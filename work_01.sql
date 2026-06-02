-- =============================================================================
-- Flight Management Database — Schema Creation Script
-- =============================================================================
-- Target dialect: SQLite 3 (via Python's built-in sqlite3 module)
--
-- Notes:
--   - Tables are created in dependency order: independent tables first,
--     then tables with foreign keys.
--   - Tables are dropped in reverse order at the top, so the script is
--     idempotent (can be run repeatedly without error).
--   - SQLite uses INTEGER PRIMARY KEY AUTOINCREMENT for surrogate keys
--     (declared inline, not as a separate constraint).
--   - Foreign-key enforcement is OFF by default in SQLite. The PRAGMA below
--     turns it on for this connection. The application code must also enable
--     it on every new connection.
--   - Date/time columns use TEXT with ISO 8601 format 'YYYY-MM-DD HH:MM:SS'.
--     This is the SQLite-recommended convention and works seamlessly with
--     Python's datetime.isoformat() output.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Enable foreign-key enforcement for this session
-- -----------------------------------------------------------------------------
PRAGMA foreign_keys = ON;


-- -----------------------------------------------------------------------------
-- Drop existing tables in reverse dependency order
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS pilotassignments;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS pilots;
DROP TABLE IF EXISTS aircrafts;
DROP TABLE IF EXISTS airports;


-- =============================================================================
-- 1. airports — no foreign keys
-- =============================================================================
-- Uses the IATA three-letter code as a natural primary key, since these
-- codes are globally standardised and stable. Although the CLI presents this
-- entity to the user as "Destination Information", the table name reflects
-- the underlying domain model: an airport can serve as either departure
-- point or destination depending on the flight.
-- -----------------------------------------------------------------------------
CREATE TABLE airports (
    airport_code   TEXT     NOT NULL,
    airport_name   TEXT     NOT NULL,
    city           TEXT     NOT NULL,
    country        TEXT     NOT NULL,

    CONSTRAINT pk_airports PRIMARY KEY (airport_code)
);


-- =============================================================================
-- 2. aircrafts — no foreign keys
-- =============================================================================
-- Surrogate primary key (aircraft_id) is used because registration_number,
-- although unique, can change over an aircraft's lifetime (re-registration,
-- international transfer). The UNIQUE constraint preserves business
-- uniqueness without making it the PK.
-- -----------------------------------------------------------------------------
CREATE TABLE aircrafts (
    aircraft_id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    registration_number  TEXT     NOT NULL,
    model                TEXT     NOT NULL,
    status               TEXT     NOT NULL DEFAULT 'Active',

    CONSTRAINT uk_aircrafts_reg     UNIQUE (registration_number),
    CONSTRAINT chk_aircrafts_status CHECK  (status IN ('Active', 'Maintenance', 'Retired'))
);


-- =============================================================================
-- 3. pilots — no foreign keys
-- =============================================================================
-- Same surrogate-key reasoning as aircrafts. license_number is unique but
-- not used as PK because it is a regulatory identifier that may be reissued.
-- The column "rank" is double-quoted defensively, since SQL standard
-- identifier quoting in SQLite uses double quotes (not backticks).
-- -----------------------------------------------------------------------------
CREATE TABLE pilots (
    pilot_id        INTEGER  PRIMARY KEY AUTOINCREMENT,
    license_number  TEXT     NOT NULL,
    first_name      TEXT     NOT NULL,
    last_name       TEXT     NOT NULL,
    "rank"          TEXT     NOT NULL,
    phone           TEXT,
    email           TEXT,
    status          TEXT     NOT NULL DEFAULT 'Available',

    CONSTRAINT uk_pilots_license  UNIQUE (license_number),
    CONSTRAINT chk_pilots_rank    CHECK  ("rank" IN ('Captain', 'First Officer', 'Trainee')),
    CONSTRAINT chk_pilots_status  CHECK  (status IN ('Available', 'On Duty', 'Inactive'))
);


