import mysql.connector
import pandas as pd
import os

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": os.getenv("DB_PASSWORD"),
    "database": "cold_chain_db"
}
def validate_database():
    connection = mysql.connector.connect(**DB_CONFIG)

    tables = [
        "products",
        "shipments",
        "containers",
        "sensors",
        "threshold_policies",
        "shipment_containers",
        "route_stops",
        "container_sensor_assignments",
        "sensor_readings",
        "excursions",
        "custody_events",
        "corrective_actions"
    ]

    results = []

    for table in tables:
        query = f"SELECT COUNT(*) AS row_count FROM `{table}`"
        count = pd.read_sql(query, connection).iloc[0]["row_count"]
        results.append({
            "table_name": table,
            "row_count": count
        })

    connection.close()

    report = pd.DataFrame(results)
    report.to_csv("validation_report.csv", index=False)

    print(report.to_string(index=False))
    print("\nValidation report saved as validation_report.csv")

if __name__ == "__main__":
    validate_database()