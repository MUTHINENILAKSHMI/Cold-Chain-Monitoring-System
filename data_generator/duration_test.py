
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "output"

# Read original data
readings = pd.read_csv(OUTPUT_DIR / "sensor_readings.csv")

readings["reading_time"] = pd.to_datetime(readings["reading_time"])

shipment_id = "SHP-GEN-000005"

# Create a separate test copy
test_data = readings.copy()

# Define a 120-minute excursion
start_time = pd.Timestamp("2026-01-05 06:30:00")
end_time = pd.Timestamp("2026-01-05 08:30:00")

# Inject temperatures above PRD-0003 maximum (8°C)
mask = (
    (test_data["shipment_id"] == shipment_id) &
    (test_data["reading_time"] >= start_time) &
    (test_data["reading_time"] <= end_time)
)

test_data.loc[mask, "temperature"] = 12.0

# Save separate test dataset
test_file = OUTPUT_DIR / "duration_test_readings.csv"
test_data.to_csv(test_file, index=False)

# Calculate actual excursion duration from timestamps
excursion_readings = test_data[
    (test_data["shipment_id"] == shipment_id) &
    (test_data["reading_time"] >= start_time) &
    (test_data["reading_time"] <= end_time) &
    (test_data["temperature"] > 8)
].sort_values("reading_time")

actual_start = excursion_readings["reading_time"].min()
actual_end = excursion_readings["reading_time"].max()

actual_duration = (
    actual_end - actual_start
).total_seconds() / 60

# Simulate an incorrect recorded duration
recorded_duration = 60

print("\n===== DURATION UNDERCOUNT VALIDATION =====")
print("Shipment:", shipment_id)
print("Product: PRD-0003")
print("Allowed temperature: 2°C to 8°C")
print("Excursion start:", actual_start)
print("Excursion end:", actual_end)
print("Actual duration:", actual_duration, "minutes")
print("Recorded duration:", recorded_duration, "minutes")

if recorded_duration < actual_duration:
    print("RESULT: DURATION UNDERCOUNT DETECTED")
else:
    print("RESULT: NO UNDERCOUNT DETECTED")

print("\nTest dataset saved:", test_file)
print("Original sensor_readings.csv remains unchanged.")
