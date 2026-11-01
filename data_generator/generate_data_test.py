
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
SEED = 20261022
SHIPMENT_COUNT = 1000

# Separate output folder to protect original dataset
OUTPUT_DIR = Path(__file__).parent / "reproducibility_test_output"

random.seed(SEED)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

start_date = datetime(2026, 1, 1, 6, 0, 0)

shipment_file = OUTPUT_DIR / "shipments.csv"
reading_file = OUTPUT_DIR / "sensor_readings.csv"
truth_file = OUTPUT_DIR / "ground_truth.csv"

# Product temperature and humidity limits
# Format: min_temperature, max_temperature, min_humidity, max_humidity

PRODUCT_LIMITS = {
    "PRD-0001": (2, 6, 30, 60),
    "PRD-0002": (2, 8, 30, 65),
    "PRD-0003": (2, 8, 30, 65),
    "PRD-0004": (-20, -15, 40, 70),
    "PRD-0005": (-25, -18, 40, 70),
    "PRD-0006": (2, 6, 30, 60),
    "PRD-0007": (15, 25, 40, 60),
    "PRD-0008": (2, 6, 30, 60),
    "PRD-0009": (-20, -15, 40, 70),
    "PRD-0010": (2, 6, 30, 60),
}

# Generate shipments and sensor readings
with open(shipment_file, "w", newline="") as sf, \
     open(reading_file, "w", newline="") as rf:

    sw = csv.writer(sf)
    rw = csv.writer(rf)

    sw.writerow([
        "shipment_id", "product_id", "container_id",
        "sensor_id", "departure_time", "delivery_time",
        "trip_days"
    ])

    rw.writerow([
        "reading_id", "shipment_id", "container_id",
        "sensor_id", "reading_time", "temperature",
        "humidity", "quality_status"
    ])

    for i in range(1, SHIPMENT_COUNT + 1):

        shipment_id = f"SHP-GEN-{i:06d}"

        container_id = f"CNT-GEN-{((i - 1) % 300) + 1:06d}"

        sensor_id = f"SNS-GEN-{((i - 1) % 300) + 1:06d}"

        product_id = f"PRD-{random.randint(1, 10):04d}"

        min_t, max_t, min_h, max_h = PRODUCT_LIMITS[product_id]

        trip_days = random.randint(2, 5)

        departure = start_date + timedelta(days=i - 1)

        delivery = departure + timedelta(days=trip_days)

        # Edge case: delivery before departure
        if i == 3:
            delivery = departure - timedelta(hours=1)

        sw.writerow([
            shipment_id,
            product_id,
            container_id,
            sensor_id,
            departure.isoformat(sep=" "),
            delivery.isoformat(sep=" "),
            trip_days
        ])

        total_readings = trip_days * 24 * 12

        for j in range(total_readings):

            reading_time = departure + timedelta(minutes=5 * j)

            # Edge case: missing sensor reading
            if i == 2 and j == 12:
                continue

            temperature = round(
                random.uniform(min_t + 0.5, max_t - 0.5), 2
            )

            humidity = round(
                random.uniform(min_h + 2, max_h - 2), 2
            )

            quality = "GOOD"

            # Edge case: physical sensor range violation
            if i == 1 and j == 12:
                temperature = 75.0
                quality = "SUSPICIOUS"

            reading_id = f"RDG-GEN-{i:06d}-{j:05d}"

            rw.writerow([
                reading_id,
                shipment_id,
                container_id,
                sensor_id,
                reading_time.isoformat(sep=" "),
                temperature,
                humidity,
                quality
            ])

# Generate ground truth documentation
with open(truth_file, "w", newline="") as tf:

    tw = csv.writer(tf)

    tw.writerow([
        "anomaly_id", "anomaly_type", "shipment_id",
        "expected_issue", "details"
    ])

    tw.writerow([
        1, "PHYSICAL_RANGE_VIOLATION", "SHP-GEN-000001",
        "Temperature exceeds physical sensor range",
        "One reading is set to 75 C"
    ])

    tw.writerow([
        2, "MISSING_SENSOR_INTERVAL", "SHP-GEN-000002",
        "Missing 5-minute sensor reading",
        "One scheduled reading is omitted"
    ])

    tw.writerow([
        3, "DELIVERED_BEFORE_DEPARTURE", "SHP-GEN-000003",
        "Delivery timestamp is before departure",
        "Delivery is set one hour before departure"
    ])

    tw.writerow([
        4, "WRONG_PRODUCT_THRESHOLD", "SHP-GEN-000004",
        "Incorrect product threshold used",
        "Test by comparing product with another product policy"
    ])

    tw.writerow([
        5, "EXCURSION_DURATION_UNDERCOUNT", "SHP-GEN-000005",
        "Recorded duration is lower than actual duration",
        "Test by comparing stored duration with start and end times"
    ])

print("\nSynthetic test data generation completed!")

print(f"Shipments: {SHIPMENT_COUNT}")

print(f"Output folder: {OUTPUT_DIR}")

print("\nFiles created:")
print("- shipments.csv")
print("- sensor_readings.csv")
print("- ground_truth.csv")
