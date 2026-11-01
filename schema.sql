CREATE DATABASE IF NOT EXISTS cold_chain_db;
USE cold_chain_db;

-- 1. PRODUCTS
CREATE TABLE products (
    product_id VARCHAR(30) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    storage_category ENUM('AMBIENT','CHILLED','FROZEN') NOT NULL,
    shelf_life_days INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CHECK (shelf_life_days > 0)
) ENGINE=InnoDB;

-- 2. SHIPMENTS
CREATE TABLE shipments (
    shipment_id VARCHAR(30) PRIMARY KEY,
    product_id VARCHAR(30) NOT NULL,
    origin VARCHAR(100) NOT NULL,
    destination VARCHAR(100) NOT NULL,
    planned_departure DATETIME NOT NULL,
    actual_departure DATETIME,
    planned_delivery DATETIME NOT NULL,
    actual_delivery DATETIME,
    status ENUM('CREATED','READY','IN_TRANSIT','DELAYED','DELIVERED','CANCELLED') DEFAULT 'CREATED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    CHECK (planned_delivery > planned_departure)
) ENGINE=InnoDB;

-- 3. CONTAINERS
CREATE TABLE containers (
    container_id VARCHAR(30) PRIMARY KEY,
    serial_number VARCHAR(50) UNIQUE NOT NULL,
    container_type ENUM('REFRIGERATED','INSULATED','FREEZER') NOT NULL,
    capacity_liters DECIMAL(10,2) NOT NULL,
    manufacturer VARCHAR(100),
    status ENUM('AVAILABLE','ASSIGNED','MAINTENANCE','INACTIVE') DEFAULT 'AVAILABLE',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CHECK (capacity_liters > 0)
) ENGINE=InnoDB;

-- 4. SENSORS
CREATE TABLE sensors (
    sensor_id VARCHAR(50) PRIMARY KEY,
    serial_number VARCHAR(50) UNIQUE NOT NULL,
    sensor_type ENUM('TEMPERATURE','HUMIDITY','COMBINED') NOT NULL,
    manufacturer VARCHAR(100),
    calibration_status ENUM('CALIBRATED','DUE','FAILED','INACTIVE') NOT NULL,
    last_calibrated_at DATETIME,
    calibration_due_at DATETIME,
    accuracy DECIMAL(5,2),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CHECK (accuracy IS NULL OR accuracy > 0)
) ENGINE=InnoDB;

-- 5. THRESHOLD POLICIES
CREATE TABLE threshold_policies (
    policy_id VARCHAR(30) PRIMARY KEY,
    product_id VARCHAR(30) NOT NULL,
    min_temperature DECIMAL(5,2),
    max_temperature DECIMAL(5,2),
    min_humidity DECIMAL(5,2),
    max_humidity DECIMAL(5,2),
    max_excursion_minutes INT NOT NULL,
    effective_from DATETIME NOT NULL,
    effective_to DATETIME,
    policy_status ENUM('ACTIVE','INACTIVE') DEFAULT 'ACTIVE',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    CHECK (min_temperature IS NULL OR max_temperature IS NULL OR min_temperature <= max_temperature),
    CHECK (min_humidity IS NULL OR max_humidity IS NULL OR
           (min_humidity >= 0 AND max_humidity <= 100 AND min_humidity <= max_humidity)),
    CHECK (max_excursion_minutes >= 0),
    CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE=InnoDB;

-- 6. SHIPMENT CONTAINERS
CREATE TABLE shipment_containers (
    shipment_id VARCHAR(30) NOT NULL,
    container_id VARCHAR(30) NOT NULL,
    assigned_at DATETIME NOT NULL,
    released_at DATETIME,
    assignment_status ENUM('ACTIVE','RELEASED') DEFAULT 'ACTIVE',
    PRIMARY KEY (shipment_id, container_id, assigned_at),
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    FOREIGN KEY (container_id) REFERENCES containers(container_id),
    CHECK (released_at IS NULL OR released_at > assigned_at)
) ENGINE=InnoDB;

-- 7. ROUTE STOPS
CREATE TABLE route_stops (
    route_stop_id VARCHAR(30) PRIMARY KEY,
    shipment_id VARCHAR(30) NOT NULL,
    stop_sequence INT NOT NULL,
    stop_name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    planned_arrival DATETIME NOT NULL,
    actual_arrival DATETIME,
    planned_departure DATETIME NOT NULL,
    actual_departure DATETIME,
    stop_type ENUM('ORIGIN','TRANSIT','DESTINATION') NOT NULL,
    status ENUM('PLANNED','ARRIVED','DEPARTED','SKIPPED') DEFAULT 'PLANNED',
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    UNIQUE (shipment_id, stop_sequence),
    CHECK (stop_sequence > 0),
    CHECK (planned_departure >= planned_arrival)
) ENGINE=InnoDB;

-- 8. CONTAINER SENSOR ASSIGNMENTS
CREATE TABLE container_sensor_assignments (
    assignment_id VARCHAR(30) PRIMARY KEY,
    container_id VARCHAR(30) NOT NULL,
    sensor_id VARCHAR(50) NOT NULL,
    installed_at DATETIME NOT NULL,
    removed_at DATETIME,
    sensor_position ENUM('INTERNAL','EXTERNAL') NOT NULL,
    assignment_status ENUM('ACTIVE','REMOVED') DEFAULT 'ACTIVE',
    FOREIGN KEY (container_id) REFERENCES containers(container_id),
    FOREIGN KEY (sensor_id) REFERENCES sensors(sensor_id),
    CHECK (removed_at IS NULL OR removed_at > installed_at)
) ENGINE=InnoDB;

-- 9. SENSOR READINGS
CREATE TABLE sensor_readings (
    reading_id VARCHAR(100) PRIMARY KEY,
    sensor_id VARCHAR(50) NOT NULL,
    shipment_id VARCHAR(30) NOT NULL,
    container_id VARCHAR(30) NOT NULL,
    route_stop_id VARCHAR(30),
    recorded_at DATETIME NOT NULL,
    temperature_c DECIMAL(7,2),
    humidity_pct DECIMAL(7,2),
    battery_level DECIMAL(5,2),
    signal_strength INT,
    quality_status ENUM('VALID','SUSPICIOUS','INVALID') NOT NULL,
    received_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sensor_id) REFERENCES sensors(sensor_id),
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    FOREIGN KEY (container_id) REFERENCES containers(container_id),
    FOREIGN KEY (route_stop_id) REFERENCES route_stops(route_stop_id),
    UNIQUE (sensor_id, recorded_at),
    CHECK (battery_level IS NULL OR battery_level BETWEEN 0 AND 100),
    CHECK (signal_strength IS NULL OR signal_strength BETWEEN -120 AND 0),
    CHECK (received_at >= recorded_at)
) ENGINE=InnoDB;

-- 10. EXCURSIONS
CREATE TABLE excursions (
    excursion_id VARCHAR(30) PRIMARY KEY,
    shipment_id VARCHAR(30) NOT NULL,
    sensor_id VARCHAR(50) NOT NULL,
    policy_id VARCHAR(30) NOT NULL,
    excursion_type ENUM('TEMPERATURE','HUMIDITY') NOT NULL,
    start_reading_id VARCHAR(100) NOT NULL,
    end_reading_id VARCHAR(100),
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    duration_minutes DECIMAL(10,2),
    severity ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
    excursion_status ENUM('OPEN','UNDER_REVIEW','RESOLVED') DEFAULT 'OPEN',
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    FOREIGN KEY (sensor_id) REFERENCES sensors(sensor_id),
    FOREIGN KEY (policy_id) REFERENCES threshold_policies(policy_id),
    FOREIGN KEY (start_reading_id) REFERENCES sensor_readings(reading_id),
    FOREIGN KEY (end_reading_id) REFERENCES sensor_readings(reading_id),
    CHECK (end_time IS NULL OR end_time > start_time),
    CHECK (duration_minutes IS NULL OR duration_minutes >= 0)
) ENGINE=InnoDB;

