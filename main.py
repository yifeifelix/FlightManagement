"""
Flight Management CLI Application
=================================

A command-line interface to the Flight Management Database (SQLite).
The first six menu options match the assignment brief exactly:

    1. Add a New Flight
    2. View Flights by Criteria
    3. Update Flight Information
    4. Assign Pilot to Flight
    5. View Pilot Schedule
    6. View / Update Destination Information

Additional support options:

    7. View Summary Reports
    8. Initialise / Reset Database
    9. Exit

Design notes:
    - All database access goes through the FlightManager class.
    - SQL is written inline in each method so each operation is readable.
    - sqlite3.Row is used so query results can be accessed by column name.
    - PRAGMA foreign_keys = ON is set on every connection.
    - User input helper functions re-prompt on invalid values.
"""

import sqlite3
from datetime import datetime
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "flight_management.db"
SCHEMA_PATH = BASE_DIR / "work_01.sql"
SEED_PATH = BASE_DIR / "work_02_seed_data.sql"


# =============================================================================
# Input helpers
# =============================================================================

def prompt_int(message, allow_blank=False):
    """Read an integer from the user, re-prompting on invalid input."""
    while True:
        raw = input(message).strip()
        if allow_blank and raw == "":
            return None
        try:
            return int(raw)
        except ValueError:
            print("  Please enter a whole number.")


def prompt_nonempty(message):
    """Read a non-empty string from the user."""
    while True:
        raw = input(message).strip()
        if raw:
            return raw
        print("  Value cannot be empty.")


def prompt_optional(message):
    """Read a string from the user. Empty input returns None."""
    raw = input(message).strip()
    return raw if raw else None


def prompt_datetime(message):
    """Read a datetime string in 'YYYY-MM-DD HH:MM:SS' format."""
    while True:
        raw = input(message).strip()
        try:
            datetime.strptime(raw, "%Y-%m-%d %H:%M:%S")
            return raw
        except ValueError:
            print("  Please use format YYYY-MM-DD HH:MM:SS.")


def prompt_date(message, allow_blank=True):
    """Read a date string in 'YYYY-MM-DD' format."""
    while True:
        raw = input(message).strip()
        if allow_blank and raw == "":
            return None
        try:
            datetime.strptime(raw, "%Y-%m-%d")
            return raw
        except ValueError:
            print("  Please use format YYYY-MM-DD.")


def prompt_choice(message, choices):
    """Read a value that must be one of the allowed choices."""
    lookup = {choice.lower(): choice for choice in choices}
    options_text = " / ".join(choices)
    while True:
        raw = input(f"{message} [{options_text}]: ").strip().lower()
        if raw in lookup:
            return lookup[raw]
        print(f"  Please choose one of: {options_text}")


def prompt_optional_choice(message, choices):
    """Read an optional enum value. Empty input returns None."""
    lookup = {choice.lower(): choice for choice in choices}
    options_text = " / ".join(choices)
    while True:
        raw = input(f"{message} [{options_text}] (blank for no filter): ").strip()
        if raw == "":
            return None
        canonical = lookup.get(raw.lower())
        if canonical:
            return canonical
        print(f"  Please choose one of: {options_text}, or leave blank.")


# =============================================================================
# Display helpers
# =============================================================================

def print_table(rows, headers=None):
    """Print query result rows as an aligned text table."""
    if not rows:
        print("  (no records found)")
        return

    if headers is None:
        headers = rows[0].keys()

    string_rows = [
        [str(row[header]) if row[header] is not None else "" for header in headers]
        for row in rows
    ]

    widths = [len(str(header)) for header in headers]
    for row in string_rows:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], len(cell))

    header_row = "  ".join(str(header).ljust(widths[index]) for index, header in enumerate(headers))
    separator = "  ".join("-" * width for width in widths)

    print(header_row)
    print(separator)
    for row in string_rows:
        print("  ".join(cell.ljust(widths[index]) for index, cell in enumerate(row)))
    print(f"  ({len(rows)} row{'s' if len(rows) != 1 else ''})")


# =============================================================================
# Main database class
# =============================================================================

