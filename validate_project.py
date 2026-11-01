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
    cursor = connection.cursor(dictionary=True)

    report = []
    details = []

    try:
        # Get database tables
        cursor.execute("""
            SELECT TABLE_NAME
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
        """)

        tables = [row["TABLE_NAME"] for row in cursor.fetchall()]

        for table in tables:

            # 1. Row count
            cursor.execute(f"SELECT COUNT(*) AS total FROM `{table}`")
            row_count = cursor.fetchone()["total"]

            report.append({
                "table_name": table,
                "check_type": "ROW_COUNT",
                "issue_count": row_count,
                "status": "INFO"
            })

            # 2. Primary key validation
            cursor.execute("""
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE()
                AND TABLE_NAME = %s
                AND CONSTRAINT_NAME = 'PRIMARY'
            """, (table,))

            pk_columns = [
                row["COLUMN_NAME"] for row in cursor.fetchall()
            ]

            if pk_columns:

                pk_expression = ", ".join(
                    f"`{column}`" for column in pk_columns
                )

                null_condition = " OR ".join(
                    f"`{column}` IS NULL" for column in pk_columns
                )

                cursor.execute(f"""
                    SELECT COUNT(*) AS issue_count
                    FROM `{table}`
                    WHERE {null_condition}
                """)

                null_pk = cursor.fetchone()["issue_count"]

                cursor.execute(f"""
                    SELECT COUNT(*) AS issue_count
                    FROM (
                        SELECT {pk_expression}
                        FROM `{table}`
                        GROUP BY {pk_expression}
                        HAVING COUNT(*) > 1
                    ) AS duplicates
                """)

                duplicate_pk = cursor.fetchone()["issue_count"]

                report.append({
                    "table_name": table,
                    "check_type": "NULL_PRIMARY_KEY",
                    "issue_count": null_pk,
                    "status": "PASS" if null_pk == 0 else "FAIL"
                })

                report.append({
                    "table_name": table,
                    "check_type": "DUPLICATE_PRIMARY_KEY",
                    "issue_count": duplicate_pk,
                    "status": "PASS" if duplicate_pk == 0 else "FAIL"
                })

            # 3. Missing values
            cursor.execute(f"SHOW COLUMNS FROM `{table}`")
            columns = [row["Field"] for row in cursor.fetchall()]

            null_expression = " + ".join(
                f"SUM(`{column}` IS NULL)" for column in columns
            )

            cursor.execute(f"""
                SELECT COALESCE({null_expression}, 0) AS missing_count
                FROM `{table}`
            """)

            missing_count = cursor.fetchone()["missing_count"]

            report.append({
                "table_name": table,
                "check_type": "MISSING_VALUES",
                "issue_count": int(missing_count or 0),
                "status": "INFO"
            })

        # 4. Foreign key validation
        cursor.execute("""
            SELECT
                TABLE_NAME,
                COLUMN_NAME,
                REFERENCED_TABLE_NAME,
                REFERENCED_COLUMN_NAME
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA = DATABASE()
            AND REFERENCED_TABLE_NAME IS NOT NULL
        """)

        foreign_keys = cursor.fetchall()

        for fk in foreign_keys:

            child = fk["TABLE_NAME"]
            child_column = fk["COLUMN_NAME"]
            parent = fk["REFERENCED_TABLE_NAME"]
            parent_column = fk["REFERENCED_COLUMN_NAME"]

            query = f"""
                SELECT COUNT(*) AS issue_count
                FROM `{child}` child
                LEFT JOIN `{parent}` parent
                ON child.`{child_column}` = parent.`{parent_column}`
                WHERE child.`{child_column}` IS NOT NULL
                AND parent.`{parent_column}` IS NULL
            """

            cursor.execute(query)
            orphan_count = cursor.fetchone()["issue_count"]

            report.append({
                "table_name": child,
                "check_type": f"INVALID_FOREIGN_KEY_{child_column}",
                "issue_count": orphan_count,
                "status": "PASS" if orphan_count == 0 else "FAIL"
            })

        # 5. Actual shipment date validation
        cursor.execute("""
            SELECT
                shipment_id,
                actual_departure,
                actual_delivery,
                status
            FROM shipments
            WHERE actual_departure IS NOT NULL
            AND actual_delivery IS NOT NULL
            AND actual_delivery < actual_departure
        """)

        invalid_shipments = cursor.fetchall()

        report.append({
            "table_name": "shipments",
            "check_type": "INVALID_ACTUAL_SHIPMENT_DATES",
            "issue_count": len(invalid_shipments),
            "status": "PASS" if not invalid_shipments else "FAIL"
        })

        for row in invalid_shipments:
            details.append({
                "issue_type": "INVALID_ACTUAL_SHIPMENT_DATES",
                "table_name": "shipments",
                "record_id": row["shipment_id"],
                "description": (
                    f"Delivery {row['actual_delivery']} is before "
                    f"departure {row['actual_departure']}"
                )
            })

        # 6. Planned shipment date validation
        cursor.execute("""
            SELECT
                shipment_id,
                planned_departure,
                planned_delivery
            FROM shipments
            WHERE planned_delivery < planned_departure
        """)

        invalid_planned = cursor.fetchall()

        report.append({
            "table_name": "shipments",
            "check_type": "INVALID_PLANNED_SHIPMENT_DATES",
            "issue_count": len(invalid_planned),
            "status": "PASS" if not invalid_planned else "FAIL"
        })

        for row in invalid_planned:
            details.append({
                "issue_type": "INVALID_PLANNED_SHIPMENT_DATES",
                "table_name": "shipments",
                "record_id": row["shipment_id"],
                "description": "Planned delivery is before planned departure"
            })

        # 7. Route stop status and timestamp validation
        cursor.execute("""
            SELECT
                route_stop_id,
                shipment_id,
                status,
                actual_arrival,
                actual_departure
            FROM route_stops
            WHERE
                (status = 'PLANNED'
                    AND (actual_arrival IS NOT NULL
                    OR actual_departure IS NOT NULL))
                OR
                (status = 'ARRIVED'
                    AND (actual_arrival IS NULL
                    OR actual_departure IS NOT NULL))
                OR
                (status = 'DEPARTED'
                    AND (actual_arrival IS NULL
                    OR actual_departure IS NULL))
        """)

        invalid_route_stops = cursor.fetchall()

        report.append({
            "table_name": "route_stops",
            "check_type": "INVALID_STOP_STATUS_TIMESTAMPS",
            "issue_count": len(invalid_route_stops),
            "status": "PASS" if not invalid_route_stops else "FAIL"
        })

        for row in invalid_route_stops:
            details.append({
                "issue_type": "INVALID_STOP_STATUS_TIMESTAMPS",
                "table_name": "route_stops",
                "record_id": row["route_stop_id"],
                "description": (
                    f"Shipment {row['shipment_id']}, status {row['status']}, "
                    f"actual arrival {row['actual_arrival']}, "
                    f"actual departure {row['actual_departure']}"
                )
            })

        # 8. Shipment delivery vs custody event validation
        cursor.execute("""
            SELECT
                s.shipment_id,
                s.actual_delivery,
                c.event_time AS custody_delivery
            FROM shipments s
            JOIN custody_events c
                ON s.shipment_id = c.shipment_id
            WHERE c.event_type = 'DELIVERED'
            AND s.actual_delivery IS NOT NULL
            AND s.actual_delivery <> c.event_time
        """)

        delivery_mismatches = cursor.fetchall()

        report.append({
            "table_name": "shipments",
            "check_type": "DELIVERY_CUSTODY_MISMATCH",
            "issue_count": len(delivery_mismatches),
            "status": "PASS" if not delivery_mismatches else "FAIL"
        })

        for row in delivery_mismatches:
            details.append({
                "issue_type": "DELIVERY_CUSTODY_MISMATCH",
                "table_name": "shipments",
                "record_id": row["shipment_id"],
                "description": (
                    f"Shipment delivery: {row['actual_delivery']}; "
                    f"Custody delivery: {row['custody_delivery']}"
                )
            })

        # 9. Physical temperature validation
        cursor.execute("""
            SELECT
                reading_id,
                shipment_id,
                sensor_id,
                temperature_c,
                quality_status,
                recorded_at
            FROM sensor_readings
            WHERE temperature_c IS NOT NULL
            AND (temperature_c < -40 OR temperature_c > 70)
        """)

        invalid_readings = cursor.fetchall()

        report.append({
            "table_name": "sensor_readings",
            "check_type": "PHYSICAL_TEMPERATURE_RANGE",
            "issue_count": len(invalid_readings),
            "status": "PASS" if not invalid_readings else "FAIL"
        })

        for row in invalid_readings:
            details.append({
                "issue_type": "PHYSICAL_TEMPERATURE_RANGE",
                "table_name": "sensor_readings",
                "record_id": row["reading_id"],
                "description": (
                    f"Temperature {row['temperature_c']}°C is outside "
                    f"the physical range -40°C to 70°C; "
                    f"quality status: {row['quality_status']}"
                )
            })

        # 10. Invalid sensor quality records
        cursor.execute("""
            SELECT
                reading_id,
                shipment_id,
                quality_status
            FROM sensor_readings
            WHERE quality_status = 'INVALID'
        """)

        invalid_quality_rows = cursor.fetchall()

        report.append({
            "table_name": "sensor_readings",
            "check_type": "INVALID_SENSOR_QUALITY",
            "issue_count": len(invalid_quality_rows),
            "status": "INFO"
        })

        for row in invalid_quality_rows:
            details.append({
                "issue_type": "INVALID_SENSOR_QUALITY",
                "table_name": "sensor_readings",
                "record_id": row["reading_id"],
                "description": (
                    f"Sensor quality status is {row['quality_status']}"
                )
            })

        # 11. Missing temperature records
        cursor.execute("""
            SELECT
                reading_id,
                shipment_id,
                recorded_at
            FROM sensor_readings
            WHERE temperature_c IS NULL
        """)

        missing_readings = cursor.fetchall()

        report.append({
            "table_name": "sensor_readings",
            "check_type": "MISSING_TEMPERATURE",
            "issue_count": len(missing_readings),
            "status": "INFO"
        })

        for row in missing_readings:
            details.append({
                "issue_type": "MISSING_TEMPERATURE",
                "table_name": "sensor_readings",
                "record_id": row["reading_id"],
                "description": (
                    f"Temperature missing at {row['recorded_at']}"
                )
            })

    finally:
        cursor.close()
        connection.close()

    # Save summary report
    result = pd.DataFrame(report)
    result.to_csv("validation_report.csv", index=False)

    # Save detailed issue report
    detail_result = pd.DataFrame(
        details,
        columns=[
            "issue_type",
            "table_name",
            "record_id",
            "description"
        ]
    )
    detail_result.to_csv("validation_details.csv", index=False)

    print("\n========== DATABASE VALIDATION REPORT ==========\n")
    print(result.to_string(index=False))

    print("\n========== VALIDATION DETAILS ==========\n")
    if details:
        print(detail_result.to_string(index=False))
    else:
        print("No detailed issues found.")

    print("\nReports saved:")
    print("1. validation_report.csv")
    print("2. validation_details.csv")


if __name__ == "__main__":
    validate_database()
