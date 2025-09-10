#!/bin/bash
set -e

# fail fast with clear message if required envs missing
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID - set this as a GitHub secret named ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID - set this as a GitHub secret named ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID - set this as a GitHub secret named ARM_SUBSCRIPTION_ID}"

export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

terraform init -reconfigure
terraform plan -refresh-only -out=tfplan || true
terraform show -json tfplan > tfplan.json

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