-- 11. CUSTODY EVENTS
CREATE TABLE custody_events (
    custody_event_id VARCHAR(30) PRIMARY KEY,
    shipment_id VARCHAR(30) NOT NULL,
    event_type ENUM('PICKUP','HANDOVER','RECEIVED','DELIVERED') NOT NULL,
    from_party VARCHAR(100),
    to_party VARCHAR(100) NOT NULL,
    location VARCHAR(150) NOT NULL,
    event_time DATETIME NOT NULL,
    received_by VARCHAR(100),
    evidence_reference VARCHAR(255),
    remarks VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id)
) ENGINE=InnoDB;

-- 12. CORRECTIVE ACTIONS
CREATE TABLE corrective_actions (
    action_id VARCHAR(30) PRIMARY KEY,
    shipment_id VARCHAR(30) NOT NULL,
    excursion_id VARCHAR(30),
    action_type ENUM('REFRIGERATION_CHECK','SENSOR_REPLACEMENT','QUALITY_INSPECTION','ROUTE_REVIEW') NOT NULL,
    description VARCHAR(255) NOT NULL,
    assigned_to VARCHAR(100) NOT NULL,
    opened_at DATETIME NOT NULL,
    due_at DATETIME,
    completed_at DATETIME,
    action_status ENUM('OPEN','IN_PROGRESS','COMPLETED','CANCELLED') DEFAULT 'OPEN',
    resolution_notes VARCHAR(255),
    evidence_reference VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    FOREIGN KEY (excursion_id) REFERENCES excursions(excursion_id),
    CHECK (due_at IS NULL OR due_at > opened_at),
    CHECK (completed_at IS NULL OR completed_at >= opened_at)
) ENGINE=InnoDB;

-- INDEXES
CREATE INDEX idx_shipment_product ON shipments(product_id);
CREATE INDEX idx_reading_shipment_time ON sensor_readings(shipment_id, recorded_at);
CREATE INDEX idx_reading_sensor_time ON sensor_readings(sensor_id, recorded_at);
CREATE INDEX idx_excursion_shipment ON excursions(shipment_id);
CREATE INDEX idx_excursion_status ON excursions(excursion_status);
CREATE INDEX idx_custody_shipment_time ON custody_events(shipment_id, event_time);
CREATE INDEX idx_action_status ON corrective_actions(action_status);
CREATE INDEX idx_policy_product_dates ON threshold_policies(product_id, effective_from, effective_to);

SHOW TABLES;


SELECT
    TABLE_NAME,
    TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'cold_chain_db'
ORDER BY TABLE_NAME;

SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'cold_chain_db'
AND REFERENCED_TABLE_NAME IS NOT NULL;

USE cold_chain_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS shipmentcontainer;
DROP TABLE IF EXISTS routestop;
DROP TABLE IF EXISTS thresholdpolicy;
DROP TABLE IF EXISTS shipment;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS container;

SET FOREIGN_KEY_CHECKS = 1;

SHOW TABLES;

DESCRIBE products;
DESCRIBE shipments;
DESCRIBE containers;
DESCRIBE sensors;
DESCRIBE threshold_policies;
DESCRIBE shipment_containers;
DESCRIBE route_stops;
DESCRIBE container_sensor_assignments;
DESCRIBE sensor_readings;
DESCRIBE excursions;
DESCRIBE custody_events;
DESCRIBE corrective_actions;

SELECT
    'products' AS table_name, COUNT(*) AS total_rows FROM products
UNION ALL
SELECT 'shipments', COUNT(*) FROM shipments
UNION ALL
SELECT 'containers', COUNT(*) FROM containers
UNION ALL
SELECT 'sensors', COUNT(*) FROM sensors;

USE cold_chain_db;

INSERT INTO products
(product_id, product_name, product_type, description,
 storage_category, shelf_life_days, is_active)
VALUES
('PRD-0001', 'Fresh Milk', 'DAIRY',
 'Pasteurized fresh milk', 'CHILLED', 7, 1),

('PRD-0002', 'Butter', 'DAIRY',
 'Unsalted dairy butter', 'CHILLED', 60, 1),

('PRD-0003', 'Cheese', 'DAIRY',
 'Processed cheese', 'CHILLED', 90, 1),

('PRD-0004', 'Frozen Peas', 'FROZEN FOOD',
 'Frozen green peas', 'FROZEN', 180, 1),

('PRD-0005', 'Ice Cream', 'FROZEN FOOD',
 'Vanilla ice cream', 'FROZEN', 120, 1),

('PRD-0006', 'Fresh Juice', 'BEVERAGE',
 'Fresh fruit juice', 'CHILLED', 5, 1),

('PRD-0007', 'Chocolate', 'CONFECTIONERY',
 'Milk chocolate', 'AMBIENT', 180, 1),

('PRD-0008', 'Yogurt', 'DAIRY',
 'Plain yogurt', 'CHILLED', 15, 1),

('PRD-0009', 'Frozen Chicken', 'MEAT',
 'Frozen chicken product', 'FROZEN', 270, 1),

('PRD-0010', 'Fresh Cream', 'DAIRY',
 'Fresh dairy cream', 'CHILLED', 10, 1);

SELECT COUNT(*) AS total_products
FROM products;


SELECT COUNT(*) AS total_containers
FROM containers;

USE cold_chain_db;

INSERT INTO containers
(container_id, serial_number, container_type, capacity_liters, manufacturer, status)
SELECT
    CONCAT('CNT-', LPAD(n, 6, '0')),
    CONCAT('SN-CNT-', LPAD(n, 6, '0')),
    CASE
        WHEN MOD(n, 3) = 1 THEN 'REFRIGERATED'
        WHEN MOD(n, 3) = 2 THEN 'INSULATED'
        ELSE 'FREEZER'
    END,
    CASE
        WHEN MOD(n, 3) = 1 THEN 500.00
        WHEN MOD(n, 3) = 2 THEN 750.00
        ELSE 1000.00
    END,
    CASE
        WHEN MOD(n, 3) = 1 THEN 'Carrier'
        WHEN MOD(n, 3) = 2 THEN 'Thermo King'
        ELSE 'Daikin'
    END,
    'AVAILABLE'
FROM (
    SELECT a.n + b.n * 10 + c.n * 100 + 1 AS n
    FROM
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2) c
) numbers;



USE cold_chain_db;

INSERT INTO sensors
(sensor_id, serial_number, sensor_type, manufacturer,
 calibration_status, last_calibrated_at, calibration_due_at, accuracy)
SELECT
    CONCAT('SNS-CNT-', LPAD(n, 6, '0')),
    CONCAT('SN-SENSOR-', LPAD(n, 6, '0')),
    'TEMPERATURE',
    CASE
        WHEN MOD(n, 3) = 1 THEN 'Sensitech'
        WHEN MOD(n, 3) = 2 THEN 'Emerson'
        ELSE 'Testo'
    END,
    'CALIBRATED',
    '2026-01-01 00:00:00',
    '2027-01-01 00:00:00',
    0.50
FROM (
    SELECT a.n + b.n * 10 + c.n * 100 + 1 AS n
    FROM
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2) c
) numbers;

SELECT COUNT(*) AS total_sensors
FROM sensors;



INSERT INTO container_sensor_assignments
(assignment_id, container_id, sensor_id, installed_at,
 removed_at, sensor_position, assignment_status)

SELECT
    CONCAT('ASN-', LPAD(n, 6, '0')),
    CONCAT('CNT-', LPAD(n, 6, '0')),
    CONCAT('SNS-CNT-', LPAD(n, 6, '0')),
    '2026-01-01 00:00:00',
    NULL,
    'INTERNAL',
    'ACTIVE'
