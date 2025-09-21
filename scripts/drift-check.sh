#!/bin/bash
set -euo pipefail

# -----------------------------
# Fail fast if required env vars missing
# -----------------------------
: "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
: "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
: "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"
export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

# -----------------------------
# Step 1: Refresh-only plan to detect drift
# -----------------------------
echo "🔄 Running refresh-only plan for drift detection..."
terraform plan -refresh-only -out=tfplan.refresh || true
terraform show -json tfplan.refresh > tfplan.json

# -----------------------------
# Step 2: Preview the JSON structure (for debugging)
# -----------------------------
echo "🔹 Previewing Terraform JSON plan structure..."
jq '.resource_changes[] | {type:.type,name:.name,security_rule:.change.after.security_rule,after_state:.change.after}' tfplan.json || true

# -----------------------------
# Step 3: Verify Rego policies
# -----------------------------
echo "🔎 Verifying Conftest policies..."
conftest verify --policy policy/ || true

# -----------------------------
# Step 4: Run Conftest drift detection
# -----------------------------
echo "🔎 Running drift classification with Conftest..."
set +e
output=$(conftest test tfplan.json --policy policy/ --all-namespaces --verbose 2>&1)
status=$?
set -e

echo "🔹 Conftest output:"
echo "$output"

# -----------------------------
# Step 5: Decide on remediation
# -----------------------------
if echo "$output" | grep "❌" >/dev/null; then
    echo "🚨 Unsafe drift detected → Running remediation plan..."
    terraform plan -out=tfplan.fix
    terraform apply -auto-approve tfplan.fix
elif echo "$output" | grep "⚠️" >/dev/null; then
    echo "✅ Only safe drift detected → No remediation needed."
else
    echo "✅ No drift detected."
fi

# -----------------------------
# Step 6: Cleanup
# -----------------------------
echo "🧹 Post-job cleanup: clearing Azure CLI accounts"
az account clear
