import pandas as pd, joblib, sys, os

model_path = "data/drift_model.pkl"
if not os.path.exists(model_path):
    print("⚠️ Model not found, skipping AI classification.")
    sys.exit(0)

features_path = "data/drift_features.csv"
if not os.path.exists(features_path):
    print("⚠️ Drift features not found.")
    sys.exit(0)

print("🤖 Loading trained drift classification model...")
model = joblib.load(model_path)
df = pd.read_csv(features_path)

# Match training feature names
X = df[["critical_services_affected", "drift_duration_hours", "num_resources_changed"]].astype(float)

pred = model.predict(X)
df["predicted_risk"] = pred

print(df[["address", "type", "predicted_risk"]])

if any(pred == 1):
    print("🚨 High-risk drift detected → trigger remediation")
    sys.exit(1)
else:
    print("✅ Only safe drifts detected")
    sys.exit(0)
