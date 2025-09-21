#!/bin/bash
set -euo pipefail

: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

echo "🔄 Terraform init..."
terraform init -reconfigure -input=false -no-color

echo "🔄 Running Terraform plan for drift detection..."
terraform plan -refresh=true -out=tfplan.auto -input=false -no-color

echo "🔹 Converting plan to JSON..."
terraform show -json tfplan.auto > tfplan.json

# Safe JSON debug (human-readable)
echo "🔹 Preview of Terraform resource_changes:"
jq '.resource_changes[] | {address, type, actions: .change.actions}' tfplan.json || true

echo "🔎 Running Conftest policies..."
set +e
conftest_output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
conftest_status=$?
set -e

echo "🔹 Conftest output:"
echo "$conftest_output"

# Auto-remediation logic
if echo "$conftest_output" | grep -q "❌"; then
    echo "🚨 Unsafe drift detected → Auto-remediating..."
    terraform apply -auto-approve tfplan.auto
elif echo "$conftest_output" | grep -q "⚠️"; then
    echo "✅ Only safe drift detected → No remediation needed."
else
    echo "✅ No drift detected."
fi

echo "🧹 Post-job cleanup: clearing Azure CLI accounts"
az account clear || true
