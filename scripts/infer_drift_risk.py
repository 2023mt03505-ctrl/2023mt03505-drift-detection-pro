import os, sys, pandas as pd
import joblib

model_path = "models/drift_classifier.joblib"
features_path = "data/drift_features.csv"

print("🧠 Starting AI drift risk inference...")

# Load features
if not os.path.exists(features_path):
    print("⚠ No features found. Assuming SAFE drift.")
    sys.exit(0)

df = pd.read_csv(features_path)

# Fallback smart AI rule (always available)
def fallback_ai(row):
    score = row["num_resources_changed"] + row["critical_services_affected"]

    if score >= 2:
        return "high"
    elif score == 1:
        return "low"
    return "safe"

# If no model → fallback AI
if not os.path.exists(model_path):
    print("⚠ No trained model found → using fallback AI logic.")
    df["predicted_risk"] = df.apply(fallback_ai, axis=1)
else:
    model = joblib.load(model_path)
    X = df[["num_resources_changed", "critical_services_affected", "drift_duration_hours"]]
    pred = model.predict(X)
    df["predicted_risk"] = ["high" if p == 1 else "low" for p in pred]

df.to_csv("data/drift_predictions.csv", index=False)
print("📊 Predictions:", df)

if "high" in df["predicted_risk"].values:
    print("🚨 High-risk drift → remediation recommended.")
    sys.exit(1)

print("✅ All drifts safe or low-risk.")
sys.exit(0)
