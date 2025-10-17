import json
import pandas as pd
import os, sys

print("📘 Extracting drift features from Terraform plan...")

# Define input/output paths
input_path = "data/drift_results.json"
output_path = "drift_features.csv"

# --- 1️⃣ Check if the input file exists ---
if not os.path.exists(input_path):
    print(f"⚠️ No drift results found at {input_path}. Skipping feature extraction.")
    sys.exit(0)

# --- 2️⃣ Load drift data safely ---
with open(input_path, "r") as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        print("⚠️ Invalid JSON format in drift_results.json. Skipping extraction.")
        sys.exit(0)

# --- 3️⃣ Extract resource list ---
resources = data.get("resource_changes") or data.get("resources") or []

if not resources:
    print("✅ No resource drift detected — nothing to extract.")
    sys.exit(0)

# --- 4️⃣ Extract drift features ---
rows = []
for r in resources:
    address = r.get("address", "unknown")
    change = r.get("change", {})
    before = change.get("before", {}) or {}
    after = change.get("after", {}) or {}

    # Feature examples
    open_ssh = int(after.get("allow_ssh", False))
    public_access = int(after.get("public_access", False))
    tag_changed = int(before.get("tags") != after.get("tags"))

    rows.append({
        "address": address,
        "type": r.get("type", "unknown"),
        "open_ssh": open_ssh,
        "public_access": public_access,
        "tag_changed": tag_changed
    })

# --- 5️⃣ Save to CSV ---
df = pd.DataFrame(rows)
df.to_csv(output_path, index=False)
print(f"✅ Drift feature file generated: {output_path}")
