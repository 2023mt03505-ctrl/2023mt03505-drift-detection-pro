import os, sys, joblib, pandas as pd

model_path = "data/drift_model.pkl"
features_path = "data/drift_features.csv"

if not os.path.exists(model_path):
    print("⚠️ No model found — skipping AI classification.")
    sys.exit(0)

if not os.path.exists(features_path):
    print("⚠️ No drift features found.")
    sys.exit(0)

print("🤖 Loading trained drift classification model...")
model = joblib.load(model_path)
df = pd.read_csv(features_path)

# ✅ Must match training feature order exactly
feature_cols = ["num_resources_changed", "critical_services_affected", "drift_duration_hours"]
X = df[feature_cols].astype(float)

pred = model.predict(X)
df["predicted_risk"] = pred

print("\n📊 Drift Risk Predictions:")
print(df[["address", "type", "predicted_risk"]])

if any(pred == 1):
    print("🚨 High-risk drift detected → trigger remediation")
    sys.exit(1)
else:
    print("✅ Only safe drifts detected")
    sys.exit(0)
