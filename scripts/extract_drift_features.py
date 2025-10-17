import os
import pandas as pd

os.makedirs("data", exist_ok=True)

# Simulated drift data — later, this will come from Terraform drift JSON
data = [
    {
        "address": "azurerm_network_security_group.nsg1",
        "type": "nsg",
        "num_resources_changed": 1,
        "critical_services_affected": 1,
        "drift_duration_hours": 2,
    },
    {
        "address": "azurerm_storage_account.sa1",
        "type": "storage",
        "num_resources_changed": 2,
        "critical_services_affected": 0,
        "drift_duration_hours": 5,
    },
    {
        "address": "azurerm_virtual_machine.vm1",
        "type": "vm",
        "num_resources_changed": 1,
        "critical_services_affected": 1,
        "drift_duration_hours": 1,
    },
]

df = pd.DataFrame(data)
output_path = os.path.join("data", "drift_features.csv")
df.to_csv(output_path, index=False)

print(f"✅ Drift features saved to {output_path}")
print(df)