FROM (
    SELECT a.n + b.n * 10 + c.n * 100 + 1 AS n
    FROM
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2) c
) numbers;


USE cold_chain_db;

INSERT INTO threshold_policies
(policy_id, product_id, min_temperature, max_temperature,
 min_humidity, max_humidity, max_excursion_minutes,
 effective_from, effective_to, policy_status)
VALUES
('POL-0001', 'PRD-0001', 2, 6, 30, 60, 15, '2026-01-01', NULL, 'ACTIVE'),
('POL-0002', 'PRD-0002', 2, 8, 30, 65, 20, '2026-01-01', NULL, 'ACTIVE'),
('POL-0003', 'PRD-0003', 2, 8, 30, 65, 20, '2026-01-01', NULL, 'ACTIVE'),
('POL-0004', 'PRD-0004', -20, -15, 40, 70, 15, '2026-01-01', NULL, 'ACTIVE'),
('POL-0005', 'PRD-0005', -25, -18, 40, 70, 10, '2026-01-01', NULL, 'ACTIVE'),
('POL-0006', 'PRD-0006', 2, 6, 30, 60, 15, '2026-01-01', NULL, 'ACTIVE'),
('POL-0007', 'PRD-0007', 15, 25, 40, 60, 60, '2026-01-01', NULL, 'ACTIVE'),
('POL-0008', 'PRD-0008', 2, 6, 30, 60, 15, '2026-01-01', NULL, 'ACTIVE'),
('POL-0009', 'PRD-0009', -20, -15, 40, 70, 15, '2026-01-01', NULL, 'ACTIVE'),
('POL-0010', 'PRD-0010', 2, 6, 30, 60, 15, '2026-01-01', NULL, 'ACTIVE');



SELECT COUNT(*) AS total_policies
FROM threshold_policies;

USE cold_chain_db;

SELECT COUNT(*) AS total_assignments
FROM container_sensor_assignments;



USE cold_chain_db;

INSERT INTO shipments
(shipment_id, product_id, origin, destination,
 planned_departure, actual_departure,
 planned_delivery, actual_delivery, status)
SELECT
    CONCAT('SHP-2026-', LPAD(n, 6, '0')),
    CONCAT('PRD-', LPAD(((n - 1) MOD 10) + 1, 4, '0')),
    ELT(((n - 1) MOD 5) + 1,
        'Hyderabad', 'Mumbai', 'Delhi', 'Chennai', 'Bengaluru'),
    ELT(((n - 1) MOD 5) + 1,
        'Pune', 'Ahmedabad', 'Kolkata', 'Jaipur', 'Kochi'),
    DATE_ADD('2026-01-01 06:00:00',
        INTERVAL (n - 1) * 12 HOUR),
    DATE_ADD('2026-01-01 06:00:00',
        INTERVAL (n - 1) * 12 HOUR),
    DATE_ADD('2026-01-03 06:00:00',
        INTERVAL (n - 1) * 12 HOUR),
    NULL,
    'IN_TRANSIT'