-- =============================================================================
-- 4. flights — depends on airports and aircrafts
-- =============================================================================
-- The composite UNIQUE constraint on (flight_number, departure_time) enforces
-- the business rule that the same flight number cannot depart at the same
-- moment twice. This is the rule that disqualified flight_number alone as
-- a candidate key during the design phase.
--
-- The CHECK constraint ensures a flight cannot depart from and arrive at
-- the same airport (a guard against data-entry mistakes).
--
-- departure_time and arrival_time use TEXT in ISO 8601 format. Stored as
-- text, lexicographic ordering equals chronological ordering, so the
-- comparison "arrival_time > departure_time" works correctly.
-- -----------------------------------------------------------------------------
CREATE TABLE flights (
    flight_id            INTEGER  PRIMARY KEY AUTOINCREMENT,
    flight_number        TEXT     NOT NULL,
    departure_airport    TEXT     NOT NULL,
    destination_airport  TEXT     NOT NULL,
    aircraft_id          INTEGER  NOT NULL,
    departure_time       TEXT     NOT NULL,  -- ISO 8601: 'YYYY-MM-DD HH:MM:SS'
    arrival_time         TEXT     NOT NULL,  -- ISO 8601: 'YYYY-MM-DD HH:MM:SS'
    gate                 TEXT,
    status               TEXT     NOT NULL DEFAULT 'Scheduled',

    CONSTRAINT uk_flights_number_time UNIQUE (flight_number, departure_time),

    CONSTRAINT fk_flights_departure
        FOREIGN KEY (departure_airport)   REFERENCES airports(airport_code),
    CONSTRAINT fk_flights_destination
        FOREIGN KEY (destination_airport) REFERENCES airports(airport_code),
    CONSTRAINT fk_flights_aircraft
        FOREIGN KEY (aircraft_id)         REFERENCES aircrafts(aircraft_id),

    CONSTRAINT chk_flights_status
        CHECK (status IN ('Scheduled', 'Boarding', 'Delayed', 'Departed', 'Cancelled', 'Landed')),
    CONSTRAINT chk_flights_airports_distinct
        CHECK (departure_airport <> destination_airport),
    CONSTRAINT chk_flights_times
        CHECK (arrival_time > departure_time)
);


-- =============================================================================
-- 5. pilotassignments — depends on flights and pilots
-- =============================================================================
-- Resolves the M:N relationship "performs" from the ER diagram into a
-- relational table. The surrogate PK (assignment_id) is paired with a
-- composite UNIQUE on (flight_id, pilot_id) so the database itself enforces
-- the business rule that a pilot cannot be assigned to the same flight twice.
--
-- ON DELETE CASCADE on flight_id: if a flight record is deleted, its
-- assignments are deleted automatically. There is intentionally no CASCADE
-- on pilot_id: a pilot's departure from the company should not erase the
-- historical record of flights they operated.
-- -----------------------------------------------------------------------------
CREATE TABLE pilotassignments (
    assignment_id   INTEGER  PRIMARY KEY AUTOINCREMENT,
    flight_id       INTEGER  NOT NULL,
    pilot_id        INTEGER  NOT NULL,
    pilot_role      TEXT     NOT NULL,

    CONSTRAINT uk_pilotassignments_pair UNIQUE (flight_id, pilot_id),

    CONSTRAINT fk_pilotassignments_flight
        FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_pilotassignments_pilot
        FOREIGN KEY (pilot_id)  REFERENCES pilots(pilot_id),

    CONSTRAINT chk_pilotassignments_role
        CHECK (pilot_role IN ('Captain', 'First Officer', 'Relief Pilot'))
);


-- =============================================================================
-- Indexes for common query patterns
-- =============================================================================
-- The PK and UNIQUE constraints above already create indexes on:
--   airports.airport_code, aircrafts.aircraft_id, aircrafts.registration_number,
--   pilots.pilot_id, pilots.license_number, flights.flight_id,
--   flights (flight_number, departure_time),
--   pilotassignments.assignment_id, pilotassignments (flight_id, pilot_id).
--
-- The indexes below cover additional access paths used by the application's
-- search and filter screens (e.g. "View Flights by Criteria", "View Pilot Schedule").
-- -----------------------------------------------------------------------------
CREATE INDEX idx_flights_departure_time ON flights (departure_time);
CREATE INDEX idx_flights_status         ON flights (status);
CREATE INDEX idx_flights_route          ON flights (departure_airport, destination_airport);
CREATE INDEX idx_pilotassignments_pilot ON pilotassignments (pilot_id);
-- =============================================================================
-- End of schema
-- =============================================================================
