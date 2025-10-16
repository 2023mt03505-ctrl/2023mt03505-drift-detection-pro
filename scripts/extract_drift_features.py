import os
import pandas as pd

# Ensure 'data/' folder exists
os.makedirs("data", exist_ok=True)

# Simulate drift data extraction (replace this with real Terraform drift output later)
data = [
    {"address": "azurerm_network_security_group.nsg1", "type": "nsg", "open_ssh": 1, "public_access": 0, "tag_changed": 0},
    {"address": "azurerm_storage_account.sa1", "type": "storage", "open_ssh": 0, "public_access": 1, "tag_changed": 0},
    {"address": "azurerm_virtual_machine.vm1", "type": "vm", "open_ssh": 0, "public_access": 0, "tag_changed": 1},
]

df = pd.DataFrame(data)
output_path = os.path.join("data", "drift_features.csv")
df.to_csv(output_path, index=False)

print(f"✅ Drift features saved to {output_path}")
print(df)
