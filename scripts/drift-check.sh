#!/bin/bash
set -euo pipefail

CLOUD=${1:-}
if [[ -z "$CLOUD" ]]; then
  echo "❌ Usage: bash scripts/drift-check.sh <cloud>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${REPO_ROOT}/${CLOUD}"
LOGDIR="${WORKDIR}/data"

echo "📁 Ensuring log directory exists at: $LOGDIR"
mkdir -p "$LOGDIR"
ls -ld "$LOGDIR" || echo "⚠️ Could not verify directory; continuing..."

echo "🌐 Starting drift detection for: $CLOUD"

# =========================
# Cloud-specific environment setup
# =========================
if [[ "$CLOUD" == "azure" ]]; then
  echo "🔹 Validating Azure OIDC environment..."
  : "${ARM_CLIENT_ID:?Missing ARM_CLIENT_ID}"
  : "${ARM_TENANT_ID:?Missing ARM_TENANT_ID}"
  : "${ARM_SUBSCRIPTION_ID:?Missing ARM_SUBSCRIPTION_ID}"
  export ARM_USE_OIDC="${ARM_USE_OIDC:-true}"

elif [[ "$CLOUD" == "aws" ]]; then
  echo "🔹 Using AWS OIDC credentials (from GitHub Actions)..."
  : "${AWS_REGION:?Missing AWS_REGION}"
else
  echo "❌ Unsupported cloud: $CLOUD"
  exit 1
fi

cd "$WORKDIR"

# =========================
# Terraform init and plan
# =========================
echo "🔄 Terraform init..."
terraform init -reconfigure -input=false

echo "🔄 Running Terraform plan for drift detection..."
terraform plan -out=tfplan.auto -input=false || {
  echo "⚠️ Terraform plan failed"; exit 1;
}

# Convert plan to JSON for Conftest
echo "🔹 Converting p
