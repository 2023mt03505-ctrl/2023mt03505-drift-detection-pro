#!/bin/bash
set -euo pipefail

CLOUD=${1:-}
if [[ -z "$CLOUD" ]]; then
  echo "❌ Usage: bash scripts/drift-check.sh <cloud>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${REPO_ROOT}/${CLOUD}"
LOGDIR="${WORKDIR}/data"

mkdir -p "$LOGDIR"

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
terraform plan -out=tfplan.auto -input=false || {
  echo "⚠️ Terraform plan failed"; exit 1;
}

# Convert plan to JSON for Conftest
echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json
jq '.resource_changes' tfplan.json > data/resource_changes.json

# =========================
# Run Conftest policy validation (✅ fixed relative paths)
# =========================
echo "🔎 Running Conftest policy validation..."
set +e
conftest_output=$(conftest test "$WORKDIR/tfplan.json" \
  --policy "$REPO_ROOT/policy" --all-namespaces 2>&1)
conftest_status=$?
set -e

# Save Conftest logs
echo "$conftest_output" | tee "$LOGDIR/conftest_output.log"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =========================
# Parse drift classification and auto-remediate
# =========================
if echo "$conftest_output" | grep -qE "FAIL|❌"; then
    drift_type="unsafe"
    severity="high"
    action="terraform apply"
    echo "🚨 Unsafe drift detected → Auto-remediating..."
    terraform apply -auto-approve tfplan.auto

elif echo "$conftest_output" | grep -qE "WARN|⚠️"; then
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
# Save drift history and JSON
# =========================
echo "$timestamp,$CLOUD,$drift_type,$severity,$action" >> "$LOGDIR/drift_history.csv"

cat <<EOF > "$LOGDIR/drift_results.json"
{
  "timestamp": "$timestamp",
  "cloud": "$CLOUD",
  "drift_type": "$drift_type",
  "severity": "$severity",
  "action": "$action"
}
EOF

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
