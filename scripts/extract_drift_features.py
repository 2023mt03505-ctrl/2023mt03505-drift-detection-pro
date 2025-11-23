import json
import os
import sys
import pandas as pd

print("📘 Extracting drift features from Terraform plan...")

# -------- FIX: Accept file path from argument --------
if len(sys.argv) > 1:
    input_path = sys.argv[1]
else:
    input_path = "data/drift_results.json"  # fallback
# ------------------------------------------------------

# Ensure output directory exists
output_dir = "data"
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "drift_features.csv")

# Helper function to generate safe baseline
def safe_baseline():
    df = pd.DataFrame([{
        "num_resources_changed": 0,
        "critical_services_affected": 0,
        "drift_duration_hours": 1,
        "drift_label": "safe"
    }])
    df.to_csv(output_path, index=False)
    print("✅ Safe baseline features generated:", output_path)

# Check if input file exists
if not os.path.exists(input_path):
    print(f"⚠ No drift JSON found at {input_path} — generating safe baseline features.")
    safe_baseline()
    sys.exit(0)

# Load JSON
try:
    with open(input_path) as f:
        data = json.load(f)
except Exception as e:
    print(f"⚠ Invalid JSON at {input_path} — generating safe baseline features. Error: {e}")
    safe_baseline()
    sys.exit(0)

# If empty drift
if not data:
    print("ℹ No drift detected — generating baseline features.")
    safe_baseline()
    sys.exit(0)

# Real drift found → extract features
rows = []
for item in data:
    change = item.get("change", [])
    is_replace = "replace" in change
    is_update = "update" in change

    rows.append({
        "num_resources_changed": 1,
        "critical_services_affected": 1 if is_replace else 0,
        "drift_duration_hours": 1,
        "drift_label": "high" if is_replace else "low"
    })

df = pd.DataFrame(rows)
df.to_csv(output_path, index=False)
print("✅ Features extracted:", output_path)