class FlightManager:
    """Encapsulates all database operations for the Flight Management system."""

    FLIGHT_STATUS_VALUES = [
        "Scheduled",
        "Boarding",
        "Delayed",
        "Departed",
        "Cancelled",
        "Landed",
    ]
    PILOT_ROLE_VALUES = ["Captain", "First Officer", "Relief Pilot"]

    def _connect(self):
        """Open a SQLite connection using the project conventions."""
        conn = sqlite3.connect(DB_PATH)
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.row_factory = sqlite3.Row
        return conn

    def initialise_database(self):
        """Create/reset the database and load the sample records."""
        print("\n--- Initialise / Reset Database ---")
        if not SCHEMA_PATH.exists():
            print(f"  Missing schema file: {SCHEMA_PATH}")
            return
        if not SEED_PATH.exists():
            print(f"  Missing seed data file: {SEED_PATH}")
            return

        confirm = prompt_choice(
            "This will drop and recreate all tables. Continue?",
            ["yes", "no"],
        )
        if confirm == "no":
            print("  Reset cancelled.")
            return

        schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")
        seed_sql = SEED_PATH.read_text(encoding="utf-8")

        with self._connect() as conn:
            conn.executescript(schema_sql)
            conn.executescript(seed_sql)
            conn.commit()

            counts = conn.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM airports) AS airports,
                    (SELECT COUNT(*) FROM aircrafts) AS aircrafts,
                    (SELECT COUNT(*) FROM pilots) AS pilots,
                    (SELECT COUNT(*) FROM flights) AS flights,
                    (SELECT COUNT(*) FROM pilotassignments) AS pilotassignments
                """
            ).fetchone()

        print("  Database initialised successfully.")
        print_table([counts])

    # -------------------------------------------------------------------------
    # Menu option 1: Add a New Flight
    # -------------------------------------------------------------------------

    def add_new_flight(self):
        """Insert a new row into flights."""
        print("\n--- Add a New Flight ---")

        with self._connect() as conn:
            print("\nAvailable airports:")
            print_table(conn.execute(
                "SELECT airport_code, airport_name, city FROM airports ORDER BY airport_code"
            ).fetchall())

            print("\nAvailable active aircraft:")
            print_table(conn.execute(
                "SELECT aircraft_id, registration_number, model "
                "FROM aircrafts WHERE status = 'Active' ORDER BY aircraft_id"
            ).fetchall())

            print()
            flight_number = prompt_nonempty("Flight number (e.g. BA117): ")
            departure_airport = prompt_nonempty("Departure airport code (e.g. LHR): ").upper()
            destination_airport = prompt_nonempty("Destination airport code (e.g. JFK): ").upper()
            aircraft_id = prompt_int("Aircraft ID: ")
            departure_time = prompt_datetime("Departure time (YYYY-MM-DD HH:MM:SS): ")
            arrival_time = prompt_datetime("Arrival time (YYYY-MM-DD HH:MM:SS): ")
            gate = prompt_optional("Gate (leave blank if unassigned): ")
            status = prompt_choice("Status", self.FLIGHT_STATUS_VALUES)

            try:
                cursor = conn.execute(
                    """
                    INSERT INTO flights (
                        flight_number,
                        departure_airport,
                        destination_airport,
                        aircraft_id,
                        departure_time,
                        arrival_time,
                        gate,
                        status
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        flight_number,
                        departure_airport,
                        destination_airport,
                        aircraft_id,
                        departure_time,
                        arrival_time,
                        gate,
                        status,
                    ),
                )
                conn.commit()
                print(f"\n  Flight added successfully (flight_id = {cursor.lastrowid}).")
            except sqlite3.IntegrityError as error:
                self._print_integrity_error(error)

    # -------------------------------------------------------------------------
    # Menu option 2: View Flights by Criteria
    # -------------------------------------------------------------------------

    def view_flights_by_criteria(self):
        """Filter flights by destination, status, and/or departure date."""
        print("\n--- View Flights by Criteria ---")
        print("Leave a field blank to skip that filter.\n")

        destination = prompt_optional("Destination airport code: ")
        if destination:
            destination = destination.upper()
        status = prompt_optional_choice("Status", self.FLIGHT_STATUS_VALUES)
        date_value = prompt_date("Departure date (YYYY-MM-DD): ", allow_blank=True)

        sql = """
            SELECT
                f.flight_id,
                f.flight_number,
                f.departure_airport AS departure,
                f.destination_airport AS destination,
                f.departure_time,
                f.arrival_time,
                f.gate,
                f.status
            FROM flights AS f
            WHERE 1 = 1
        """
        params = []
        if destination:
            sql += " AND f.destination_airport = ?"
            params.append(destination)
        if status:
            sql += " AND f.status = ?"
            params.append(status)
        if date_value:
            sql += " AND date(f.departure_time) = ?"
            params.append(date_value)
        sql += " ORDER BY f.departure_time"

        with self._connect() as conn:
            rows = conn.execute(sql, params).fetchall()
            print()
            print_table(rows)

    # -------------------------------------------------------------------------
    # Menu option 3: Update Flight Information
    # -------------------------------------------------------------------------

    def update_flight_information(self):
        """Update the departure time or status of an existing flight."""
        print("\n--- Update Flight Information ---")
        flight_id = prompt_int("Flight ID to update: ")

        with self._connect() as conn:
            current = conn.execute(
                """
                SELECT flight_id, flight_number, departure_time, arrival_time, status
                FROM flights
                WHERE flight_id = ?
                """,
                (flight_id,),
            ).fetchone()

            if current is None:
                print(f"  No flight with ID {flight_id}.")
                return

            print("\nCurrent record:")
            print_table([current])

            print("\nWhich field would you like to update?")
            print("  1. Departure time")
            print("  2. Status")
            choice = prompt_choice("Choice", ["1", "2"])

            if choice == "1":
                new_value = prompt_datetime("New departure time (YYYY-MM-DD HH:MM:SS): ")
                column = "departure_time"
            else:
                new_value = prompt_choice("New status", self.FLIGHT_STATUS_VALUES)
                column = "status"

            try:
                cursor = conn.execute(
                    f"UPDATE flights SET {column} = ? WHERE flight_id = ?",
                    (new_value, flight_id),
                )
                conn.commit()

                print(f"  Updated {cursor.rowcount} row.")
                updated = conn.execute(
                    """
                    SELECT flight_id, flight_number, departure_time, arrival_time, status
                    FROM flights
                    WHERE flight_id = ?
                    """,
                    (flight_id,),
                ).fetchone()
                print_table([updated])
            except sqlite3.IntegrityError as error:
                self._print_integrity_error(error)

    # -------------------------------------------------------------------------
    # Menu option 4: Assign Pilot to Flight
    # -------------------------------------------------------------------------

    def assign_pilot_to_flight(self):
        """Insert a row into pilotassignments."""
        print("\n--- Assign Pilot to Flight ---")

        with self._connect() as conn:
            print("\nUpcoming flights:")
            print_table(conn.execute(
                """
                SELECT
                    flight_id,
                    flight_number,
                    departure_airport,
                    destination_airport,
                    departure_time,
                    status
                FROM flights
                WHERE status IN ('Scheduled', 'Boarding', 'Delayed')
                ORDER BY departure_time
                """
            ).fetchall())

            print("\nAvailable pilots:")
            print_table(conn.execute(
                """
                SELECT pilot_id, first_name, last_name, "rank", status
                FROM pilots
                WHERE status != 'Inactive'
                ORDER BY pilot_id
                """
            ).fetchall())

            print()
            flight_id = prompt_int("Flight ID: ")
            pilot_id = prompt_int("Pilot ID: ")
            pilot_role = prompt_choice("Role", self.PILOT_ROLE_VALUES)

            try:
                cursor = conn.execute(
                    """
                    INSERT INTO pilotassignments (flight_id, pilot_id, pilot_role)
                    VALUES (?, ?, ?)
                    """,
                    (flight_id, pilot_id, pilot_role),
                )
                conn.commit()
                print(f"\n  Assignment added (assignment_id = {cursor.lastrowid}).")
            except sqlite3.IntegrityError as error:
                self._print_integrity_error(error)

    # -------------------------------------------------------------------------
    # Menu option 5: View Pilot Schedule
    # -------------------------------------------------------------------------

    def view_pilot_schedule(self):
        """Show all flights assigned to a given pilot."""
        print("\n--- View Pilot Schedule ---")
        pilot_id = prompt_int("Pilot ID: ")

        with self._connect() as conn:
            pilot = conn.execute(
                """
                SELECT pilot_id, first_name, last_name, "rank", status
                FROM pilots
                WHERE pilot_id = ?
                """,
                (pilot_id,),
            ).fetchone()

            if pilot is None:
                print(f"  No pilot with ID {pilot_id}.")
                return

            print("\nPilot:")
            print_table([pilot])

            schedule = conn.execute(
                """
                SELECT
                    f.flight_id,
                    f.flight_number,
                    f.departure_airport AS departure,
                    f.destination_airport AS destination,
                    f.departure_time,
                    f.arrival_time,
                    pa.pilot_role,
                    f.status
                FROM pilotassignments AS pa
                JOIN flights AS f
                    ON pa.flight_id = f.flight_id
                WHERE pa.pilot_id = ?
                ORDER BY f.departure_time
                """,
                (pilot_id,),
            ).fetchall()

            print("\nAssigned flights:")
            print_table(schedule)

    # -------------------------------------------------------------------------
    # Menu option 6: View / Update Destination Information
    # -------------------------------------------------------------------------

    def view_update_destination(self):
        """View or update destination information in the airports table."""
        print("\n--- View / Update Destination Information ---")
        print("  1. View all destinations")
        print("  2. View one destination")
        print("  3. Update a destination")
        choice = prompt_choice("Choice", ["1", "2", "3"])

        with self._connect() as conn:
            if choice == "1":
                rows = conn.execute(
                    """
                    SELECT airport_code, airport_name, city, country
                    FROM airports
                    ORDER BY airport_code
                    """
                ).fetchall()
                print()
                print_table(rows)
                return

            if choice == "2":
                code = prompt_nonempty("Airport code (e.g. LHR): ").upper()
                row = conn.execute(
                    """
                    SELECT airport_code, airport_name, city, country
                    FROM airports
                    WHERE airport_code = ?
                    """,
                    (code,),
                ).fetchone()
                print()
                if row is None:
                    print(f"  No airport with code {code}.")
                else:
                    print_table([row])
                return

            code = prompt_nonempty("Airport code to update: ").upper()
            current = conn.execute(
                """
                SELECT airport_code, airport_name, city, country
                FROM airports
                WHERE airport_code = ?
                """,
                (code,),
            ).fetchone()

            if current is None:
                print(f"  No airport with code {code}.")
                return

            print("\nCurrent record:")
            print_table([current])

            print("\nWhich field would you like to update?")
            print("  1. Airport name")
            print("  2. City")
            print("  3. Country")
            field_choice = prompt_choice("Choice", ["1", "2", "3"])
            column = {"1": "airport_name", "2": "city", "3": "country"}[field_choice]
            new_value = prompt_nonempty(f"New {column}: ")

            cursor = conn.execute(
                f"UPDATE airports SET {column} = ? WHERE airport_code = ?",
                (new_value, code),
            )
            conn.commit()
            print(f"  Updated {cursor.rowcount} row.")

            updated = conn.execute(
                """
                SELECT airport_code, airport_name, city, country
                FROM airports
                WHERE airport_code = ?
                """,
                (code,),
            ).fetchone()
            print_table([updated])

    # -------------------------------------------------------------------------
    # Menu option 7: View Summary Reports
    # -------------------------------------------------------------------------

    def view_summary_reports(self):
        """Show aggregate reports required by the assignment."""
        print("\n--- View Summary Reports ---")
        print("  1. Number of flights to each destination")
        print("  2. Number of flights assigned to each pilot")
        choice = prompt_choice("Choice", ["1", "2"])

        with self._connect() as conn:
            if choice == "1":
                rows = conn.execute(
                    """
                    SELECT
                        dest.airport_code AS destination_code,
                        dest.airport_name AS destination_name,
                        dest.city AS destination_city,
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
                        dest.airport_code
                    """
                ).fetchall()
            else:
                rows = conn.execute(
                    """
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
                        p.first_name
                    """
                ).fetchall()

            print()
            print_table(rows)

    # -------------------------------------------------------------------------
    # Error display
    # -------------------------------------------------------------------------

    def _print_integrity_error(self, error):
        """Translate common SQLite constraint errors into clearer messages."""
        message = str(error)
        if "UNIQUE constraint failed: flights.flight_number, flights.departure_time" in message:
            print("  Error: a flight with that number is already scheduled for that time.")
        elif "UNIQUE constraint failed: pilotassignments.flight_id, pilotassignments.pilot_id" in message:
            print("  Error: that pilot is already assigned to that flight.")
        elif "CHECK constraint failed: chk_flights_airports_distinct" in message:
            print("  Error: departure and destination airports must be different.")
        elif "CHECK constraint failed: chk_flights_times" in message:
            print("  Error: arrival time must be after departure time.")
        elif "CHECK constraint failed: chk_flights_status" in message:
            print("  Error: status value is not allowed.")
        elif "CHECK constraint failed: chk_pilotassignments_role" in message:
            print("  Error: pilot role value is not allowed.")
        elif "FOREIGN KEY constraint failed" in message:
            print("  Error: a referenced airport, aircraft, flight, or pilot does not exist.")
        else:
            print(f"  Database rejected the operation: {error}")


