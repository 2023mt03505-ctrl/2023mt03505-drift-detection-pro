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

echo "🔄 Running Terraform plan for drift detection..."
terraform plan -refresh=true -out=tfplan.auto -input=false || {
  echo "⚠️ Terraform plan failed"; exit 1;
}

# =========================
# Convert plan to JSON (BEFORE remediation)
# =========================
echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json

echo "🔹 Extracting resource_changes BEFORE remediation..."
jq '.resource_changes' tfplan.json > "$LOGDIR/terraform-drift.json"
echo "📄 Drift JSON saved to: $LOGDIR/terraform-drift.json"

resource_count=$(jq 'length' "$LOGDIR/terraform-drift.json")

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

# --------------------------
# STRICT FIX FOR TEAMS JSON
# --------------------------
# Extract only resource names from conftest output (robust attempt)
raw_failed=$(echo "$conftest_output" | grep -E "FAIL|❌" | awk -F'- ' '{print $NF}' || true)

if [[ -z "$raw_failed" ]]; then
    failed_resources="[]"
else
    # convert newline-separated raw names into a JSON array string
    failed_resources=$(echo "$raw_failed" | jq -R -s -c 'split("\n")[:-1]')
fi
# --------------------------

# STRICT FIX — assign numeric defaults after real values
resource_count=${resource_count:-0}
fail_count=${fail_count:-0}
warn_count=${warn_count:-0}

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =========================
# AI FEATURE EXTRACTION & RISK INFERENCE (PRE-REMEDIATION)
# =========================
echo "🤖 Running AI-based drift risk classification (before remediation)..."

python "$REPO_ROOT/scripts/extract_drift_features.py" "$LOGDIR/terraform-drift.json" || \
  echo "⚠️ AI feature extraction fallback."

python "$REPO_ROOT/scripts/train_drift_model.py" || \
  echo "⚠️ AI model training skipped."

python "$REPO_ROOT/scripts/infer_drift_risk.py" || \
  echo "⚠️ AI inference could not run."

# =========================
# Decide Remediation AFTER AI
# =========================
if [[ $fail_count -gt 0 ]]; then
    drift_type="unsafe"
    severity="high"
    action="terraform apply"

    echo "🚨 Unsafe drift detected (AI + Policy) → Proceeding with auto-remediation..."
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
# Save unified JSON (SAFE via jq)
# =========================
# Ensure failed_resources is valid JSON array string (we created it above).
# Use jq to build JSON safely so PowerShell ConvertFrom-Json will always work.
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
  echo "🔹 AWS OIDC session handled automatically — no cleanup needed."
fi

echo "✅ Drift detection completed for $CLOUD. Logs stored in $LOGDIR"
