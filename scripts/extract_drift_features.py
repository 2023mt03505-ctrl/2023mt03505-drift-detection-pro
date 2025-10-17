import os
import json
import pandas as pd

print("📘 Extracting drift features from Terraform plan...")

os.makedirs("data", exist_ok=True)
plan_path = "data/tfplan.json"

if not os.path.exists(plan_path):
    print("⚠️ tfplan.json not found — using fallback sample data for AI testing.")
    data = [
        {"address": "azurerm_network_security_group.nsg1", "type": "nsg", "num_resources_changed": 1, "critical_services_affected": 1, "drift_duration_hours": 2},
        {"address": "azurerm_storage_account.sa1", "type": "storage", "num_resources_changed": 2, "critical_services_affected": 0, "drift_duration_hours": 5},
        {"address": "azurerm_virtual_machine.vm1", "type": "vm", "num_resources_changed": 1, "critical_services_affected": 1, "drift_duration_hours": 1},
    ]
else:
    with open(plan_path, "r") as f:
        plan_json = json.load(f)

    resources = plan_json.get("resource_changes", [])
    if not resources:
        print("⚠️ No resource_changes found in tfplan.json — using fallback data.")
        data = [
            {"address": "azurerm_network_security_group.nsg1", "type": "nsg", "num_resources_changed": 1, "critical_services_affected": 1, "drift_duration_hours": 2},
            {"address": "azurerm_storage_account.sa1", "type": "storage", "num_resources_changed": 2, "critical_services_affected": 0, "drift_duration_hours": 5},
        ]
    else:
        data = []
        for r in resources:
            address = r.get("address", "unknown")
            rtype = r.get("type", "unknown")
            actions = r.get("change", {}).get("actions", [])
            drifted = len(actions) > 0 and actions[0] != "no-op"
            if drifted:
                data.append({
                    "address": address,
                    "type": rtype,
                    "num_resources_changed": len(actions),
                    "critical_services_affected": 1 if "delete" in actions or "replace" in actions else 0,
                    "drift_duration_hours": 2,
                })

        if not data:
            print("ℹ️ No drifted resources found, adding one placeholder sample.")
            data = [{"address": "placeholder", "type": "none", "num_resources_changed": 0, "critical_services_affected": 0, "drift_duration_hours": 0}]

df = pd.DataFrame(data)
out_path = "data/drift_features.csv"
df.to_csv(out_path, index=False)

print(f"✅ Drift features extracted → {out_path}")
print(df)
