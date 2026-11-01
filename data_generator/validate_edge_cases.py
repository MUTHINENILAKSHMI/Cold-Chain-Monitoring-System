
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "output"

shipments = pd.read_csv(OUTPUT_DIR / "shipments.csv")
readings = pd.read_csv(OUTPUT_DIR / "sensor_readings.csv")

# Correct product-specific temperature limits from generate_data.py
PRODUCT_LIMITS = {
    "PRD-0001": (2, 6),
    "PRD-0002": (2, 8),
    "PRD-0003": (2, 8),
    "PRD-0004": (-20, -15),
    "PRD-0005": (-25, -18),
    "PRD-0006": (2, 6),
    "PRD-0007": (15, 25),
    "PRD-0008": (2, 6),
    "PRD-0009": (-20, -15),
    "PRD-0010": (2, 6),
}

print("\n========== EDGE CASE VALIDATION ==========\n")

# 1. Delivery before departure
shipments["departure_time"] = pd.to_datetime(shipments["departure_time"])
shipments["delivery_time"] = pd.to_datetime(shipments["delivery_time"])

invalid_delivery = shipments[
    shipments["delivery_time"] < shipments["departure_time"]
]

print("1. DELIVERY BEFORE DEPARTURE")
print("Detected records:", len(invalid_delivery))

# Join product information to actual sensor readings
actual_data = readings.merge(
    shipments[["shipment_id", "product_id"]],
    on="shipment_id",
    how="left"
)

actual_data["min_limit"] = actual_data["product_id"].map(
    lambda x: PRODUCT_LIMITS.get(x, (None, None))[0]
)
actual_data["max_limit"] = actual_data["product_id"].map(
    lambda x: PRODUCT_LIMITS.get(x, (None, None))[1]
)

# 2. Correct product threshold validation
print("\n2. WRONG PRODUCT THRESHOLD VALIDATION")

actual_data["outside_correct_limit"] = (
    (actual_data["temperature"] < actual_data["min_limit"]) |
    (actual_data["temperature"] > actual_data["max_limit"])
)

# Deliberately apply another product's policy to shipment 5
test_shipment = "SHP-GEN-000005"
test_product = "PRD-0003"
wrong_policy_product = "PRD-0004"

correct_min, correct_max = PRODUCT_LIMITS[test_product]
wrong_min, wrong_max = PRODUCT_LIMITS[wrong_policy_product]

test_readings = actual_data[
    actual_data["shipment_id"] == test_shipment
].copy()

test_readings["wrong_policy_flag"] = (
    (test_readings["temperature"] < wrong_min) |
    (test_readings["temperature"] > wrong_max)
)

test_readings["correct_policy_flag"] = (
    (test_readings["temperature"] < correct_min) |
    (test_readings["temperature"] > correct_max)
)

false_flags = test_readings[
    test_readings["wrong_policy_flag"] &
    ~test_readings["correct_policy_flag"]
]

print("Test shipment:", test_shipment)
print("Actual product:", test_product)
print("Correct limits:", correct_min, "to", correct_max)
print("Incorrect policy product:", wrong_policy_product)
print("Incorrect limits:", wrong_min, "to", wrong_max)
print("False alerts caused by wrong policy:", len(false_flags))

wrong_threshold_detected = len(false_flags) > 0

print(
    "Wrong threshold scenario:",
    "DETECTED" if wrong_threshold_detected else "NOT DETECTED"
)

# 3. Excursion duration undercount using actual test data
print("\n3. EXCURSION DURATION UNDERCOUNT")

duration_file = OUTPUT_DIR / "duration_test_readings.csv"

if duration_file.exists():
    duration_data = pd.read_csv(duration_file)
    duration_data["reading_time"] = pd.to_datetime(
        duration_data["reading_time"]
    )

    start_time = pd.Timestamp("2026-01-05 06:30:00")
    end_time = pd.Timestamp("2026-01-05 08:30:00")

    event = duration_data[
        (duration_data["shipment_id"] == test_shipment) &
        (duration_data["reading_time"] >= start_time) &
        (duration_data["reading_time"] <= end_time) &
        (duration_data["temperature"] > correct_max)
    ].sort_values("reading_time")

    if not event.empty:
        actual_duration = (
            event["reading_time"].max() -
            event["reading_time"].min()
        ).total_seconds() / 60

        recorded_duration = 60

        print("Actual duration:", actual_duration, "minutes")
        print("Recorded duration:", recorded_duration, "minutes")

        if recorded_duration < actual_duration:
            print("Duration undercount: DETECTED")
        else:
            print("Duration undercount: NOT DETECTED")
    else:
        print("No duration test event found.")
else:
    print("Duration test file not found.")

print("\n========== VALIDATION COMPLETED ==========")
