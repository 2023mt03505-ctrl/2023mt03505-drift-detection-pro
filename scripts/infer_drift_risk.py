import os, sys
import pandas as pd
import joblib

# --- consistent paths ---
MODEL_PATH = os.path.join("data", "drift_model.pkl")
FEATURE_PATH = os.path.join("data", "drift_features.csv")

if not os.path.exists(MODEL_PATH):
    print("⚠️ Model not found, skipping AI classification.")
    sys.exit(0)

if not os.path.exists(FEATURE_PATH):
    print("⚠️ Drift features not found.")
    sys.exit(0)

print("🤖 Loading trained drift classification model...")
model = joblib.load(MODEL_PATH)

# --- load and infer ---
df = pd.read_csv(FEATURE_PATH)
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
