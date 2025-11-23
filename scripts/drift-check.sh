#!/bin/bash
set -uo pipefail

CLOUD=${1:-}
if [[ -z "$CLOUD" ]]; then
  echo "❌ Usage: bash scripts/drift-check.sh <cloud>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGDIR="${REPO_ROOT}/data/${CLOUD}"
mkdir -p "$LOGDIR"
mkdir -p "$REPO_ROOT/data"

echo "📁 Ensuring log directory exists at: $LOGDIR"

echo "🌐 Starting drift detection for: $CLOUD"

# =========================
# Cloud-specific environment setup
# =========================
if [[ "$CLOUD" == "azure" ]]; then
  echo "🔹 Validating Azure OIDC environment..."
  : "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
  : "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
  : "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"
  export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

elif [[ "$CLOUD" == "aws" ]]; then
  echo "🔹 Using AWS OIDC credentials..."
  : "${AWS_REGION:?Missing AWS_REGION}"
else
  echo "❌ Unsupported cloud: $CLOUD"
  exit 1
fi

cd "$REPO_ROOT/$CLOUD"

# =========================
# Terraform init and plan
# =========================
echo "🔄 Terraform init..."
terraform init -reconfigure -input=false

echo "🔄 Running Terraform plan for drift detection..."
terraform plan -refresh=true -out=tfplan.auto -input=false || {
  echo "⚠️ Terraform plan failed"; exit 1;
}

echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json
jq '.resource_changes' tfplan.json > "$LOGDIR/terraform-drift.json"
echo "📄 Drift JSON saved to: $LOGDIR/terraform-drift.json"

resource_count=$(jq 'length' "$LOGDIR/terraform-drift.json" || echo 0)

# =========================
# Run Conftest
# =========================
echo "🔎 Running Conftest policy validation..."
set +e
conftest_output=$(conftest test tfplan.json --policy "$REPO_ROOT/policy" --all-namespaces 2>&1)
set -u

echo "$conftest_output" | tee "$LOGDIR/conftest_output.log"
fail_count=$(echo "$conftest_output" | grep -cE "FAIL|❌" || echo 0)
warn_count=$(echo "$conftest_output" | grep -cE "WARN|⚠️" || echo 0)

raw_failed=$(echo "$conftest_output" | grep -E "FAIL|❌" | awk -F'- ' '{print $NF}' || true)
if [[ -z "$raw_failed" ]]; then
    failed_resources="[]"
else
    failed_resources=$(echo "$raw_failed" | jq -R -s -c 'split("\n")[:-1]')
fi

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =========================
# AI FEATURE EXTRACTION & RISK INFERENCE
# =========================
echo "🤖 Running AI-based drift risk classification..."
python "$REPO_ROOT/scripts/extract_drift_features.py" "$LOGDIR/terraform-drift.json" || echo "⚠️ AI feature extraction fallback."
python "$REPO_ROOT/scripts/train_drift_model.py" || echo "⚠️ AI model training skipped."
python "$REPO_ROOT/scripts/infer_drift_risk.py" || echo "⚠️ AI inference fallback."

# =========================
# Decide Remediation
# =========================
if [[ $fail_count -gt 0 ]]; then
    drift_type="unsafe"
    severity="high"
    action="terraform apply"
    echo "🚨 Unsafe drift detected → auto-remediation..."
    terraform apply -auto-approve tfplan.auto
elif [[ $warn_count -gt 0 ]]; then
    drift_type="safe"
    severity="low"
    action="none"
    echo "⚠️ Safe drift detected."
else
    drift_type="none"
    severity="none"
    action="none"
    echo "✅ No drift detected."
fi

# =========================
# Save unified JSON
# =========================
jq -n \
  --arg timestamp "$timestamp" \
  --arg cloud "$CLOUD" \
  --arg drift_type "$drift_type" \
  --arg severity "$severity" \
  --arg action "$action" \
  --argjson resource_count "$resource_count" \
  --argjson fail_count "$fail_count" \
  --argjson warn_count "$warn_count" \
  --argjson failed_resources "$failed_resources" \
  '{
    timestamp: $timestamp,
    cloud: $cloud,
    drift_type: $drift_type,
    severity: $severity,
    action: $action,
    resource_count: $resource_count,
    fail_count: $fail_count,
    warn_count: $warn_count,
    failed_resources: $failed_resources
  }' > "$LOGDIR/drift_results.json"

echo "📄 Drift results saved to: $LOGDIR/drift_results.json"

# =========================
# Save drift history
# =========================
echo "$timestamp,$CLOUD,$drift_type,$severity,$action,$resource_count,$fail_count,$warn_count" >> "$LOGDIR/drift_history.csv"

# =========================
# Session cleanup
# =========================
if [[ "$CLOUD" == "azure" ]]; then
  echo "🔹 Clearing Azure session..."
  az account clear || true
elif [[ "$CLOUD" == "aws" ]]; then
  echo "🔹 AWS OIDC session handled automatically."
fi

echo "✅ Drift detection completed for $CLOUD. Logs stored in $LOGDIR"
