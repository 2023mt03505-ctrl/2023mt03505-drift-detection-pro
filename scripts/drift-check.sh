#!/bin/bash
set -euo pipefail

# =========================
# Azure authentication validation
# =========================
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

mkdir -p data

# =========================
# Terraform init and plan
# =========================
echo "🔄 Terraform init..."
terraform init -reconfigure

echo "🔄 Running Terraform plan for drift detection..."
terraform plan -out=tfplan.auto -input=false || {
    echo "⚠️ Terraform plan failed"; exit 1;
}

# Convert plan to JSON for Conftest
echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json
jq '.resource_changes' tfplan.json > data/resource_changes.json

# =========================
# Run Conftest policy validation
# =========================
echo "🔎 Running Conftest policy validation..."
set +e
conftest_output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
conftest_status=$?
set -e

# Save Conftest logs
echo "$conftest_output" | tee data/conftest_output.log

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =========================
# Parse drift classification and auto-remediate
# =========================
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

# =========================
# Save drift history
# =========================
echo "$timestamp,$drift_type,$severity,$action" >> data/drift_history.csv

# =========================
# Clear Azure session for security
# =========================
az account clear
