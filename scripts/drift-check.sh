#!/bin/bash
set -e

# fail fast with clear message if required envs missing
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

# ✅ Init already done in workflow → do NOT run terraform init here

terraform plan -refresh-only -out=tfplan || true
terraform show -json tfplan > tfplan.json

echo "🔎 Verifying Conftest policies..."
conftest verify --policy policy/

echo "🔎 Running drift classification with Conftest..."
set +e
output=$(conftest test tfplan.json --policy policy/ --all-namespaces 2>&1)
status=$?
set -e

echo "$output"

if echo "$output" | grep "❌"; then
  echo "🚨 Unsafe drift detected → Auto-remediating..."
  terraform apply -auto-approve tfplan
elif echo "$output" | grep "⚠️"; then
  echo "✅ Only safe drift detected → No remediation needed."
else
  echo "✅ No drift detected."
fi
