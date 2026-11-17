"""Append an NHS annual usage file to the existing SNOMEDCT usage table.

Requires pyodbc and Microsoft ODBC Driver 17 for SQL Server. Uses Windows
authentication. Existing periods are verified, never replaced. NHS '*' values
(suppressed counts of 1-4) map to 0, matching the existing database convention;
the unmodified source file preserves the suppression markers.
"""

import argparse
import csv
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

import pyodbc


def read_source(path):
    expected_header = [
        "SNOMED_Concept_ID", "Description", "Usage",
        "Active_at_Start", "Active_at_End",
    ]
    records = {}
    suppressed = 0
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle, delimiter="\t", quoting=csv.QUOTE_NONE)
        if next(reader, None) != expected_header:
            raise ValueError("Unexpected source header")
        for line, fields in enumerate(reader, 2):
            if len(fields) != 5:
                raise ValueError(f"Line {line}: expected five columns")
            code, description, usage, active_start, active_end = fields
            if not re.fullmatch(r"[0-9]{1,18}", code) or code in records:
                raise ValueError(f"Line {line}: invalid or duplicate concept ID")
            if not description or len(description.encode("utf-16-le")) > 1000:
                raise ValueError(f"Line {line}: missing or oversized description")
            if active_start not in ("0", "1") or active_end not in ("0", "1"):
                raise ValueError(f"Line {line}: invalid active flag")
            if usage == "*":
                suppressed += 1
                numeric_usage = 0
            elif re.fullmatch(r"[0-9]+", usage):
                numeric_usage = int(usage)
                if numeric_usage > 9223372036854775807:
                    raise ValueError(f"Line {line}: usage exceeds SQL bigint")
            else:
                raise ValueError(f"Line {line}: unexpected usage value")
            records[code] = (description, numeric_usage, int(active_start), int(active_end))
    if not records:
        raise ValueError("Source file contains no records")
    return records, suppressed


def verify_period(cursor, period, records):
    cursor.execute("""
        SELECT SNOMED_Concept_ID, Description, [Usage], Active_at_Start,
               Active_at_End, Geographic_Coverage
        FROM dbo.SNOMED_Usage_Data WHERE Data_Period = ?
    """, period)
    seen = set()
    for row in cursor:
        if row[0] in seen or row[0] not in records:
            raise ValueError("Unexpected or duplicate database concept ID")
        if tuple(row[1:5]) != records[row[0]] or row[5] != "England":
            raise ValueError(f"Source/database mismatch for concept {row[0]}")
        seen.add(row[0])
    if len(seen) != len(records):
        raise ValueError(f"Row count mismatch: source={len(records)}, database={len(seen)}")
    return len(seen)


