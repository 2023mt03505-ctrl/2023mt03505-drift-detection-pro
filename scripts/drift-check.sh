#!/bin/bash
set -euo pipefail

# 🚨 Fail fast if required envs missing
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"
export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

echo "🔄 Terraform init..."
terraform init -reconfigure

# Step 1: Generate a normal plan JSON for Conftest
echo "🔄 Running Terraform plan for drift detection..."
terraform plan -out=tfplan.auto -input=false
terraform show -json tfplan.auto > tfplan.json

# Step 2: Debug JSON structure for GitHub Actions logs
echo "🔹 Previewing Terraform JSON plan structure..."
jq '.resource_changes | length, .resource_changes[].address' tfplan.json || echo "⚠️ No resource_changes found"

# Step 3: Verify Conftest policies
echo "🔎 Verifying Conftest policies..."
conftest verify --policy policy/

# Step 4: Run Conftest drift classification
echo "🔎 Running drift classification with Conftest..."
set +e
output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
status=$?
set -e

# Print Conftest output
echo "🔹 Conftest output:"
echo "$output"

# Step 5: Auto-remediation logic
if echo "$output" | grep -q "❌"; then
    echo "🚨 Unsafe drift detected → Applying remediation..."
    terraform apply -auto-approve tfplan.auto
elif echo "$output" | grep -q "⚠️"; then
    echo "✅ Only safe drift detected → No remediation needed."
else
    echo "✅ No drift detected."
fi

# Step 6: Cleanup Azure CLI accounts
echo "🧹 Post-job cleanup: clearing Azure CLI accounts"
az account clear
