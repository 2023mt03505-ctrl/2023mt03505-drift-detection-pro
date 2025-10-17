import os, json, pandas as pd

os.makedirs("data", exist_ok=True)
json_path = "data/resource_changes.json"

if os.path.exists(json_path):
    print("📘 Extracting drift features from Terraform plan...")
    with open(json_path) as f:
        resources = json.load(f)

    rows = []
    for r in resources:
        addr = r.get("address", "")
        rtype = r.get("type", "")
        actions = r.get("change", {}).get("actions", [])
        change_count = len(actions)
        rows.append({
            "address": addr,
            "type": rtype,
            "num_resources_changed": change_count,
            "critical_services_affected": 1 if "azurerm_network_security_group" in addr else 0,
            "drift_duration_hours": 1
        })
    df = pd.DataFrame(rows)
else:
    print("⚠️ No resource_changes.json found, generating sample features.")
    df = pd.DataFrame([
        {"address": "azurerm_storage_account.sa", "type": "storage", "num_resources_changed": 1, "critical_services_affected": 0, "drift_duration_hours": 2}
    ])

df.to_csv("data/drift_features.csv", index=False)
print("✅ Drift features saved → data/drift_features.csv")