FROM (
    SELECT a.n + b.n * 10 + c.n * 100 + 1 AS n
    FROM
      (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
       UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN
      (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
       UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN
      (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
       UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
) numbers;

SELECT COUNT(*) AS total_shipments
FROM shipments;



USE cold_chain_db;

INSERT INTO shipment_containers
(shipment_id, container_id, assigned_at, released_at, assignment_status)
SELECT
    s.shipment_id,
    c.container_id,
    s.actual_departure,
    DATE_ADD(s.actual_departure, INTERVAL 48 HOUR),
    'RELEASED'
FROM shipments s
JOIN containers c
    ON c.container_id = CONCAT(
        'CNT-',
        LPAD(
            MOD(CAST(RIGHT(s.shipment_id, 6) AS UNSIGNED) - 1, 300) + 1,
            6,
            '0'
        )
    );
    
    
    
    USE cold_chain_db;

INSERT INTO route_stops
(route_stop_id, shipment_id, stop_sequence, stop_name, city,
 planned_arrival, actual_arrival,
 planned_departure, actual_departure,
 stop_type, status)
SELECT
    CONCAT('RST-', RIGHT(s.shipment_id, 6), '-', r.stop_sequence),
    s.shipment_id,
    r.stop_sequence,
    r.stop_name,
    CASE
        WHEN r.stop_sequence = 1 THEN s.origin
        WHEN r.stop_sequence = 2 THEN 'Central Transit Hub'
        ELSE s.destination
    END,
    DATE_ADD(s.planned_departure, INTERVAL r.arrival_hours HOUR),
    CASE WHEN r.stop_sequence = 1
         THEN s.actual_departure ELSE NULL END,
    DATE_ADD(s.planned_departure, INTERVAL r.departure_hours HOUR),
    CASE WHEN r.stop_sequence = 1
         THEN s.actual_departure ELSE NULL END,
    r.stop_type,
    CASE WHEN r.stop_sequence = 1
         THEN 'DEPARTED' ELSE 'PLANNED' END
FROM shipments s
CROSS JOIN (
    SELECT 1 AS stop_sequence, 'Origin' AS stop_name,
           0 AS arrival_hours, 0 AS departure_hours,
           'ORIGIN' AS stop_type
    UNION ALL
    SELECT 2, 'Transit', 24, 25, 'TRANSIT'
    UNION ALL
    SELECT 3, 'Destination', 48, 48, 'DESTINATION'
) r;

SELECT COUNT(*) AS total_route_stops
FROM route_stops;

USE cold_chain_db;

SELECT COUNT(*) AS total_readings
FROM sensor_readings;


USE cold_chain_db;

INSERT INTO sensor_readings
(
    reading_id,
    sensor_id,
    shipment_id,
    container_id,
    route_stop_id,
    recorded_at,
    temperature_c,
    humidity_pct,
    battery_level,
    signal_strength,
    quality_status,
    received_at
)
WITH RECURSIVE time_slots AS
(
    SELECT 0 AS n

    UNION ALL

    SELECT n + 1
    FROM time_slots
    WHERE n < 575
)
SELECT
    CONCAT(
        'RDG-', a.sensor_id, '-',
        DATE_FORMAT(
            DATE_ADD(s.actual_departure, INTERVAL t.n * 5 MINUTE),
            '%Y%m%d%H%i'
        )
    ),
    a.sensor_id,
    s.shipment_id,
    a.container_id,
    NULL,
    DATE_ADD(s.actual_departure, INTERVAL t.n * 5 MINUTE),
    CASE
        WHEN MOD(t.n, 100) < 5 THEN 9.5
        ELSE ROUND(3.5 + MOD(t.n * 7, 20) / 10, 2)
    END,
    NULL,
    95,
    -65,
    'VALID',
    DATE_ADD(
        s.actual_departure,
        INTERVAL t.n * 5 + 1 MINUTE
    )
FROM
(
    SELECT shipment_id, actual_departure
    FROM shipments
    ORDER BY shipment_id
    LIMIT 10
) s
JOIN shipment_containers sc
    ON sc.shipment_id = s.shipment_id
JOIN container_sensor_assignments a
    ON a.container_id = sc.container_id
   AND a.assignment_status = 'ACTIVE'
CROSS JOIN time_slots t;

SELECT COUNT(*) AS total_readings
FROM sensor_readings;


SELECT
    COUNT(*) AS high_temperature_readings
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies tp
    ON s.product_id = tp.product_id
WHERE sr.temperature_c > tp.max_temperature
  AND sr.quality_status = 'VALID';
  
  
  USE cold_chain_db;

INSERT INTO excursions
(
    excursion_id, shipment_id, sensor_id, policy_id,
    start_reading_id, end_reading_id, excursion_type,
    start_time, end_time, duration_minutes,
    severity, excursion_status, detected_at
)
WITH reading_flags AS
(
    SELECT
        sr.reading_id,
        sr.shipment_id,
        sr.sensor_id,
        sr.recorded_at,
        tp.policy_id,
        tp.max_excursion_minutes,
        CASE WHEN sr.temperature_c > tp.max_temperature
             THEN 1 ELSE 0 END AS is_high,
        LAG(
            CASE WHEN sr.temperature_c > tp.max_temperature
                 THEN 1 ELSE 0 END
        ) OVER (
            PARTITION BY sr.shipment_id, sr.sensor_id
            ORDER BY sr.recorded_at
        ) AS previous_high,
        LAG(sr.recorded_at) OVER (
            PARTITION BY sr.shipment_id, sr.sensor_id
            ORDER BY sr.recorded_at
        ) AS previous_time
    FROM sensor_readings sr
    JOIN shipments s
        ON sr.shipment_id = s.shipment_id
    JOIN threshold_policies tp
        ON s.product_id = tp.product_id
    WHERE sr.quality_status = 'VALID'
),
event_starts AS
(
    SELECT *,
        CASE
            WHEN is_high = 1 AND (
                COALESCE(previous_high, 0) = 0
                OR TIMESTAMPDIFF(
                    MINUTE, previous_time, recorded_at
                ) > 5
            )
            THEN 1 ELSE 0
        END AS new_event
    FROM reading_flags
),
event_groups AS
(
    SELECT *,
        SUM(new_event) OVER (
            PARTITION BY shipment_id, sensor_id
            ORDER BY recorded_at
        ) AS event_number
    FROM event_starts
),
ranked_events AS
(
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY shipment_id, sensor_id, policy_id, event_number
            ORDER BY recorded_at
        ) AS first_row,
        ROW_NUMBER() OVER (
            PARTITION BY shipment_id, sensor_id, policy_id, event_number
            ORDER BY recorded_at DESC
        ) AS last_row
    FROM event_groups
    WHERE is_high = 1
),
event_summary AS
(
    SELECT
        shipment_id,
        sensor_id,
        policy_id,
        event_number,
        MAX(max_excursion_minutes) AS allowed_minutes,
        MIN(recorded_at) AS start_time,
        MAX(recorded_at) AS end_time,
        TIMESTAMPDIFF(
            MINUTE, MIN(recorded_at), MAX(recorded_at)
        ) AS duration_minutes,
        MAX(CASE WHEN first_row = 1 THEN reading_id END)
            AS start_reading_id,
        MAX(CASE WHEN last_row = 1 THEN reading_id END)
            AS end_reading_id
    FROM ranked_events
    GROUP BY shipment_id, sensor_id, policy_id, event_number
)
SELECT
    CONCAT(
        'EXC-', RIGHT(shipment_id, 6), '-',
        LPAD(event_number, 3, '0')
    ),
    shipment_id,
    sensor_id,
    policy_id,
    start_reading_id,
    end_reading_id,
    'TEMPERATURE',
    start_time,
    end_time,
    duration_minutes,
    CASE
        WHEN duration_minutes > allowed_minutes * 2 THEN 'CRITICAL'
        WHEN duration_minutes > allowed_minutes THEN 'HIGH'
        WHEN duration_minutes > 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END,
    'OPEN',
    NOW()
FROM event_summary;



USE cold_chain_db;

INSERT INTO custody_events
(
    custody_event_id,
    shipment_id,
    event_type,
    from_party,
    to_party,
    location,
    event_time,
    received_by,
    evidence_reference,
    remarks
)
SELECT
    CONCAT('CUS-', RIGHT(s.shipment_id, 6), '-', e.event_no),
    s.shipment_id,
    e.event_type,
    e.from_party,
    e.to_party,
    e.location,
    DATE_ADD(s.actual_departure, INTERVAL e.hours_after HOUR),
    e.received_by,
    CONCAT('EVD-', RIGHT(s.shipment_id, 6), '-', e.event_no),
    e.remarks
FROM shipments s
CROSS JOIN
(
    SELECT 1 AS event_no, 'PICKUP' AS event_type,
           'Warehouse' AS from_party, 'Transport Team' AS to_party,
           'Origin' AS location, 0 AS hours_after,
           'Transport Operator' AS received_by,
           'Shipment picked up' AS remarks
    UNION ALL
    SELECT 2, 'HANDOVER',
           'Transport Team', 'Distribution Team',
           'Transit Hub', 24,
           'Distribution Operator',
           'Shipment handed over at transit hub'
    UNION ALL
    SELECT 3, 'DELIVERED',
           'Distribution Team', 'Customer',
           'Destination', 48,
           'Customer Representative',
           'Shipment delivered'
) e;

SELECT
    (SELECT COUNT(*) FROM excursions) AS total_excursions,
    (SELECT COUNT(*) FROM custody_events) AS total_custody_events;

USE cold_chain_db;

INSERT INTO corrective_actions
(
    action_id,
    shipment_id,
    excursion_id,
    action_type,
    description,
    assigned_to,
    opened_at,
    due_at,
    completed_at,
    action_status,
    resolution_notes,
    evidence_reference
)
SELECT
    CONCAT('ACT-', LPAD(ROW_NUMBER() OVER (
        ORDER BY e.excursion_id
    ), 6, '0')),
    e.shipment_id,
    e.excursion_id,
    CASE
        WHEN e.severity IN ('HIGH', 'CRITICAL')
            THEN 'REFRIGERATION_CHECK'
        ELSE 'QUALITY_INSPECTION'
    END,
    CONCAT('Investigate temperature excursion ', e.excursion_id),
    'Quality Engineer',
    e.detected_at,
    DATE_ADD(e.detected_at, INTERVAL 24 HOUR),
    NULL,
    'OPEN',
    NULL,
    CONCAT('EVIDENCE-', e.excursion_id)
FROM excursions e;


SELECT 'products' AS table_name, COUNT(*) AS total_records FROM products
UNION ALL
SELECT 'shipments', COUNT(*) FROM shipments
UNION ALL
SELECT 'containers', COUNT(*) FROM containers
UNION ALL
SELECT 'sensors', COUNT(*) FROM sensors
UNION ALL
SELECT 'threshold_policies', COUNT(*) FROM threshold_policies
UNION ALL
SELECT 'shipment_containers', COUNT(*) FROM shipment_containers
UNION ALL
SELECT 'route_stops', COUNT(*) FROM route_stops
UNION ALL
SELECT 'container_sensor_assignments', COUNT(*) FROM container_sensor_assignments
UNION ALL
SELECT 'sensor_readings', COUNT(*) FROM sensor_readings
UNION ALL
SELECT 'excursions', COUNT(*) FROM excursions
UNION ALL
SELECT 'custody_events', COUNT(*) FROM custody_events
UNION ALL
SELECT 'corrective_actions', COUNT(*) FROM corrective_actions;

SELECT
    s.shipment_id,
    s.product_id,
    p.product_name,
    s.origin,
    s.destination,
    s.status
FROM shipments s
JOIN products p
    ON s.product_id = p.product_id
LIMIT 10;

SELECT
    s.shipment_id,
    s.product_id
FROM shipments s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;
SELECT
    sr.reading_id,
    sr.sensor_id
FROM sensor_readings sr
LEFT JOIN sensors s
    ON sr.sensor_id = s.sensor_id
WHERE s.sensor_id IS NULL;

SELECT
    sr.reading_id,
    sr.shipment_id
FROM sensor_readings sr
LEFT JOIN shipments s
    ON sr.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;

SELECT
    e.excursion_id,
    e.shipment_id
FROM excursions e
LEFT JOIN shipments s
    ON e.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;

SELECT
    ca.action_id,
    ca.shipment_id
FROM corrective_actions ca
LEFT JOIN shipments s
    ON ca.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;

SELECT
    e.excursion_id,
    e.sensor_id
FROM excursions e
LEFT JOIN sensors s
    ON e.sensor_id = s.sensor_id
WHERE s.sensor_id IS NULL;

SELECT
    e.excursion_id,
    e.policy_id
FROM excursions e
LEFT JOIN threshold_policies tp
    ON e.policy_id = tp.policy_id
WHERE tp.policy_id IS NULL;

SELECT
    sc.shipment_id,
    sc.container_id
FROM shipment_containers sc
LEFT JOIN containers c
    ON sc.container_id = c.container_id
WHERE c.container_id IS NULL;

 SELECT
    csa.assignment_id,
    csa.container_id,
    csa.sensor_id
FROM container_sensor_assignments csa
LEFT JOIN sensors s
    ON csa.sensor_id = s.sensor_id
WHERE s.sensor_id IS NULL; 


SELECT
    rs.route_stop_id,
    rs.shipment_id
FROM route_stops rs
LEFT JOIN shipments s
    ON rs.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;

SELECT
    ce.custody_event_id,
    ce.shipment_id
FROM custody_events ce
LEFT JOIN shipments s
    ON ce.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;

SELECT
    ca.action_id,
    ca.excursion_id
FROM corrective_actions ca
LEFT JOIN excursions e
    ON ca.excursion_id = e.excursion_id
WHERE ca.excursion_id IS NOT NULL
  AND e.excursion_id IS NULL;
  
  SELECT
    COUNT(*) AS total_readings,
    SUM(temperature_c IS NULL) AS missing_temperature
FROM sensor_readings;

SELECT
    COUNT(*) AS total_readings,
    SUM(humidity_pct IS NULL) AS missing_humidity
FROM sensor_readings;

SELECT
    quality_status,
    COUNT(*) AS total
FROM sensor_readings
GROUP BY quality_status;


SELECT
    severity,
    COUNT(*) AS total_excursions
FROM excursions
GROUP BY severity
ORDER BY total_excursions DESC;

SELECT
    excursion_status,
    COUNT(*) AS total_excursions
FROM excursions
GROUP BY excursion_status;
SELECT
    status,
    COUNT(*) AS total_shipments
FROM shipments
GROUP BY status;

SELECT
    s.shipment_id,
    s.status,
    s.actual_delivery,
    ce.event_type,
    ce.event_time
FROM shipments s
JOIN custody_events ce
    ON s.shipment_id = ce.shipment_id
WHERE ce.event_type = 'DELIVERED'
  AND s.status = 'IN_TRANSIT'
LIMIT 10;

UPDATE shipments s
JOIN custody_events ce
    ON s.shipment_id = ce.shipment_id
SET
    s.status = 'DELIVERED',
    s.actual_delivery = ce.event_time
WHERE s.shipment_id LIKE 'SHP-2026-%'
  AND ce.event_type = 'DELIVERED'
  AND s.status = 'IN_TRANSIT';
  
  SELECT
    status,
    COUNT(*) AS total_shipments
FROM shipments
GROUP BY status;

SELECT
    COUNT(*) AS total_delivered,
    SUM(actual_delivery IS NULL) AS missing_delivery_time
FROM shipments
WHERE status = 'DELIVERED';

SELECT
    status,
    COUNT(*) AS total_stops
FROM route_stops
WHERE stop_type = 'DESTINATION'
GROUP BY status;


UPDATE route_stops rs
JOIN shipments s
    ON rs.shipment_id = s.shipment_id
SET
    rs.status = 'ARRIVED',
    rs.actual_arrival = s.actual_delivery
WHERE rs.route_stop_id LIKE 'RST-%'
  AND rs.stop_type = 'DESTINATION'
  AND s.status = 'DELIVERED';
  
  UPDATE route_stops rs
JOIN shipments s
    ON rs.shipment_id = s.shipment_id
SET
    rs.status = 'ARRIVED',
    rs.actual_arrival = s.actual_delivery
WHERE rs.shipment_id LIKE 'SHP-2026-%'
  AND rs.stop_type = 'DESTINATION'
  AND s.status = 'DELIVERED';
  
  SELECT
    status,
    COUNT(*) AS total_stops
FROM route_stops
WHERE stop_type = 'DESTINATION'
GROUP BY status;


SELECT
    COUNT(*) AS inconsistent_shipments
FROM shipments s
JOIN route_stops rs
    ON s.shipment_id = rs.shipment_id
WHERE s.status = 'DELIVERED'
  AND rs.stop_type = 'DESTINATION'
  AND rs.status <> 'ARRIVED';
  
  SELECT
    assignment_status,
    COUNT(*) AS total_assignments
FROM shipment_containers
GROUP BY assignment_status;

SELECT
    COUNT(*) AS active_assignments
FROM shipment_containers sc
JOIN shipments s
    ON sc.shipment_id = s.shipment_id
WHERE s.status = 'DELIVERED'
  AND sc.assignment_status = 'ACTIVE';
  
  SELECT
    calibration_status,
    COUNT(*) AS total_sensors
FROM sensors
GROUP BY calibration_status;

SELECT
    COUNT(*) AS invalid_container_assignments
FROM container_sensor_assignments csa
LEFT JOIN containers c
    ON csa.container_id = c.container_id
WHERE c.container_id IS NULL;


SELECT
    COUNT(*) AS invalid_container_assignments
FROM container_sensor_assignments csa
LEFT JOIN containers c
    ON csa.container_id = c.container_id
WHERE c.container_id IS NULL;

SELECT
    COUNT(*) AS invalid_sensor_assignments
FROM container_sensor_assignments csa
LEFT JOIN sensors s
    ON csa.sensor_id = s.sensor_id
WHERE s.sensor_id IS NULL;

SELECT
    COUNT(*) AS readings_before_departure
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
WHERE sr.recorded_at < s.actual_departure;

SELECT
    COUNT(*) AS readings_after_delivery
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
WHERE sr.recorded_at > s.actual_delivery;


-- STEP 38: Readings recorded after delivery
SELECT
    '38 - Readings After Delivery' AS validation,
    COUNT(*) AS result
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
WHERE sr.recorded_at > s.actual_delivery;

-- STEP 39: Duplicate sensor readings
SELECT
    '39 - Duplicate Sensor Readings' AS validation,
    COUNT(*) AS result
FROM (
    SELECT sensor_id, shipment_id, recorded_at
    FROM sensor_readings
    GROUP BY sensor_id, shipment_id, recorded_at
    HAVING COUNT(*) > 1
) AS duplicates_found;

-- STEP 40: Invalid temperature readings
SELECT
    '40 - Invalid Temperature Readings' AS validation,
    COUNT(*) AS result
FROM sensor_readings
WHERE temperature_c < -50
   OR temperature_c > 60;

-- STEP 41: Invalid humidity readings
SELECT
    '41 - Invalid Humidity Readings' AS validation,
    COUNT(*) AS result
FROM sensor_readings
WHERE humidity_pct < 0
   OR humidity_pct > 100;

-- STEP 42: Missing or negative excursion duration
SELECT
    '42 - Invalid Excursion Durations' AS validation,
    COUNT(*) AS result
FROM excursions
WHERE duration_minutes IS NULL
   OR duration_minutes < 0;

-- STEP 43: Excursions without corrective actions
SELECT
    '43 - Excursions Without Actions' AS validation,
    COUNT(*) AS result
FROM excursions e
LEFT JOIN corrective_actions ca
    ON e.excursion_id = ca.excursion_id
WHERE ca.action_id IS NULL;

-- STEP 44: Delivered shipments without delivery timestamps
SELECT
    '44 - Missing Delivery Timestamps' AS validation,
    COUNT(*) AS result
FROM shipments
WHERE status = 'DELIVERED'
  AND actual_delivery IS NULL;

-- STEP 45: Delivered shipments with destination stops not arrived
SELECT
    '45 - Inconsistent Destination Stops' AS validation,
    COUNT(*) AS result
FROM route_stops rs
JOIN shipments s
    ON rs.shipment_id = s.shipment_id
WHERE rs.stop_type = 'DESTINATION'
  AND s.status = 'DELIVERED'
  AND rs.status <> 'ARRIVED';

-- STEP 46: Final table record counts
SELECT 'products' AS table_name, COUNT(*) AS total_rows FROM products
UNION ALL
SELECT 'shipments', COUNT(*) FROM shipments
UNION ALL
SELECT 'containers', COUNT(*) FROM containers
UNION ALL
SELECT 'sensors', COUNT(*) FROM sensors
UNION ALL
SELECT 'threshold_policies', COUNT(*) FROM threshold_policies
UNION ALL
SELECT 'shipment_containers', COUNT(*) FROM shipment_containers
UNION ALL
SELECT 'route_stops', COUNT(*) FROM route_stops
UNION ALL
SELECT 'container_sensor_assignments', COUNT(*) FROM container_sensor_assignments
UNION ALL
SELECT 'sensor_readings', COUNT(*) FROM sensor_readings
UNION ALL
SELECT 'excursions', COUNT(*) FROM excursions
UNION ALL
SELECT 'custody_events', COUNT(*) FROM custody_events
UNION ALL
SELECT 'corrective_actions', COUNT(*) FROM corrective_actions;
DESCRIBE sensor_readings;
DESCRIBE excursions;
DESCRIBE corrective_actions;

SELECT
    COUNT(*) AS total_readings,
    COUNT(temperature_c) AS temperature_readings,
    COUNT(humidity_pct) AS humidity_readings
FROM sensor_readings;
DESCRIBE threshold_policies;
SELECT
    product_id,
    min_humidity,
    max_humidity,
    policy_status
FROM threshold_policies;
DESCRIBE excursions;

SELECT
    excursion_type,
    COUNT(*) AS total_excursions
FROM excursions
GROUP BY excursion_type;

SELECT
    COUNT(*) AS total_readings,
    COUNT(DISTINCT shipment_id) AS shipments,
    COUNT(DISTINCT sensor_id) AS sensors,
    MIN(recorded_at) AS first_reading,
    MAX(recorded_at) AS last_reading
FROM sensor_readings;

DESCRIBE sensor_readings;

USE cold_chain_db;

SELECT
    product_id,
    min_humidity,
    max_humidity,
    policy_status
FROM threshold_policies
WHERE policy_status = 'ACTIVE';

SELECT
    COUNT(*) AS total_readings,
    COUNT(DISTINCT sr.shipment_id) AS total_shipments,
    COUNT(DISTINCT s.product_id) AS total_products,
    COUNT(p.policy_id) AS matched_policies
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE';
   
   USE cold_chain_db;

UPDATE sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'
SET sr.humidity_pct =
    ROUND(
        p.min_humidity +
        MOD(
            CRC32(CONCAT(sr.reading_id, '-', sr.shipment_id)),
            FLOOR((p.max_humidity - p.min_humidity) * 100) + 1
        ) / 100,
        2
    )
WHERE sr.humidity_pct IS NULL;

SELECT
    COUNT(*) AS total_readings,
    COUNT(humidity_pct) AS humidity_readings,
    ROUND(AVG(humidity_pct), 2) AS average_humidity,
    MIN(humidity_pct) AS minimum_humidity,
    MAX(humidity_pct) AS maximum_humidity
FROM sensor_readings;

SELECT
    sr.reading_id,
    sr.shipment_id,
    sr.humidity_pct,
    s.product_id,
    p.min_humidity,
    p.max_humidity
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'
LIMIT 10;

USE cold_chain_db;

UPDATE sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'
SET sr.humidity_pct = ROUND(
    p.min_humidity +
    RAND() * (p.max_humidity - p.min_humidity),
    2
)
WHERE sr.humidity_pct IS NULL;

SELECT
    COUNT(*) AS total_readings,
    COUNT(humidity_pct) AS humidity_readings,
    ROUND(AVG(humidity_pct), 2) AS average_humidity,
    MIN(humidity_pct) AS minimum_humidity,
    MAX(humidity_pct) AS maximum_humidity
FROM sensor_readings;

USE cold_chain_db;

USE cold_chain_db;

-- Temporarily disable safe update mode
SET SQL_SAFE_UPDATES = 0;

-- Update humidity values
UPDATE sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
SET sr.humidity_pct =
    ROUND(
        p.min_humidity +
        RAND() * (p.max_humidity - p.min_humidity),
        2
    )
WHERE sr.humidity_pct IS NULL
  AND p.policy_status = 'ACTIVE';

-- Enable safe update mode again
SET SQL_SAFE_UPDATES = 1;

SELECT
    COUNT(*) AS total_readings,
    COUNT(humidity_pct) AS humidity_readings,
    ROUND(AVG(humidity_pct), 2) AS average_humidity,
    MIN(humidity_pct) AS minimum_humidity,
    MAX(humidity_pct) AS maximum_humidity
FROM sensor_readings;


USE cold_chain_db;

SELECT
    s.product_id,
    COUNT(*) AS total_readings,
    SUM(
        CASE
            WHEN sr.humidity_pct < p.min_humidity
              OR sr.humidity_pct > p.max_humidity
            THEN 1
            ELSE 0
        END
    ) AS humidity_violations
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'
WHERE sr.humidity_pct IS NOT NULL
GROUP BY s.product_id
ORDER BY s.product_id;


SELECT
    s.product_id,
    COUNT(*) AS total_readings,
    SUM(
        CASE
            WHEN sr.temperature_c < p.min_temperature
              OR sr.temperature_c > p.max_temperature
            THEN 1
            ELSE 0
        END
    ) AS temperature_violations
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'
GROUP BY s.product_id
ORDER BY s.product_id;

SELECT
    s.product_id,
    p.min_temperature,
    p.max_temperature,
    MIN(sr.temperature_c) AS actual_min_temperature,
    MAX(sr.temperature_c) AS actual_max_temperature,
    ROUND(AVG(sr.temperature_c), 2) AS average_temperature,
    COUNT(*) AS total_readings
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'
GROUP BY
    s.product_id,
    p.min_temperature,
    p.max_temperature
ORDER BY s.product_id;

SELECT
    s.product_id,
    SUM(CASE
        WHEN sr.temperature_c < p.min_temperature
        THEN 1 ELSE 0
    END) AS below_limit,

    SUM(CASE
        WHEN sr.temperature_c BETWEEN
             p.min_temperature AND p.max_temperature
        THEN 1 ELSE 0
    END) AS within_limit,

    SUM(CASE
        WHEN sr.temperature_c > p.max_temperature
        THEN 1 ELSE 0
    END) AS above_limit

FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies p
    ON s.product_id = p.product_id
   AND p.policy_status = 'ACTIVE'

GROUP BY s.product_id
ORDER BY s.product_id;

SELECT
    s.product_id,
    sr.temperature_c,
    COUNT(*) AS reading_count
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
GROUP BY
    s.product_id,
    sr.temperature_c
ORDER BY
    s.product_id,
    sr.temperature_c;
    
    SELECT
    sr.shipment_id,
    s.product_id,
    COUNT(*) AS high_temperature_readings,
    MIN(sr.recorded_at) AS first_high_reading,
    MAX(sr.recorded_at) AS last_high_reading
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
WHERE sr.temperature_c = 9.50
GROUP BY
    sr.shipment_id,
    s.product_id
ORDER BY
    sr.shipment_id;
    
SELECT
    excursion_id,
    shipment_id,
    excursion_type,
    start_time,
    end_time,
    duration_minutes,
    severity,
    excursion_status
FROM excursions
WHERE excursion_type = 'TEMPERATURE'
ORDER BY shipment_id, start_time;


SELECT
    e.excursion_id,
    e.shipment_id,
    e.duration_minutes,
    e.start_reading_id,
    sr1.recorded_at AS actual_start_time,
    sr1.temperature_c AS start_temperature,
    e.end_reading_id,
    sr2.recorded_at AS actual_end_time,
    sr2.temperature_c AS end_temperature
FROM excursions e
LEFT JOIN sensor_readings sr1
    ON e.start_reading_id = sr1.reading_id
LEFT JOIN sensor_readings sr2
    ON e.end_reading_id = sr2.reading_id
WHERE e.excursion_type = 'TEMPERATURE'
ORDER BY e.shipment_id, e.start_time;


SELECT
    e.excursion_id,
    e.shipment_id,
    s.product_id,
    e.policy_id AS excursion_policy_id,
    tp.policy_id AS product_policy_id,
    tp.min_temperature,
    tp.max_temperature
FROM excursions e
JOIN shipments s
    ON e.shipment_id = s.shipment_id
JOIN threshold_policies tp
    ON e.policy_id = tp.policy_id
WHERE e.excursion_type = 'TEMPERATURE'
ORDER BY e.shipment_id, e.start_time;


SELECT
    s.product_id,
    COUNT(*) AS total_readings,
    SUM(CASE
        WHEN sr.temperature_c < tp.min_temperature THEN 1
        ELSE 0
    END) AS below_limit,
    SUM(CASE
        WHEN sr.temperature_c BETWEEN tp.min_temperature
             AND tp.max_temperature THEN 1
        ELSE 0
    END) AS within_limit,
    SUM(CASE
        WHEN sr.temperature_c > tp.max_temperature THEN 1
        ELSE 0
    END) AS above_limit
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies tp
    ON s.product_id = tp.product_id
   AND tp.policy_status = 'ACTIVE'
GROUP BY s.product_id
ORDER BY s.product_id;

DESCRIBE shipments;

SELECT
    shipment_id,
    planned_departure,
    actual_departure,
    planned_delivery,
    actual_delivery,
    status,
    CASE
        WHEN actual_delivery < actual_departure
        THEN 'DELIVERED BEFORE DEPARTURE'
        ELSE 'OK'
    END AS timeline_check
FROM shipments
WHERE actual_departure IS NOT NULL
  AND actual_delivery IS NOT NULL
ORDER BY shipment_id
LIMIT 20;


SELECT
    COUNT(*) AS total_shipments,
    SUM(
        CASE
            WHEN actual_delivery < actual_departure THEN 1
            ELSE 0
        END
    ) AS delivered_before_departure,
    SUM(
        CASE
            WHEN actual_delivery = actual_departure THEN 1
            ELSE 0
        END
    ) AS same_time,
    SUM(
        CASE
            WHEN actual_delivery > actual_departure THEN 1
            ELSE 0
        END
    ) AS delivered_after_departure
FROM shipments
WHERE actual_departure IS NOT NULL
  AND actual_delivery IS NOT NULL;
  
  SELECT
    shipment_id,
    COUNT(*) AS total_readings,
    MIN(recorded_at) AS first_reading,
    MAX(recorded_at) AS last_reading,
    TIMESTAMPDIFF(
        MINUTE,
        MIN(recorded_at),
        MAX(recorded_at)
    ) AS total_minutes
FROM sensor_readings
GROUP BY shipment_id
ORDER BY shipment_id
LIMIT 10;

use cold_chain_db;

WITH reading_gaps AS (
    SELECT
        shipment_id,
        recorded_at,
        LAG(recorded_at) OVER (
            PARTITION BY shipment_id
            ORDER BY recorded_at
        ) AS previous_reading
    FROM sensor_readings
)
SELECT
    shipment_id,
    previous_reading,
    recorded_at,
    TIMESTAMPDIFF(
        MINUTE,
        previous_reading,
        recorded_at
    ) AS gap_minutes
FROM reading_gaps
WHERE previous_reading IS NOT NULL
  AND TIMESTAMPDIFF(
        MINUTE,
        previous_reading,
        recorded_at
      ) > 5
ORDER BY shipment_id, recorded_at;

SELECT
    quality_status,
    COUNT(*) AS total_readings
FROM sensor_readings
GROUP BY quality_status;


SELECT
    COUNT(*) AS total_readings,
    SUM(CASE
        WHEN temperature_c < -50 OR temperature_c > 60
        THEN 1 ELSE 0
    END) AS invalid_temperature_readings,
    SUM(CASE
        WHEN humidity_pct < 0 OR humidity_pct > 100
        THEN 1 ELSE 0
    END) AS invalid_humidity_readings
FROM sensor_readings;

SELECT
    COUNT(*) AS total_readings,
    SUM(CASE WHEN temperature_c IS NULL THEN 1 ELSE 0 END) AS missing_temperature,
    SUM(CASE WHEN humidity_pct IS NULL THEN 1 ELSE 0 END) AS missing_humidity
FROM sensor_readings;

SELECT
    s.shipment_id,
    s.product_id,
    COUNT(*) AS total_readings,
    SUM(CASE
        WHEN sr.temperature_c < tp.min_temperature THEN 1
        ELSE 0
    END) AS below_minimum,
    SUM(CASE
        WHEN sr.temperature_c > tp.max_temperature THEN 1
        ELSE 0
    END) AS above_maximum,
    SUM(CASE
        WHEN sr.temperature_c BETWEEN tp.min_temperature AND tp.max_temperature THEN 1
        ELSE 0
    END) AS within_range
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies tp
    ON s.product_id = tp.product_id
   AND tp.policy_status = 'ACTIVE'
GROUP BY
    s.shipment_id,
    s.product_id
ORDER BY s.shipment_id;

SELECT
    s.product_id,
    COUNT(*) AS total_readings,
    SUM(
        CASE
            WHEN sr.humidity_pct < tp.min_humidity
              OR sr.humidity_pct > tp.max_humidity
            THEN 1
            ELSE 0
        END
    ) AS humidity_violations,
    SUM(
        CASE
            WHEN sr.humidity_pct BETWEEN tp.min_humidity AND tp.max_humidity
            THEN 1
            ELSE 0
        END
    ) AS within_range
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies tp
    ON s.product_id = tp.product_id
   AND tp.policy_status = 'ACTIVE'
GROUP BY s.product_id
ORDER BY s.product_id;

SELECT
    reading_id,
    shipment_id,
    sensor_id,
    recorded_at,
    temperature_c,
    humidity_pct,
    quality_status
FROM sensor_readings
WHERE temperature_c < -50
   OR temperature_c > 60
   OR humidity_pct < 0
   OR humidity_pct > 100
ORDER BY recorded_at
LIMIT 20;

SELECT
    reading_id,
    shipment_id,
    temperature_c,
    humidity_pct,
    recorded_at
FROM sensor_readings
ORDER BY reading_id
LIMIT 5;


UPDATE sensor_readings
SET
    temperature_c = 75.00,
    quality_status = 'SUSPICIOUS'
WHERE reading_id = 'RDG-SNS-CNT-000001-202601010600';
SELECT
    reading_id,
    shipment_id,
    temperature_c,
    humidity_pct,
    quality_status,
    recorded_at
FROM sensor_readings
WHERE reading_id = 'RDG-SNS-CNT-000001-202601010600';

SELECT
    reading_id,
    shipment_id,
    recorded_at,
    temperature_c,
    quality_status
FROM sensor_readings
WHERE shipment_id = 'SHP-2026-000001'
  AND recorded_at BETWEEN '2026-01-01 06:20:00'
                      AND '2026-01-01 06:35:00'
ORDER BY recorded_at;

SELECT
    shipment_id,
    actual_departure,
    actual_delivery,
    status
FROM shipments
WHERE actual_delivery < actual_departure;

UPDATE shipments
SET actual_delivery = DATE_SUB(actual_departure, INTERVAL 1 HOUR)
WHERE shipment_id = 'SHP-2026-000001';


SELECT
    shipment_id,
    actual_departure,
    actual_delivery,
    TIMESTAMPDIFF(
        MINUTE,
        actual_delivery,
        actual_departure
    ) AS delivered_before_departure_minutes
FROM shipments
WHERE shipment_id = 'SHP-2026-000001';

SELECT
    sr.shipment_id,
    s.product_id,
    sr.sensor_id,
    tp.policy_id,
    tp.min_temperature,
    tp.max_temperature
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id
JOIN threshold_policies tp
    ON s.product_id = tp.product_id
   AND tp.policy_status = 'ACTIVE'
WHERE sr.shipment_id = 'SHP-2026-000001'
LIMIT 5;

SELECT
    s.shipment_id,
    s.product_id,
    tp.policy_id,
    tp.min_temperature,
    tp.max_temperature,
    tp.policy_status
FROM shipments s
JOIN threshold_policies tp
    ON s.product_id = tp.product_id
WHERE s.shipment_id = 'SHP-2026-000001'
ORDER BY tp.effective_from DESC;
SELECT
    policy_id,
    product_id,
    min_temperature,
    max_temperature,
    min_humidity,
    max_humidity,
    policy_status
FROM threshold_policies
WHERE policy_status = 'ACTIVE'
ORDER BY product_id;

SELECT
    s.shipment_id,
    s.product_id,
    correct.policy_id AS correct_policy,
    correct.min_temperature AS correct_min,
    correct.max_temperature AS correct_max,
    wrong.policy_id AS wrong_policy,
    wrong.min_temperature AS wrong_min,
    wrong.max_temperature AS wrong_max
FROM shipments s
JOIN threshold_policies correct
    ON correct.product_id = s.product_id
   AND correct.policy_status = 'ACTIVE'
JOIN threshold_policies wrong
    ON wrong.policy_id = 'POL-0004'
WHERE s.shipment_id = 'SHP-2026-000001';


SELECT
    excursion_id,
    shipment_id,
    start_time,
    end_time,
    duration_minutes,
    TIMESTAMPDIFF(
        MINUTE,
        start_time,
        end_time
    ) AS actual_duration_minutes
FROM excursions
ORDER BY duration_minutes DESC
LIMIT 10;

UPDATE excursions
SET duration_minutes = 60
WHERE excursion_id = 'EXC-000009-001';

SELECT
    excursion_id,
    shipment_id,
    start_time,
    end_time,
    duration_minutes AS recorded_duration,
    TIMESTAMPDIFF(
        MINUTE,
        start_time,
        end_time
    ) AS actual_duration,
    TIMESTAMPDIFF(
        MINUTE,
        start_time,
        end_time
    ) - duration_minutes AS undercounted_minutes
FROM excursions
WHERE excursion_id = 'EXC-000009-001';

SELECT
    sr.reading_id,
    sr.shipment_id,
    sr.recorded_at,
    sr.temperature_c,
    e.excursion_id
FROM sensor_readings sr
LEFT JOIN excursions e
    ON sr.reading_id = e.start_reading_id
    OR sr.reading_id = e.end_reading_id
WHERE sr.shipment_id = 'SHP-2026-000001'
  AND sr.recorded_at = '2026-01-01 06:25:00';
  
  SELECT
    shipment_id,
    COUNT(*) AS total_readings,
    MIN(recorded_at) AS first_reading,
    MAX(recorded_at) AS last_reading,
    TIMESTAMPDIFF(
        MINUTE,
        MIN(recorded_at),
        MAX(recorded_at)
    ) AS total_duration_minutes
FROM sensor_readings
GROUP BY shipment_id
ORDER BY shipment_id
LIMIT 10;

SELECT
    sr.reading_id,
    sr.shipment_id,
    sr.recorded_at,
    sr.temperature_c
FROM sensor_readings sr
LEFT JOIN excursions e
    ON sr.reading_id = e.start_reading_id
    OR sr.reading_id = e.end_reading_id
WHERE sr.shipment_id = 'SHP-2026-000001'
  AND sr.recorded_at = '2026-01-01 06:25:00'
  AND e.excursion_id IS NULL;
  
  WITH reading_gaps AS (
    SELECT
        shipment_id,
        recorded_at,
        LAG(recorded_at) OVER (
            PARTITION BY shipment_id
            ORDER BY recorded_at
        ) AS previous_reading
    FROM sensor_readings
)
SELECT
    shipment_id,
    previous_reading,
    recorded_at,
    TIMESTAMPDIFF(
        MINUTE,
        previous_reading,
        recorded_at
    ) AS gap_minutes
FROM reading_gaps
WHERE previous_reading IS NOT NULL
  AND TIMESTAMPDIFF(
      MINUTE,
      previous_reading,
      recorded_at
  ) > 5
ORDER BY shipment_id, recorded_at;

SELECT
    sr.reading_id,
    sr.recorded_at,
    e.excursion_id
FROM sensor_readings sr
LEFT JOIN excursions e
    ON sr.reading_id = e.start_reading_id
    OR sr.reading_id = e.end_reading_id
WHERE sr.shipment_id = 'SHP-2026-000001'
  AND sr.recorded_at = '2026-01-01 06:25:00';
  
DELETE FROM sensor_readings
WHERE reading_id = 'RDG-SNS-CNT-000001-202601010625';

WITH reading_gaps AS (
    SELECT
        shipment_id,
        recorded_at,
        LAG(recorded_at) OVER (
            PARTITION BY shipment_id
            ORDER BY recorded_at
        ) AS previous_reading
    FROM sensor_readings
)
SELECT
    shipment_id,
    previous_reading,
    recorded_at,
    TIMESTAMPDIFF(
        MINUTE,
        previous_reading,
        recorded_at
    ) AS gap_minutes
FROM reading_gaps
WHERE shipment_id = 'SHP-2026-000001'
  AND previous_reading IS NOT NULL
  AND TIMESTAMPDIFF(
      MINUTE,
      previous_reading,
      recorded_at
  ) > 5;
  SELECT 'Physical range violation' AS anomaly,
       COUNT(*) AS affected_records
FROM sensor_readings
WHERE temperature_c < -50 OR temperature_c > 60
   OR humidity_pct < 0 OR humidity_pct > 100

UNION ALL

SELECT 'Missing sensor interval',
       COUNT(*)
FROM (
    SELECT
        shipment_id,
        recorded_at,
        LAG(recorded_at) OVER (
            PARTITION BY shipment_id ORDER BY recorded_at
        ) AS previous_reading
    FROM sensor_readings
) AS gaps
WHERE TIMESTAMPDIFF(MINUTE, previous_reading, recorded_at) > 5

UNION ALL

SELECT 'Delivered before departure',
       COUNT(*)
FROM shipments
WHERE actual_delivery < actual_departure

UNION ALL

SELECT 'Wrong excursion policy',
       COUNT(*)
FROM excursions e
JOIN shipments s ON e.shipment_id = s.shipment_id
JOIN threshold_policies tp ON e.policy_id = tp.policy_id
WHERE tp.product_id <> s.product_id

UNION ALL

SELECT 'Undercounted excursion duration',
       COUNT(*)
FROM excursions
WHERE duration_minutes < TIMESTAMPDIFF(
    MINUTE, start_time, end_time
);
  