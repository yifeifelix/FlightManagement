-- Flight Management Database — Schema Creation Script
-- Enable foreign-key enforcement for this session

PRAGMA foreign_keys = ON;



-- Drop existing tables in reverse dependency order

DROP TABLE IF EXISTS pilotassignments;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS pilots;
DROP TABLE IF EXISTS aircrafts;
DROP TABLE IF EXISTS airports;



-- 1. airports — no foreign keys

-- -----------------------------------------------------------------------------
CREATE TABLE airports (
    airport_code   TEXT     NOT NULL,
    airport_name   TEXT     NOT NULL,
    city           TEXT     NOT NULL,
    country        TEXT     NOT NULL,

    CONSTRAINT pk_airports PRIMARY KEY (airport_code)
);



-- 2. aircrafts — no foreign keys

CREATE TABLE aircrafts (
    aircraft_id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    registration_number  TEXT     NOT NULL,
    model                TEXT     NOT NULL,
    status               TEXT     NOT NULL DEFAULT 'Active',

    CONSTRAINT uk_aircrafts_reg     UNIQUE (registration_number),
    CONSTRAINT chk_aircrafts_status CHECK  (status IN ('Active', 'Maintenance', 'Retired'))
);



-- 3. pilots — no foreign keys

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



-- 4. flights — depends on airports and aircrafts


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



-- 5. pilotassignments — depends on flights and pilots


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



-- Indexes for common query patterns

CREATE INDEX idx_flights_departure_time ON flights (departure_time);
CREATE INDEX idx_flights_status         ON flights (status);
CREATE INDEX idx_flights_route          ON flights (departure_airport, destination_airport);
CREATE INDEX idx_pilotassignments_pilot ON pilotassignments (pilot_id);

-- End of schema

