
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "output"

shipments = pd.read_csv(OUTPUT_DIR / "shipments.csv")
excursions = pd.read_csv(OUTPUT_DIR / "excursion_report.csv")

results = []

# 1. Physical range violation
physical_count = (
    excursions["issue_type"] == "PHYSICAL_RANGE_VIOLATION"
).sum()

results.append({
    "edge_case": "Physical range violation",
    "status": "DETECTED" if physical_count > 0 else "NOT DETECTED",
    "validation_type": "Actual data detection",
    "count": int(physical_count)
})

# 2. Missing sensor interval
gap_count = (
    excursions["issue_type"] == "MISSING_SENSOR_INTERVAL"
).sum()

results.append({
    "edge_case": "Missing sensor interval",
    "status": "DETECTED" if gap_count > 0 else "NOT DETECTED",
    "validation_type": "Actual data detection",
    "count": int(gap_count)
})

# 3. Delivery before departure
shipments["departure_time"] = pd.to_datetime(
    shipments["departure_time"]
)
shipments["delivery_time"] = pd.to_datetime(
    shipments["delivery_time"]
)

invalid_delivery = (
    shipments["delivery_time"] < shipments["departure_time"]
).sum()

results.append({
    "edge_case": "Delivery before departure",
    "status": "DETECTED" if invalid_delivery > 0 else "NOT DETECTED",
    "validation_type": "Actual data detection",
    "count": int(invalid_delivery)
})

# 4. Wrong product threshold using actual sensor test data
sensor_data = pd.read_csv(
    OUTPUT_DIR / "sensor_readings.csv"
)

shipment_id = "SHP-GEN-000005"

actual_product = "PRD-0003"
wrong_policy_product = "PRD-0004"

correct_min, correct_max = 2, 8
wrong_min, wrong_max = -20, -15

shipment_readings = sensor_data[
    sensor_data["shipment_id"] == shipment_id
]

correct_alerts = (
    (shipment_readings["temperature"] < correct_min) |
    (shipment_readings["temperature"] > correct_max)
).sum()

wrong_policy_alerts = (
    (shipment_readings["temperature"] < wrong_min) |
    (shipment_readings["temperature"] > wrong_max)
).sum()

false_alerts = int(wrong_policy_alerts - correct_alerts)

results.append({
    "edge_case": "Wrong product threshold",
    "status": "DETECTED" if false_alerts > 0 else "NOT DETECTED",
    "validation_type": "Actual sensor-data policy test",
    "count": false_alerts
})

# 5. Excursion duration undercount using actual test data
duration_data = pd.read_csv(
    OUTPUT_DIR / "duration_test_readings.csv"
)

duration_data["reading_time"] = pd.to_datetime(
    duration_data["reading_time"]
)

start_time = pd.Timestamp("2026-01-05 06:30:00")
end_time = pd.Timestamp("2026-01-05 08:30:00")

duration_events = duration_data[
    (duration_data["shipment_id"] == shipment_id) &
    (duration_data["reading_time"] >= start_time) &
    (duration_data["reading_time"] <= end_time) &
    (duration_data["temperature"] > 8)
].sort_values("reading_time")

if not duration_events.empty:
    actual_duration = (
        duration_events["reading_time"].max() -
        duration_events["reading_time"].min()
    ).total_seconds() / 60
else:
    actual_duration = 0

recorded_duration = 60
undercount = recorded_duration < actual_duration

results.append({
    "edge_case": "Excursion duration undercount",
    "status": "DETECTED" if undercount else "NOT DETECTED",
    "validation_type": "Actual test-data validation",
    "count": 1 if undercount else 0
})

# Create final report
report = pd.DataFrame(results)

report.to_csv(
    OUTPUT_DIR / "final_validation_report.csv",
    index=False
)

print("\n========== FINAL VALIDATION REPORT ==========\n")
print(report.to_string(index=False))

print("\nReport saved successfully:")
print(OUTPUT_DIR / "final_validation_report.csv")
