-- =============================================================================
-- Flight Management Database - Required SQL Queries
-- =============================================================================
-- Target dialect: SQLite 3 (via Python's built-in sqlite3 module)
--
-- Notes:
--   - These queries are written against the final schema in work_01.sql and
--     the example records in work_02_seed_data.sql.
--   - Literal values are used here so the script is easy to demonstrate.
--     In the Python CLI, replace these literals with parameter placeholders (?).
--   - Modification queries are followed by SELECT statements so the result of
--     each change can be checked immediately.
-- =============================================================================

PRAGMA foreign_keys = ON;


-- =============================================================================
-- 1. Flight Retrieval
-- =============================================================================

-- 1.1 Retrieve flights by destination airport.
-- Example: all flights whose destination is London Heathrow (LHR).
SELECT
    f.flight_id,
    f.flight_number,
    dep.airport_code AS departure_code,
    dep.city         AS departure_city,
    dest.airport_code AS destination_code,
    dest.city         AS destination_city,
    f.departure_time,
    f.arrival_time,
    f.gate,
    f.status
FROM flights AS f
JOIN airports AS dep
    ON f.departure_airport = dep.airport_code
JOIN airports AS dest
    ON f.destination_airport = dest.airport_code
WHERE f.destination_airport = 'LHR'
ORDER BY f.arrival_time;


-- 1.2 Retrieve flights by status.
-- Example: all flights currently boarding.
SELECT
    f.flight_id,
    f.flight_number,
    f.departure_airport,
    f.destination_airport,
    f.departure_time,
    f.arrival_time,
    f.gate,
    f.status
FROM flights AS f
WHERE f.status = 'Boarding'
ORDER BY f.departure_time;


-- 1.3 Retrieve flights by departure date.
-- Example: all flights departing on 2026-05-24.
SELECT
    f.flight_id,
    f.flight_number,
    f.departure_airport,
    f.destination_airport,
    f.departure_time,
    f.arrival_time,
    f.status
FROM flights AS f
WHERE date(f.departure_time) = '2026-05-24'
ORDER BY f.departure_time;


-- =============================================================================
-- 2. Schedule Modification
-- =============================================================================

-- 2.1 Update a flight's departure time.
-- Example: delay flight BA560 by changing its departure time.
UPDATE flights
SET departure_time = '2026-05-24 16:45:00'
WHERE flight_id = 2;

SELECT
    flight_id,
    flight_number,
    departure_airport,
    destination_airport,
    departure_time,
    arrival_time,
    status
FROM flights
WHERE flight_id = 2;


-- 2.2 Update a flight's status.
-- Example: mark flight LH2477 as delayed.
UPDATE flights
SET status = 'Delayed'
WHERE flight_id = 6;

SELECT
    flight_id,
    flight_number,
    departure_airport,
    destination_airport,
    departure_time,
    arrival_time,
    status
FROM flights
WHERE flight_id = 6;


-- =============================================================================
-- 3. Pilot Assignment
-- =============================================================================

-- 3.1 Assign a pilot to a flight.
-- Example: add a relief pilot to flight AA81.
-- INSERT OR IGNORE keeps the demo script repeatable if it is run more than once.
INSERT OR IGNORE INTO pilotassignments (flight_id, pilot_id, pilot_role)
VALUES (4, 14, 'Relief Pilot');

SELECT
    f.flight_id,
    f.flight_number,
    p.pilot_id,
    p.first_name || ' ' || p.last_name AS pilot_name,
    pa.pilot_role
FROM pilotassignments AS pa
JOIN flights AS f
    ON pa.flight_id = f.flight_id
JOIN pilots AS p
    ON pa.pilot_id = p.pilot_id
WHERE pa.flight_id = 4
ORDER BY
    CASE pa.pilot_role
        WHEN 'Captain' THEN 1
        WHEN 'First Officer' THEN 2
        WHEN 'Relief Pilot' THEN 3
        ELSE 4
    END,
    p.last_name;


-- 3.2 Retrieve a pilot's schedule.
-- Example: show all flights assigned to pilot_id 1.
SELECT
    p.pilot_id,
    p.first_name || ' ' || p.last_name AS pilot_name,
    p."rank",
    f.flight_id,
    f.flight_number,
    f.departure_airport,
    f.destination_airport,
    f.departure_time,
    f.arrival_time,
    pa.pilot_role,
    f.status
FROM pilots AS p
JOIN pilotassignments AS pa
    ON p.pilot_id = pa.pilot_id
JOIN flights AS f
    ON pa.flight_id = f.flight_id
WHERE p.pilot_id = 1
ORDER BY f.departure_time;


-- =============================================================================
-- 4. Destination Management
-- =============================================================================

-- 4.1 View destination information.
-- Example: view London Heathrow destination/airport details.
SELECT
    airport_code,
    airport_name,
    city,
    country
FROM airports
WHERE airport_code = 'LHR';


-- 4.2 Update destination information.
-- Example: correct FCO from a common display name to its official airport name.
UPDATE airports
SET airport_name = 'Leonardo da Vinci-Fiumicino Airport'
WHERE airport_code = 'FCO';

SELECT
    airport_code,
    airport_name,
    city,
    country
FROM airports
WHERE airport_code = 'FCO';


-- =============================================================================
-- 5. Summary / Aggregation
-- =============================================================================

-- 5.1 Count the number of flights to each destination.
SELECT
    dest.airport_code AS destination_code,
    dest.airport_name AS destination_name,
    dest.city         AS destination_city,
    COUNT(f.flight_id) AS number_of_flights
FROM airports AS dest
LEFT JOIN flights AS f
    ON f.destination_airport = dest.airport_code
GROUP BY
    dest.airport_code,
    dest.airport_name,
    dest.city
ORDER BY
    number_of_flights DESC,
    dest.airport_code;


-- 5.2 Count the number of flights assigned to each pilot.
SELECT
    p.pilot_id,
    p.first_name || ' ' || p.last_name AS pilot_name,
    p."rank",
    COUNT(pa.flight_id) AS assigned_flights
FROM pilots AS p
LEFT JOIN pilotassignments AS pa
    ON p.pilot_id = pa.pilot_id
GROUP BY
    p.pilot_id,
    p.first_name,
    p.last_name,
    p."rank"
ORDER BY
    assigned_flights DESC,
    p.last_name,
    p.first_name;

-- =============================================================================
-- End of required queries
-- =============================================================================
