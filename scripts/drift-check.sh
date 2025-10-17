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
  echo "⚠️ No resource_changes found in tfplan.json (empty or invalid plan)"
  echo "[]" > data/resource_changes.json
fi

echo "🔎 Running Conftest policy validation..."
set +e
conftest_output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
status=$?
set -e
echo "$conftest_output" | tee data/conftest_output.log

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Drift Classification ---
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
  echo "✅ Safe drift detected (no action)."
else
  drift_type="none"
  severity="none"
  action="none"
  echo "✅ No drift detected."
fi

# --- Logging ---
echo "$timestamp,$drift_type,$severity,$action" >> data/drift_history.csv

# --- Cleanup ---
az account clear
