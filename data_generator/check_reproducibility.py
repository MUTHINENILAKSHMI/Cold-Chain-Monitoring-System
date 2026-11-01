import hashlib
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "output"

FILES = [
    "shipments.csv",
    "sensor_readings.csv",
    "ground_truth.csv"
]

def calculate_hash(file_path):
    hasher = hashlib.sha256()

    with open(file_path, "rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            hasher.update(chunk)

    return hasher.hexdigest()

print("\n========== DATA REPRODUCIBILITY CHECK ==========\n")

for filename in FILES:
    file_path = OUTPUT_DIR / filename

    if file_path.exists():
        print(f"{filename}:")
        print("SHA-256:", calculate_hash(file_path))
    else:
        print(f"{filename}: FILE NOT FOUND")

print("\nHash calculation completed.")