# =============================================================================
# Menu loop
# =============================================================================

MENU_TEXT = """
============================================
   Flight Management System
============================================
  1. Add a New Flight
  2. View Flights by Criteria
  3. Update Flight Information
  4. Assign Pilot to Flight
  5. View Pilot Schedule
  6. View / Update Destination Information
  7. View Summary Reports
  8. Initialise / Reset Database
  9. Exit
============================================
First time running? Choose option 8 to create and populate the database.
"""


def main():
    manager = FlightManager()
    actions = {
        1: manager.add_new_flight,
        2: manager.view_flights_by_criteria,
        3: manager.update_flight_information,
        4: manager.assign_pilot_to_flight,
        5: manager.view_pilot_schedule,
        6: manager.view_update_destination,
        7: manager.view_summary_reports,
        8: manager.initialise_database,
    }

    while True:
        print(MENU_TEXT)
        choice = prompt_int("Enter your choice (1-9): ")

        if choice == 9:
            print("Goodbye.")
            break

        action = actions.get(choice)
        if action is None:
            print("  Please choose a number between 1 and 9.")
            continue

        try:
            action()
        except sqlite3.OperationalError as error:
            print(f"\n  Database error: {error}")
            print("  If this is the first run, choose option 8 to initialise the database.")
        except KeyboardInterrupt:
            print("\n  Cancelled. Returning to menu.")


if __name__ == "__main__":
    main()
