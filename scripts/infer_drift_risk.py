import pandas as pd, joblib, sys, os

model_path = "models/drift_classifier.pkl"
if not os.path.exists(model_path):
    print("⚠️ Model not found, skipping AI classification.")
    sys.exit(0)

df = pd.read_csv("drift_features.csv")
model = joblib.load(model_path)
X = df[["open_ssh", "public_access", "tag_changed"]].astype(int)
pred = model.predict(X)

df["predicted_risk"] = pred
print(df[["address", "type", "predicted_risk"]])

if any(pred == 1):
    print("🚨 High-risk drift detected → trigger remediation")
    sys.exit(1)
else:
    print("✅ Only safe drifts detected")
    sys.exit(0)
