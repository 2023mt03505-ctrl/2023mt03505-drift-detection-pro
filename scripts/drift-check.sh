#!/bin/bash
set -uo pipefail       # FIX 1: removed -e

CLOUD=${1:-}
if [[ -z "$CLOUD" ]]; then
  echo "❌ Usage: bash scripts/drift-check.sh <cloud>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${REPO_ROOT}/${CLOUD}"
LOGDIR="${WORKDIR}/data"

echo "📁 Ensuring log directory exists at: $LOGDIR"
mkdir -p "$LOGDIR"
ls -ld "$LOGDIR" || echo "⚠️ Could not verify directory; continuing..."

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
  echo "🔹 Using AWS OIDC credentials (from GitHub Actions)..."
  : "${AWS_REGION:?Missing AWS_REGION}"
else
  echo "❌ Unsupported cloud: $CLOUD"
  exit 1
fi

cd "$WORKDIR"

# =========================
# Terraform init and plan
# =========================
echo "🔄 Terraform init..."
terraform init -reconfigure -input=false

echo "🔄 Running Terraform plan for drift detection (refreshing state)..."
terraform plan -refresh=true -out=tfplan.auto -input=false || {
  echo "⚠️ Terraform plan failed"; exit 1;
}

# =========================
# Convert plan to JSON
# =========================
echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json
jq '.resource_changes' tfplan.json > "$LOGDIR/resource_changes.json"

resource_count=$(jq 'length' "$LOGDIR/resource_changes.json")

# =========================
# Run Conftest
# =========================
echo "🔎 Running Conftest policy validation..."
set +e
conftest_output=$(conftest test "$WORKDIR/tfplan.json" \
  --policy "$REPO_ROOT/policy" --all-namespaces 2>&1)
set -u

echo "$conftest_output" | tee "$LOGDIR/conftest_output.log"

fail_count=$(echo "$conftest_output" | grep -cE "FAIL|❌" || echo 0)
warn_count=$(echo "$conftest_output" | grep -cE "WARN|⚠️" || echo 0)

# FIX 2: safe grep to avoid script exit
failed_resources=$(echo "$conftest_output" | grep -E "FAIL|❌" || true \
  | awk '{print $2}' | jq -R -s -c 'split("\n")[:-1]')

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =========================
# Determine drift type & optionally auto-remediate
# =========================
if [[ $fail_count -gt 0 ]]; then
    drift_type="unsafe"
    severity="high"
    action="terraform apply"
    echo "🚨 Unsafe drift detected → Auto-remediating..."
    terraform apply -auto-approve tfplan.auto

elif [[ $warn_count -gt 0 ]]; then
    drift_type="safe"
    severity="low"
    action="none"
    echo "⚠️ Safe drift detected (no remediation)."

else
    drift_type="none"
    severity="none"
    action="none"
    echo "✅ No drift detected."
fi

# =========================
# Save unified JSON 
# =========================
cat <<EOF > "$LOGDIR/drift_results.json"
{
  "timestamp": "$timestamp",
  "cloud": "$CLOUD",
  "drift_type": "$drift_type",
  "severity": "$severity",
  "action": "$action",
  "resource_count": $resource_count,
  "fail_count": $fail_count,
  "warn_count": $warn_count,
  "failed_resources": $failed_resources
}
EOF

# =========================
# ⭐ AI FIX (ONLY ADDITION YOU REQUESTED)
# Convert single-object drift_results.json → AI-friendly array format
# =========================
jq -s '.' "$LOGDIR/drift_results.json" > "$LOGDIR/drift_results_ai.json"
echo "🤖 AI-ready drift JSON generated → $LOGDIR/drift_results_ai.json"

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
  echo "🔹 AWS OIDC session handled automatically — no cleanup needed."
fi

echo "✅ Drift detection completed for $CLOUD. Logs stored in $LOGDIR"
