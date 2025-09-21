#!/bin/bash
set -e

# Fail fast with clear message if required envs missing
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

# Step 1: Refresh-only plan for drift detection
echo "🔄 Running refresh-only plan for drift detection..."
terraform plan -refresh-only -out=tfplan.refresh || true
terraform show -json tfplan.refresh > tfplan.json

echo "🔎 Verifying Conftest policies..."
conftest verify --policy policy/

echo "🔎 Running drift classification with Conftest..."
set +e
output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
status=$?
set -e

echo "$output"

if echo "$output" | grep "❌"; then
  echo "🚨 Unsafe drift detected → Running remediation plan..."
  
  # Step 2: Full plan+apply to revert drift
  terraform plan -out=tfplan.fix
  terraform apply -auto-approve tfplan.fix

elif echo "$output" | grep "⚠️"; then
  echo "✅ Only safe drift detected → No remediation needed."
else
  echo "✅ No drift detected."
fi