def historical_totals(cursor, period):
    cursor.execute("""
        SELECT Data_Period, COUNT_BIG(*), SUM([Usage]),
               SUM(CONVERT(bigint, Active_at_Start)),
               SUM(CONVERT(bigint, Active_at_End))
        FROM dbo.SNOMED_Usage_Data WHERE Data_Period <> ?
        GROUP BY Data_Period ORDER BY Data_Period
    """, period)
    return [list(row) for row in cursor]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument("--period", required=True)
    parser.add_argument("--server", default=r"SILENTPRIORY\SQLEXPRESS")
    parser.add_argument("--database", default="SNOMEDCT")
    parser.add_argument("--source-url", required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"20[0-9]{2}-[0-9]{2}", args.period):
        parser.error("Period must use YYYY-YY format")
    if args.file.name != f"SNOMED_code_usage_{args.period}.txt":
        parser.error("File name and period must agree")
    if not args.report.parent.is_dir():
        parser.error("Report directory must already exist")

    source_hash = hashlib.sha256(args.file.read_bytes()).hexdigest()
    records, suppressed = read_source(args.file)
    print(f"Validated {len(records):,} rows; {suppressed:,} suppressed counts map to 0.", flush=True)
    connection = pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={args.server};"
        f"DATABASE={args.database};Trusted_Connection=yes;TrustServerCertificate=yes",
        autocommit=False,
    )
    committed = False
    try:
        cursor = connection.cursor()
        cursor.execute("SET XACT_ABORT ON; SET NOCOUNT ON;")
        server_name, database_name = cursor.execute("SELECT @@SERVERNAME, DB_NAME()").fetchone()
        before = historical_totals(cursor, args.period)
        existing = cursor.execute(
            "SELECT COUNT_BIG(*) FROM dbo.SNOMED_Usage_Data WITH (UPDLOCK, HOLDLOCK) WHERE Data_Period=?",
            args.period,
        ).fetchval()
        if existing:
            # A repeated run is safe only when the entire period already matches.
            verify_period(cursor, args.period, records)
            inserted = 0
        else:
            cursor.fast_executemany = True
            cursor.setinputsizes([
                (pyodbc.SQL_WVARCHAR, 18, 0), (pyodbc.SQL_WVARCHAR, 500, 0),
                (pyodbc.SQL_BIGINT, 0, 0), (pyodbc.SQL_BIT, 0, 0),
                (pyodbc.SQL_BIT, 0, 0), (pyodbc.SQL_WVARCHAR, 10, 0),
                (pyodbc.SQL_WVARCHAR, 20, 0),
            ])
            rows = [(code, *values, args.period, "England") for code, values in records.items()]
            statement = """
                INSERT INTO dbo.SNOMED_Usage_Data
                    (SNOMED_Concept_ID, Description, [Usage], Active_at_Start,
                     Active_at_End, Data_Period, Geographic_Coverage)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            for offset in range(0, len(rows), 10000):
                cursor.executemany(statement, rows[offset:offset + 10000])
                print(f"Loaded {min(offset + 10000, len(rows)):,}/{len(rows):,} rows (uncommitted).", flush=True)
            cursor.close()
            cursor = connection.cursor()
            inserted = len(rows)

        verified = verify_period(cursor, args.period, records)
        after = historical_totals(cursor, args.period)
        if before != after:
            raise ValueError("Historical period totals changed during import")
        if hashlib.sha256(args.file.read_bytes()).hexdigest() != source_hash:
            raise ValueError("Source file changed during import")

        # Check that the existing consumer discovers the new period dynamically.
        sample_codes = list(records)[:3]
        cursor.execute("EXEC dbo.GetSNOMEDUsageByPeriod @SnomedCodes=?", ",".join(sample_codes))
        column_names = [column[0] for column in cursor.description]
        usage_column = column_names.index(f"{args.period}_Usage")
        id_column = column_names.index("SNOMED_Concept_ID")
        sample_results = {row[id_column]: row[usage_column] for row in cursor.fetchall()}
        if sample_results != {code: records[code][1] for code in sample_codes}:
            raise ValueError("Stored procedure did not return expected usage values")

        connection.commit()
        committed = True
        # Read back after commit, independently of the uncommitted insert checks.
        verify_period(cursor, args.period, records)
        connection.commit()
        report = {
            "status": "committed" if inserted else "already_loaded_verified",
            "verified_at_utc": datetime.now(timezone.utc).isoformat(),
            "server": server_name, "database": database_name,
            "table": "dbo.SNOMED_Usage_Data", "data_period": args.period,
            "source_url": args.source_url, "source_file": str(args.file.resolve()),
            "source_sha256": source_hash, "source_bytes": args.file.stat().st_size,
            "source_rows": len(records), "inserted_rows": inserted, "verified_rows": verified,
            "published_numeric_usage_total": sum(values[1] for values in records.values()),
            "suppressed_rows": suppressed,
            "suppression_handling": "NHS '*' (1-4 uses) stored as 0, matching existing years; raw file retains '*'.",
            "historical_periods_unchanged": before == after,
            "historical_totals_columns": ["period", "rows", "usage", "active_start", "active_end"],
            "historical_totals": before,
            "stored_procedure_verified": "dbo.GetSNOMEDUsageByPeriod",
            "stored_procedure_sample_results": sample_results,
        }
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({key: report[key] for key in (
            "status", "server", "database", "data_period", "inserted_rows",
            "verified_rows", "published_numeric_usage_total", "suppressed_rows",
            "historical_periods_unchanged",
        )}, indent=2), flush=True)
    except Exception:
        connection.rollback()
        if committed:
            print("Import was committed, but post-commit verification/reporting failed. Inspect the database before rerunning.", flush=True)
        else:
            print("Import failed; transaction rolled back.", flush=True)
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()
