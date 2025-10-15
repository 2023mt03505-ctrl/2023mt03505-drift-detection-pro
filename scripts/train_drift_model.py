import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib, os

df = pd.read_csv("drift_features.csv")

# quick rule-based labels for bootstrap training
df["label"] = df.apply(
    lambda x: 1 if x["open_ssh"] or x["public_access"] else 0,
    axis=1
)

X = df[["open_ssh", "public_access", "tag_changed"]].astype(int)
y = df["label"]

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

print(classification_report(y_test, clf.predict(X_test)))

os.makedirs("models", exist_ok=True)
joblib.dump(clf, "models/drift_classifier.pkl")
print("✅ Model saved → models/drift_classifier.pkl")
