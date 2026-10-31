
USE cold_chain_db;

-- =========================================
-- 1. JOIN QUERIES
-- =========================================

-- Query 1: Shipment and Product Details
SELECT
    s.shipment_id,
    p.product_name,
    s.origin,
    s.destination,
    s.status
FROM shipments s
JOIN products p ON s.product_id = p.product_id;

-- Query 2: Shipment and Container Details
SELECT
    s.shipment_id,
    c.container_id,
    c.container_type,
    c.manufacturer,
    sc.assignment_status
FROM shipments s
JOIN shipment_containers sc
    ON s.shipment_id = sc.shipment_id
JOIN containers c
    ON sc.container_id = c.container_id;

-- Query 3: Sensor Reading Details
SELECT
    sr.reading_id,
    sr.shipment_id,
    sr.sensor_id,
    sr.recorded_at,
    sr.temperature_c,
    sr.quality_status
FROM sensor_readings sr
JOIN shipments s
    ON sr.shipment_id = s.shipment_id;

-- Query 4: Excursion Details with Product
SELECT
    e.excursion_id,
    e.shipment_id,
    p.product_name,
    e.excursion_type,
    e.duration_minutes,
    e.severity,
    e.excursion_status
FROM excursions e
JOIN shipments s ON e.shipment_id = s.shipment_id
JOIN products p ON s.product_id = p.product_id;

-- Query 5: Corrective Actions and Excursions
SELECT
    ca.action_id,
    ca.shipment_id,
    ca.action_type,
    ca.assigned_to,
    ca.action_status,
    e.excursion_id,
    e.severity
FROM corrective_actions ca
LEFT JOIN excursions e
    ON ca.excursion_id = e.excursion_id;


-- =========================================
-- 2. GROUP BY AND AGGREGATE FUNCTIONS
-- =========================================

-- Query 6: Shipment Count by Status
SELECT
    status,
    COUNT(*) AS total_shipments
FROM shipments
GROUP BY status;

-- Query 7: Shipment Count by Product
SELECT
    p.product_name,
    COUNT(s.shipment_id) AS total_shipments
FROM products p
LEFT JOIN shipments s
    ON p.product_id = s.product_id
GROUP BY p.product_id, p.product_name;

-- Query 8: Average Temperature by Shipment
SELECT
    shipment_id,
    ROUND(AVG(temperature_c), 2) AS average_temperature
FROM sensor_readings
GROUP BY shipment_id;

-- Query 9: Maximum and Minimum Temperature
SELECT
    shipment_id,
    MAX(temperature_c) AS maximum_temperature,
    MIN(temperature_c) AS minimum_temperature
FROM sensor_readings
GROUP BY shipment_id;

-- Query 10: Excursion Count by Severity
SELECT
    severity,
    COUNT(*) AS total_excursions
FROM excursions
GROUP BY severity;

-- Query 11: Corrective Actions by Status
SELECT
    action_status,
    COUNT(*) AS total_actions
FROM corrective_actions
GROUP BY action_status;

-- Query 12: Shipments with More Than One Excursion
SELECT
    shipment_id,
    COUNT(*) AS total_excursions
FROM excursions
GROUP BY shipment_id
HAVING COUNT(*) > 1;


-- =========================================
-- 3. SUBQUERIES
-- =========================================

-- Query 13: Readings Above Average Temperature
SELECT *
FROM sensor_readings
WHERE temperature_c > (
    SELECT AVG(temperature_c)
    FROM sensor_readings
);

-- Query 14: Products Having Shipments
SELECT *
FROM products
WHERE product_id IN (
    SELECT product_id
    FROM shipments
);

-- Query 15: Shipments Having Excursions
SELECT *
FROM shipments
WHERE shipment_id IN (
    SELECT shipment_id
    FROM excursions
);

-- Query 16: Shipments Without Excursions
SELECT *
FROM shipments
WHERE shipment_id NOT IN (
    SELECT shipment_id
    FROM excursions
);


-- =========================================
-- 4. VIEWS
-- =========================================

-- Query 17: Shipment Details View
CREATE OR REPLACE VIEW shipment_details_view AS
SELECT
    s.shipment_id,
    p.product_name,
    s.origin,
    s.destination,
    s.status,
    s.planned_departure,
    s.actual_delivery
