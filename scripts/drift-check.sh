echo "🔎 Running drift classification with Conftest..."
set +e
output=$(conftest test tfplan.json --policy policy/ --all-namespaces)
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
