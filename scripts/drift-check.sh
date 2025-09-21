#!/bin/bash
set -euo pipefail

# Fail fast if required env vars missing
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"
export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

echo "🔄 Running refresh-only plan for drift detection..."
terraform plan -refresh-only -out=tfplan.refresh || true
terraform show -json tfplan.refresh > tfplan.json

# Debugging: safely iterate over resource_changes even if null
echo "🔹 Previewing Terraform JSON plan structure..."
jq '.resource_changes? // [] | .[] | {type:.type,name:.name,security_rule:.change.after.security_rule,after_state:.change.after}' tfplan.json || true

echo "🔎 Verifying Conftest policies..."
conftest verify --policy policy/ || true

echo "🔎 Running drift classification with Conftest..."
set +e
output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
status=$?
set -e

echo "🔹 Conftest output:"
echo "$output"

if echo "$output" | grep "❌" >/dev/null; then
    echo "🚨 Unsafe drift detected → Running remediation plan..."
    terraform plan -out=tfplan.fix
    terraform apply -auto-approve tfplan.fix
elif echo "$output" | grep "⚠️" >/dev/null; then
    echo "✅ Only safe drift detected → No remediation needed."
else
    echo "✅ No drift detected."
fi

echo "🧹 Post-job cleanup: clearing Azure CLI accounts"
az account clear
