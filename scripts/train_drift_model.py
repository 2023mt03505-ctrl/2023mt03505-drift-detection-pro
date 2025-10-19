import os, pandas as pd, sys
from sklearn.ensemble import RandomForestClassifier
from joblib import dump

os.makedirs("models", exist_ok=True)
data_path = "data/drift_features.csv"
model_path = "models/drift_classifier.joblib"

# --- Check if data exists ---
if not os.path.exists(data_path) or os.path.getsize(data_path) == 0:
    print("⚠️ No drift feature data found. Skipping model training.")
    sys.exit(0)

df = pd.read_csv(data_path)

feature_cols = ['num_resources_changed', 'critical_services_affected', 'drift_duration_hours']
missing = [c for c in feature_cols if c not in df.columns]

if missing:
    print(f"⚠️ Missing columns in feature data: {missing}. Skipping training.")
    sys.exit(0)

if df.empty:
    print("⚠️ No rows in drift feature data. Skipping training.")
    sys.exit(0)

if 'drift_label' not in df.columns:
    print("⚠️ Missing drift_label column. Skipping training.")
    sys.exit(0)

X = df[feature_cols]
y = (df['drift_label'] == 'high').astype(int)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X, y)
dump(model, model_path)

print(f"✅ Drift classification model trained successfully → {model_path}")
