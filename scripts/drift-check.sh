#!/bin/bash
set -euo pipefail

# --- Azure OIDC Auth ---
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

mkdir -p data

echo "🔄 Terraform init..."
terraform init -reconfigure

echo "🔄 Running Terraform plan for drift detection..."
if ! terraform plan -refresh-only -out=tfplan.auto -input=false; then
  echo "⚠️ Terraform plan failed"
  exit 1
fi

echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json

# Extract resource_changes safely
jq '.resource_changes // []' tfplan.json > data/resource_changes.json

if [[ ! -s data/resource_changes.json ]]; then
  echo "⚠️ No resource_changes found in tfplan.json"
  echo "[]" > data/resource_changes.json
fi

echo "🔎 Running Conftest policy validation..."
set +e
conftest_output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
status=$?
set -e
echo "$conftest_output" | tee data/conftest_output.log

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Drift classification based on policies ---
if echo "$conftest_output" | grep -q "❌"; then
  drift_type="unsafe"
  severity="high"
  action="terraform apply"
  echo "🚨 Unsafe drift detected → Auto-remediating..."
  terraform apply -auto-approve tfplan.auto
elif echo "$conftest_output" | grep -q "⚠️"; then
  drift_type="safe"
  severity="low"
  action="none"
  echo "✅ Safe drift detected (no remediation)."
else
  drift_type="none"
  severity="none"
  action="none"
  echo "✅ No drift detected."
fi

# --- Write drift results for AI layer ---
if [[ "$drift_type" == "none" ]]; then
  echo "[]" > data/drift_results.json
else
  jq -n --arg type "$drift_type" --arg severity "$severity" \
     '[{ "drift_type": $type, "severity": $severity }]' > data/drift_results.json
fi

# --- Log drift history ---
echo "$timestamp,$drift_type,$severity,$action" >> data/drift_history.csv

# --- AI Layer: Extract features + infer risk ---
echo "🧠 Extracting features for AI classification..."
python3 scripts/extract_drift_features.py || echo "⚠️ Feature extraction failed"

echo "🤖 Running AI-based drift risk inference..."
python3 scripts/infer_drift_risk.py || echo "⚠️ Risk inference failed"

# --- Fallback remediation if unsafe drift persists ---
if [[ "$drift_type" != "none" ]]; then
  echo "⚙️ Fallback: Ensuring infrastructure is in sync..."
  terraform apply -auto-approve tfplan.auto
fi

# --- Cleanup ---
az account clear
