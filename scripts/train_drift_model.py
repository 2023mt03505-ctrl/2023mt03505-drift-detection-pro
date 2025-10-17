import os, pandas as pd, joblib
from sklearn.ensemble import RandomForestClassifier

os.makedirs("data", exist_ok=True)
history_path = "data/drift_history.csv"

if os.path.exists(history_path):
    df = pd.read_csv(history_path)
else:
    df = pd.DataFrame({
        "num_resources_changed": [1, 3, 10],
        "critical_services_affected": [0, 1, 1],
        "drift_duration_hours": [1, 5, 10],
        "risk_label": ["low", "high", "high"]
    })

if "risk_label" not in df.columns:
    df["risk_label"] = ["low"] * len(df)

feature_cols = ["num_resources_changed", "critical_services_affected", "drift_duration_hours"]
X = df[feature_cols]
y = (df["risk_label"] == "high").astype(int)

print("🧠 Training RandomForest drift model...")
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X, y)
joblib.dump(model, "data/drift_model.pkl")
print("✅ Saved model → data/drift_model.pkl")