FROM shipments s
JOIN products p
    ON s.product_id = p.product_id;

SELECT * FROM shipment_details_view;


-- Query 18: Excursion Report View
CREATE OR REPLACE VIEW excursion_report_view AS
SELECT
    e.excursion_id,
    e.shipment_id,
    p.product_name,
    e.excursion_type,
    e.duration_minutes,
    e.severity,
    e.excursion_status
FROM excursions e
JOIN shipments s
    ON e.shipment_id = s.shipment_id
JOIN products p
    ON s.product_id = p.product_id;

SELECT * FROM excursion_report_view;


-- =========================================
-- 5. STORED PROCEDURES
-- =========================================

DROP PROCEDURE IF EXISTS GetShipmentDetails;

DELIMITER //

CREATE PROCEDURE GetShipmentDetails(
    IN input_shipment_id VARCHAR(30)
)
BEGIN
    SELECT
        s.shipment_id,
        p.product_name,
        s.origin,
        s.destination,
        s.status
    FROM shipments s
    JOIN products p
        ON s.product_id = p.product_id
    WHERE s.shipment_id = input_shipment_id;
END //

DELIMITER ;

CALL GetShipmentDetails('SHP-2026-000001');


DROP PROCEDURE IF EXISTS GetExcursionsBySeverity;

DELIMITER //

CREATE PROCEDURE GetExcursionsBySeverity(
    IN input_severity VARCHAR(20)
)
BEGIN
    SELECT *
    FROM excursions
    WHERE severity = input_severity;
END //

DELIMITER ;

CALL GetExcursionsBySeverity('HIGH');


-- =========================================
-- 6. TRIGGERS
-- =========================================

DROP TRIGGER IF EXISTS check_temperature_before_insert;

DELIMITER //

CREATE TRIGGER check_temperature_before_insert
BEFORE INSERT ON sensor_readings
FOR EACH ROW
BEGIN
    IF NEW.temperature_c IS NOT NULL
       AND (NEW.temperature_c < -50 OR NEW.temperature_c > 60)
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid temperature reading';
    END IF;
END //

DELIMITER ;


DROP TRIGGER IF EXISTS check_humidity_before_insert;

DELIMITER //

CREATE TRIGGER check_humidity_before_insert
BEFORE INSERT ON sensor_readings
FOR EACH ROW
BEGIN
    IF NEW.humidity_pct IS NOT NULL
       AND (NEW.humidity_pct < 0 OR NEW.humidity_pct > 100)
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid humidity reading';
    END IF;
END //

DELIMITER ;


-- =========================================
-- 7. FINAL PROJECT REPORTS
-- =========================================

-- Query 23: Overall Project Summary
SELECT
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM shipments) AS total_shipments,
    (SELECT COUNT(*) FROM containers) AS total_containers,
    (SELECT COUNT(*) FROM sensors) AS total_sensors,
    (SELECT COUNT(*) FROM sensor_readings) AS total_readings,
    (SELECT COUNT(*) FROM excursions) AS total_excursions,
    (SELECT COUNT(*) FROM corrective_actions) AS total_actions;


-- Query 24: Shipment-wise Temperature Report
SELECT
    s.shipment_id,
    p.product_name,
    COUNT(sr.reading_id) AS total_readings,
    ROUND(AVG(sr.temperature_c), 2) AS avg_temperature,
    MAX(sr.temperature_c) AS max_temperature,
    MIN(sr.temperature_c) AS min_temperature
FROM shipments s
JOIN products p
    ON s.product_id = p.product_id
LEFT JOIN sensor_readings sr
    ON s.shipment_id = sr.shipment_id
GROUP BY s.shipment_id, p.product_name;


-- Query 25: Excursion and Corrective Action Report
SELECT
    s.shipment_id,
    p.product_name,
    COUNT(DISTINCT e.excursion_id) AS total_excursions,
    COUNT(DISTINCT ca.action_id) AS total_actions
FROM shipments s
JOIN products p
    ON s.product_id = p.product_id
LEFT JOIN excursions e
    ON s.shipment_id = e.shipment_id
LEFT JOIN corrective_actions ca
    ON e.excursion_id = ca.excursion_id
GROUP BY s.shipment_id, p.product_name;

