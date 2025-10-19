import os, sys, joblib, pandas as pd

model_path = "data/drift_model.pkl"
features_path = "data/drift_features.csv"

print("🧠 Starting AI drift risk inference...")

if not os.path.exists(model_path):
    print("⚠️ No trained model found. Skipping risk inference.")
    sys.exit(0)

if not os.path.exists(features_path):
    print("⚠️ No drift features found. Skipping risk inference.")
    sys.exit(0)

try:
    model = joblib.load(model_path)
    df = pd.read_csv(features_path)
    print(f"✅ Loaded model and features ({len(df)} records)")
except Exception as e:
    print(f"❌ Error loading model or data: {e}")
    sys.exit(0)

feature_cols = ["num_resources_changed", "critical_services_affected", "drift_duration_hours"]
missing_cols = [c for c in feature_cols if c not in df.columns]

if missing_cols:
    print(f"⚠️ Missing expected feature columns: {missing_cols}")
    sys.exit(0)

X = df[feature_cols].astype(float)
pred = model.predict(X)

df["predicted_risk"] = ["high" if p == 1 else "low" for p in pred]
df.to_csv("data/drift_predictions.csv", index=False)

print("📊 Drift predictions:\n", df[["address", "type", "predicted_risk"]])

if "high" in df["predicted_risk"].values:
    print("🚨 High-risk drift found → triggering remediation.")
    sys.exit(1)
else:
    print("✅ All detected drifts are low-risk.")
    sys.exit(0)
