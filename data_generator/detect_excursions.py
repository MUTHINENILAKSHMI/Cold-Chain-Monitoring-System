
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).parent
INPUT_DIR = BASE_DIR / "output"
SHIPMENTS_FILE = INPUT_DIR / "shipments.csv"
READINGS_FILE = INPUT_DIR / "sensor_readings.csv"

OUTPUT_FILE = INPUT_DIR / "excursion_report.csv"

# Product-specific temperature thresholds
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

EXPECTED_INTERVAL_MINUTES = 5
PHYSICAL_MIN_TEMP = -40
PHYSICAL_MAX_TEMP = 70

def main():
    print("Loading shipment and sensor data...")

    shipments = pd.read_csv(SHIPMENTS_FILE)
    readings = pd.read_csv(READINGS_FILE)

    shipments["product_id"] = shipments["product_id"].astype(str)

    readings["reading_time"] = pd.to_datetime(
        readings["reading_time"]
    )

    data = readings.merge(
        shipments[["shipment_id", "product_id"]],
        on="shipment_id",
        how="left",
        validate="many_to_one"
    )

    if data["product_id"].isna().any():
        raise ValueError("Some readings have no matching shipment.")

    data["min_temp"] = data["product_id"].map(
        lambda p: PRODUCT_LIMITS[p][0]
    )
    data["max_temp"] = data["product_id"].map(
        lambda p: PRODUCT_LIMITS[p][1]
    )

    data = data.sort_values(
        ["sensor_id", "shipment_id", "reading_time"]
    )

    events = []
    event_number = 1

    print("Detecting temperature excursions and data gaps...")

    for (shipment_id, sensor_id), group in data.groupby(
        ["shipment_id", "sensor_id"],
        sort=False
    ):
        group = group.sort_values("reading_time").reset_index(drop=True)

        # Detect missing sensor intervals
        time_gaps = group["reading_time"].diff().dt.total_seconds() / 60

        for index in group.index[time_gaps > EXPECTED_INTERVAL_MINUTES]:
            events.append({
                "event_id": f"EVT-{event_number:07d}",
                "shipment_id": shipment_id,
                "sensor_id": sensor_id,
                "event_type": "SENSOR_DATA_GAP",
                "start_time": group.loc[index - 1, "reading_time"],
                "end_time": group.loc[index, "reading_time"],
                "duration_minutes": int(time_gaps.iloc[index]),
                "temperature": None,
                "severity": "DATA_QUALITY_ISSUE",
                "issue_type": "MISSING_SENSOR_INTERVAL"
            })
            event_number += 1

        # Detect temperature excursions
        outside = (
    (group["temperature"] < group["min_temp"]) |
    (group["temperature"] > group["max_temp"])
)

        # A reading marked suspicious is also flagged
        suspicious = group["quality_status"].eq("SUSPICIOUS")

        # Physical sensor range violation
        physical_violation = (
            (group["temperature"] < PHYSICAL_MIN_TEMP) |
            (group["temperature"] > PHYSICAL_MAX_TEMP)
        )

        flagged = outside | suspicious | physical_violation

        # Each continuous run is treated as one event.
        run_id = flagged.ne(flagged.shift(fill_value=False)).cumsum()

        for _, run in group[flagged].groupby(run_id[flagged]):
            start = run["reading_time"].iloc[0]
            end = run["reading_time"].iloc[-1]

            duration = int(
                (end - start).total_seconds() / 60
            ) + EXPECTED_INTERVAL_MINUTES

            temp = float(run["temperature"].max())

            if duration <= 30:
                severity = "BRIEF"
            else:
                severity = "PROLONGED"

            issue_type = "TEMPERATURE_EXCURSION"

            if physical_violation.loc[run.index].any():
                issue_type = "PHYSICAL_RANGE_VIOLATION"

            elif suspicious.loc[run.index].any():
                issue_type = "SUSPICIOUS_SENSOR_READING"

            events.append({
                "event_id": f"EVT-{event_number:07d}",
                "shipment_id": shipment_id,
                "sensor_id": sensor_id,
                "event_type": "TEMPERATURE_EXCURSION",
                "start_time": start,
                "end_time": end,
                "duration_minutes": duration,
                "temperature": temp,
                "severity": severity,
                "issue_type": issue_type
            })
            event_number += 1

    report = pd.DataFrame(events)

    if report.empty:
        print("No excursions or sensor gaps detected.")
        report = pd.DataFrame(columns=[
            "event_id", "shipment_id", "sensor_id",
            "event_type", "start_time", "end_time",
            "duration_minutes", "temperature",
            "severity", "issue_type"
        ])

    report.to_csv(OUTPUT_FILE, index=False)

    print("\nDetection completed!")
    print("Total detected events:", len(report))

    if not report.empty:
        print("\nEvent summary:")
        print(report["event_type"].value_counts().to_string())

        print("\nIssue summary:")
        print(report["issue_type"].value_counts().to_string())

    print("\nReport saved to:", OUTPUT_FILE)


if __name__ == "__main__":
    main()
