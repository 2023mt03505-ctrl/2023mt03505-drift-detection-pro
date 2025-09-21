#!/bin/bash
set -euo pipefail

# Fail fast if required envs missing
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

echo "🔄 Terraform init..."
terraform init -reconfigure

echo "🔄 Running Terraform plan for drift detection..."
terraform plan -refresh=true -out=tfplan.auto -input=false

echo "🔹 Saving JSON plan..."
terraform show -json tfplan.auto > tfplan.json

echo "🔹 Previewing Terraform JSON plan structure..."
jq '.resource_changes // [] | length as $len | "resource_changes count: \($len)", (.[] | .address)' tfplan.json || echo "⚠️ No resource_changes found"

echo "🔎 Verifying Conftest policies..."
conftest verify --policy policy/ || true

echo "🔎 Running drift classification with Conftest..."
set +e
conftest_output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
conftest_status=$?
set -e

echo "🔹 Conftest output:"
echo "$conftest_output"

if echo "$conftest_output" | grep -q "❌"; then
    echo "🚨 Unsafe drift detected → Auto-remediating..."
    terraform apply -auto-approve tfplan.auto
elif echo "$conftest_output" | grep -q "⚠️"; then
    echo "✅ Only safe drift detected → No remediation needed."
else
    echo "✅ No drift detected."
fi

echo "🧹 Post-job cleanup: clearing Azure CLI accounts"
az account clear
