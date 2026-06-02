-- =============================================================================
-- Flight Management Database - Example Records
-- =============================================================================
-- Target dialect: SQLite 3 (via Python's built-in sqlite3 module)
--
-- Data sources used for realistic flight examples:
--   - Heathrow live departures page: confirms Heathrow publishes live
--     minute-by-minute departure status information.
--   - Plane Finder Heathrow live departures/arrivals, checked on 2026-05-24:
--     used for sample flight numbers, airport codes, destinations/origins,
--     scheduled times, gates where shown, and operational statuses.
--
-- Notes:
--   - Aircraft and pilot records are demonstration data. Public flight boards
--     normally do not provide the exact pilot roster or aircraft registration
--     for each listed flight.
--   - Each flight has at least one Captain and one First Officer assignment to
--     make the demonstration data consistent with normal commercial operation.
--   - Times are stored as ISO 8601 TEXT values to match work_01.sql.
--   - For inbound/outbound flights, departure_time and arrival_time are treated
--     as normalised operational times so the schema CHECK
--     (arrival_time > departure_time) remains valid.
-- =============================================================================

PRAGMA foreign_keys = ON;


-- -----------------------------------------------------------------------------
-- Clear existing example records in reverse dependency order
-- -----------------------------------------------------------------------------
DELETE FROM pilotassignments;
DELETE FROM flights;
DELETE FROM pilots;
DELETE FROM aircrafts;
DELETE FROM airports;

DELETE FROM sqlite_sequence
WHERE name IN ('pilotassignments', 'flights', 'pilots', 'aircrafts');


-- =============================================================================
-- 1. airports
-- =============================================================================
INSERT INTO airports (airport_code, airport_name, city, country) VALUES
('LHR', 'London Heathrow Airport', 'London', 'United Kingdom'),
('ABZ', 'Aberdeen International Airport', 'Aberdeen', 'United Kingdom'),
('FCO', 'Rome Fiumicino Airport', 'Rome', 'Italy'),
('JFK', 'John F. Kennedy International Airport', 'New York', 'United States'),
('DFW', 'Dallas Fort Worth International Airport', 'Dallas-Fort Worth', 'United States'),
('MAD', 'Adolfo Suarez Madrid-Barajas Airport', 'Madrid', 'Spain'),
('MUC', 'Munich Airport', 'Munich', 'Germany'),
('BLR', 'Kempegowda International Airport', 'Bangalore', 'India'),
('DUB', 'Dublin Airport', 'Dublin', 'Ireland'),
('KEF', 'Keflavik International Airport', 'Keflavik', 'Iceland'),
('PEK', 'Beijing Capital International Airport', 'Beijing', 'China'),
('DOH', 'Hamad International Airport', 'Doha', 'Qatar'),
('SEA', 'Seattle-Tacoma International Airport', 'Seattle', 'United States'),
('EWR', 'Newark Liberty International Airport', 'Newark', 'United States'),
('ZRH', 'Zurich Airport', 'Zurich', 'Switzerland');


-- =============================================================================
-- 2. aircrafts
-- =============================================================================
INSERT INTO aircrafts (aircraft_id, registration_number, model, status) VALUES
(1,  'G-TTNA', 'Airbus A320neo', 'Active'),
(2,  'G-TTNB', 'Airbus A320neo', 'Active'),
(3,  'G-ZBLA', 'Boeing 787-10', 'Active'),
(4,  'G-VNEW', 'Boeing 787-9', 'Active'),
(5,  'N726AN', 'Boeing 777-300ER', 'Active'),
(6,  'D-AIUB', 'Airbus A320neo', 'Active'),
(7,  'VT-ALX', 'Boeing 787-8', 'Active'),
(8,  'EI-NSB', 'Airbus A320neo', 'Active'),
(9,  'TF-ICE', 'Boeing 757-200', 'Active'),
(10, 'B-2486', 'Boeing 777-300ER', 'Active'),
(11, 'A7-BHA', 'Boeing 787-9', 'Active'),
(12, 'G-YMMR', 'Boeing 777-200ER', 'Retired');


-- =============================================================================
-- 3. pilots
-- =============================================================================
INSERT INTO pilots (pilot_id, license_number, first_name, last_name, "rank", phone, email, status) VALUES
(1,  'UK-ATPL-1001', 'James',   'Walker',   'Captain',       '+44 7700 900101', 'james.walker@exampleair.test', 'On Duty'),
(2,  'UK-ATPL-1002', 'Emily',   'Carter',   'First Officer', '+44 7700 900102', 'emily.carter@exampleair.test', 'On Duty'),
(3,  'UK-ATPL-1003', 'Oliver',  'Hughes',   'Captain',       '+44 7700 900103', 'oliver.hughes@exampleair.test', 'On Duty'),
(4,  'UK-ATPL-1004', 'Sophie',  'Bennett',  'First Officer', '+44 7700 900104', 'sophie.bennett@exampleair.test', 'On Duty'),
(5,  'UK-ATPL-1005', 'Daniel',  'Morgan',   'Captain',       '+44 7700 900105', 'daniel.morgan@exampleair.test', 'On Duty'),
(6,  'UK-ATPL-1006', 'Amelia',  'Reed',     'Captain',       '+44 7700 900106', 'amelia.reed@exampleair.test', 'Available'),
(7,  'UK-ATPL-1007', 'Thomas',  'Evans',    'First Officer', '+44 7700 900107', 'thomas.evans@exampleair.test', 'Available'),
(8,  'UK-ATPL-1008', 'Grace',   'Turner',   'Captain',       '+44 7700 900108', 'grace.turner@exampleair.test', 'On Duty'),
(9,  'UK-ATPL-1009', 'Henry',   'Patel',    'First Officer', '+44 7700 900109', 'henry.patel@exampleair.test', 'On Duty'),
(10, 'UK-ATPL-1010', 'Mia',     'Roberts',  'Captain',       '+44 7700 900110', 'mia.roberts@exampleair.test', 'On Duty'),
(11, 'UK-ATPL-1011', 'Ethan',   'Clarke',   'First Officer', '+44 7700 900111', 'ethan.clarke@exampleair.test', 'Available'),
(12, 'UK-ATPL-1012', 'Charlotte','Lewis',   'Captain',       '+44 7700 900112', 'charlotte.lewis@exampleair.test', 'On Duty'),
(13, 'UK-ATPL-1013', 'Noah',    'Green',    'First Officer', '+44 7700 900113', 'noah.green@exampleair.test', 'On Duty'),
(14, 'UK-ATPL-1014', 'Ava',     'Hill',     'Trainee',       '+44 7700 900114', 'ava.hill@exampleair.test', 'Available'),
(15, 'UK-ATPL-1015', 'Lucas',   'Scott',    'Captain',       '+44 7700 900115', 'lucas.scott@exampleair.test', 'Inactive');


-- =============================================================================
-- 4. flights
-- =============================================================================
-- Outbound examples from Heathrow live departures:
--   BA1314 LHR -> ABZ, BA560 LHR -> FCO, VS47 LHR -> JFK,
--   AA81 LHR -> DFW, BA464 LHR -> MAD, LH2477 LHR -> MUC.
-- Inbound examples from Heathrow live arrivals:
--   AI133 BLR -> LHR, EI182 DUB -> LHR, FI454 KEF -> LHR,
--   BA1315 ABZ -> LHR, CA855 PEK -> LHR, QR15 DOH -> LHR.
-- -----------------------------------------------------------------------------
INSERT INTO flights (
    flight_id, flight_number, departure_airport, destination_airport,
    aircraft_id, departure_time, arrival_time, gate, status
) VALUES
(1,  'BA1314', 'LHR', 'ABZ', 1,  '2026-05-24 16:20:00', '2026-05-24 17:55:00', 'A21', 'Departed'),
(2,  'BA560',  'LHR', 'FCO', 2,  '2026-05-24 16:20:00', '2026-05-24 18:55:00', 'A18', 'Departed'),
(3,  'VS47',   'LHR', 'JFK', 4,  '2026-05-24 16:20:00', '2026-05-24 23:55:00', '19',  'Departed'),
(4,  'AA81',   'LHR', 'DFW', 5,  '2026-05-24 16:25:00', '2026-05-25 02:35:00', '31',  'Boarding'),
(5,  'BA464',  'LHR', 'MAD', 3,  '2026-05-24 16:25:00', '2026-05-24 18:55:00', 'A8',  'Boarding'),
(6,  'LH2477', 'LHR', 'MUC', 6,  '2026-05-24 16:25:00', '2026-05-24 18:15:00', 'A25', 'Boarding'),
(7,  'AI133',  'BLR', 'LHR', 7,  '2026-05-24 10:00:00', '2026-05-24 20:20:00', NULL,  'Scheduled'),
(8,  'EI182',  'DUB', 'LHR', 8,  '2026-05-24 19:00:00', '2026-05-24 20:20:00', NULL,  'Landed'),
(9,  'FI454',  'KEF', 'LHR', 9,  '2026-05-24 17:10:00', '2026-05-24 20:20:00', NULL,  'Landed'),
(10, 'BA1315', 'ABZ', 'LHR', 1,  '2026-05-24 18:55:00', '2026-05-24 20:25:00', NULL,  'Scheduled'),
(11, 'CA855',  'PEK', 'LHR', 10, '2026-05-24 10:40:00', '2026-05-24 20:25:00', NULL,  'Landed'),
(12, 'QR15',   'DOH', 'LHR', 11, '2026-05-24 13:15:00', '2026-05-24 20:30:00', NULL,  'Landed');


-- =============================================================================
-- 5. pilotassignments
-- =============================================================================
INSERT INTO pilotassignments (assignment_id, flight_id, pilot_id, pilot_role) VALUES
(1,  1,  1,  'Captain'),
(2,  1,  2,  'First Officer'),
(3,  2,  3,  'Captain'),
(4,  2,  4,  'First Officer'),
(5,  3,  5,  'Captain'),
(6,  3,  7,  'First Officer'),
(7,  4,  6,  'Captain'),
(8,  4,  9,  'First Officer'),
(9,  5,  8,  'Captain'),
(10, 5,  11, 'First Officer'),
(11, 6,  10, 'Captain'),
(12, 6,  13, 'First Officer'),
(13, 7,  12, 'Captain'),
(14, 7,  2,  'First Officer'),
(15, 8,  3,  'Captain'),
(16, 8,  13, 'First Officer'),
(17, 9,  6,  'Captain'),
(18, 9,  9,  'First Officer'),
(19, 10, 1,  'Captain'),
(20, 10, 4,  'First Officer'),
(21, 11, 3,  'Captain'),
(22, 11, 7,  'First Officer'),
(23, 12, 5,  'Captain'),
(24, 12, 11, 'First Officer');

-- =============================================================================
-- End of example records
-- =============================================================================
