import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

# Ensure the data directory exists
os.makedirs("data", exist_ok=True)

# Check drift history file
history_path = "data/drift_history.csv"
if not os.path.exists(history_path):
    print(f"❌ No drift history found at {history_path}. Please run drift detection first.")
    exit(1)

print("📘 Loading drift history...")
df = pd.read_csv(history_path)

# Simple fallback dataset
if "drift_type" not in df.columns or "risk_label" not in df.columns:
    print("⚠️ Drift history missing required columns, generating sample training data...")
    df = pd.DataFrame({
        "num_resources_changed": [1, 3, 10, 2],
        "critical_services_affected": [0, 1, 1, 0],
        "drift_duration_hours": [1, 5, 12, 2],
        "risk_label": ["low", "high", "high", "low"]
    })

print("🧠 Training RandomForest model...")
X = df.drop(columns=["risk_label"])
y = df["risk_label"]

model = RandomForestClassifier(n_estimators=50, random_state=42)
model.fit(X, y)

output_path = "data/drift_model.pkl"
joblib.dump(model, output_path)
print(f"✅ Model trained and saved to {output_path}")
