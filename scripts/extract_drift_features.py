import json, os, sys, pandas as pd

print("📘 Extracting drift features from Terraform plan...")

input_path = "data/drift_results.json"
output_path = "data/drift_features.csv"

# --- Check if file exists and is non-empty ---
if not os.path.exists(input_path) or os.path.getsize(input_path) == 0:
    print("⚠️ No drift results found. Skipping feature extraction.")
    sys.exit(0)

with open(input_path) as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        print("⚠️ Invalid JSON format in drift_results.json. Skipping.")
        sys.exit(0)

if not data:
    print("⚠️ No drift entries found. Skipping extraction.")
    sys.exit(0)

rows = []
for entry in data:
    drift_type = entry.get("drift_type", "unknown")
    severity = entry.get("severity", "unknown")

    # Derive simple numeric features for model input
    num_resources_changed = 1 if drift_type != "none" else 0
    critical_services_affected = 1 if severity == "high" else 0
    drift_duration_hours = 1  # Placeholder (future: calculate via timestamps)

    rows.append({
        "num_resources_changed": num_resources_changed,
        "critical_services_affected": critical_services_affected,
        "drift_duration_hours": drift_duration_hours,
        "drift_label": severity
    })

df = pd.DataFrame(rows)
df.to_csv(output_path, index=False)
print(f"✅ Drift feature file generated: {output_path}")
