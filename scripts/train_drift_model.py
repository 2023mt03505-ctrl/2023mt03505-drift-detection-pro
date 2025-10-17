import os
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib

os.makedirs("data", exist_ok=True)

history_path = "data/drift_history.csv"

print("📘 Loading drift history...")
if not os.path.exists(history_path):
    print(f"⚠️ Drift history not found at {history_path}. Generating sample data...")
    df = pd.DataFrame({
        "num_resources_changed": [1, 3, 10, 2],
        "critical_services_affected": [0, 1, 1, 0],
        "drift_duration_hours": [1, 5, 12, 2],
        "risk_label": ["low", "high", "high", "low"]
    })
else:
    df = pd.read_csv(history_path)
    if "risk_label" not in df.columns:
        print("⚠️ No 'risk_label' column found — using fallback dataset.")
        df = pd.DataFrame({
            "num_resources_changed": [1, 3, 10, 2],
            "critical_services_affected": [0, 1, 1, 0],
            "drift_duration_hours": [1, 5, 12, 2],
            "risk_label": ["low", "high", "high", "low"]
        })

print("🧠 Training RandomForest model...")
# Maintain consistent feature order
feature_cols = ["num_resources_changed", "critical_services_affected", "drift_duration_hours"]
X = df[feature_cols]
y = (df["risk_label"] == "high").astype(int)

model = RandomForestClassifier(n_estimators=50, random_state=42)
model.fit(X, y)

joblib.dump(model, "data/drift_model.pkl")
print("✅ Model trained and saved to data/drift_model.pkl")
