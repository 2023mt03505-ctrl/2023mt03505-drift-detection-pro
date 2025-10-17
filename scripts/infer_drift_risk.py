import os, sys, joblib, pandas as pd

model_path = "data/drift_model.pkl"
features_path = "data/drift_features.csv"

if not os.path.exists(model_path):
    print("⚠️ No trained model found.")
    sys.exit(0)

if not os.path.exists(features_path):
    print("⚠️ No drift features found.")
    sys.exit(0)

print("🤖 Loading model & predicting drift risk...")
model = joblib.load(model_path)
df = pd.read_csv(features_path)

feature_cols = ["num_resources_changed", "critical_services_affected", "drift_duration_hours"]
X = df[feature_cols].astype(float)
pred = model.predict(X)

df["predicted_risk"] = ["high" if p == 1 else "low" for p in pred]
df.to_csv("data/drift_predictions.csv", index=False)

print("📊 Drift predictions:\n", df[["address", "type", "predicted_risk"]])

if "high" in df["predicted_risk"].values:
    print("🚨 High-risk drift found → recommend remediation.")
    sys.exit(1)
else:
    print("✅ All drifts are low-risk.")
