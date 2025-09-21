#!/bin/bash
set -euo pipefail

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

echo "🔄 Terraform init..."
terraform init -reconfigure

echo "🔄 Terraform plan for drift detection..."
terraform plan -refresh=true -out=tfplan.auto -input=false

echo "🔹 Convert plan to JSON..."
terraform show -json tfplan.auto > tfplan.json

echo "🔹 Safe Terraform JSON resource_changes preview:"
jq -r '.resource_changes[]? | "\(.address) (\(.type)): \(.change.actions)"' tfplan.json || echo "⚠️ No resource_changes found"

echo "🔎 Preparing JSON for Conftest..."
jq '{resource_changes: .resource_changes}' tfplan.json > tfplan.conftest.json

echo "🔎 Running Conftest policies..."
set +e
conftest_output=$(conftest test tfplan.conftest.json --policy policy/ --all-namespaces 2>&1)
conftest_status=$?
set -e

echo "🔹 Conftest output:"
echo "$conftest_output"

echo "🔹 Auto-remediation logic:"
if echo "$conftest_output" | grep -q "❌"; then
    echo "🚨 Unsafe drift detected → Applying plan..."
    terraform apply -auto-approve tfplan.auto
elif echo "$conftest_output" | grep -q "⚠️"; then
    echo "✅ Only safe drift detected → No remediation needed."
else
    echo "✅ No drift detected."
fi

echo "🧹 Cleanup Azure CLI accounts"
az account clear
