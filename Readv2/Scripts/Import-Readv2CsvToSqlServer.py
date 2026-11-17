"""
Import Readv2_codes_full.csv into SQL Server as a flat lookup table.

Source: O:\GitHub\snomed-database-loader\Readv2\Readv2_codes_full.csv
Target: SilentPriory\SQLEXPRESS -> READv2 -> dbo.Readv2Lookup

Uses CS_AS collation on TERMID to preserve case-sensitive term linkage.
"""

import csv
import pyodbc

SERVER = r"SilentPriory\SQLEXPRESS"
DATABASE = "READv2"
DRIVER = "ODBC Driver 17 for SQL Server"
CSV_PATH = r"O:\GitHub\snomed-database-loader\Readv2\Readv2_codes_full.csv"
TABLE_NAME = "Readv2Lookup"


def get_conn():
    return pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;"
    )


def main():
    print("=== Import Readv2_codes_full.csv to SQL Server ===")

    # Read CSV
    print("  Reading CSV...")
    with open(CSV_PATH, encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = [tuple(r) for r in reader]
    print(f"  Rows read: {len(rows):,}")

    conn = get_conn()
    cursor = conn.cursor()

    # Drop and recreate table
    cursor.execute(f"""
        IF OBJECT_ID('[{TABLE_NAME}]', 'U') IS NOT NULL
            DROP TABLE [{TABLE_NAME}]
    """)
    conn.commit()

    cursor.execute(f"""
        CREATE TABLE [{TABLE_NAME}] (
            [ReadCode]      VARCHAR(5)  COLLATE Latin1_General_CS_AS NOT NULL,
            [TermID]        VARCHAR(5)  COLLATE Latin1_General_CS_AS NOT NULL,
            [PreferredTerm] VARCHAR(60) NOT NULL,
            [Status]        VARCHAR(1)  NOT NULL
        )
    """)
    conn.commit()
    print(f"  Table [{TABLE_NAME}] created (CS_AS collation on ReadCode/TermID)")

    # Bulk insert
    print("  Inserting rows...")
    insert_sql = f"""
        INSERT INTO [{TABLE_NAME}] ([ReadCode], [TermID], [PreferredTerm], [Status])
        VALUES (?, ?, ?, ?)
    """
    cursor.fast_executemany = True
    cursor.executemany(insert_sql, rows)
    conn.commit()
    print(f"  Rows inserted: {len(rows):,}")

    # Create indexes
    print("  Creating indexes...")
    cursor.execute(f"""
        CREATE UNIQUE CLUSTERED INDEX [IX_{TABLE_NAME}_ReadCode]
            ON [{TABLE_NAME}] ([ReadCode]);
    """)
    cursor.execute(f"""
        CREATE NONCLUSTERED INDEX [IX_{TABLE_NAME}_TermID]
            ON [{TABLE_NAME}] ([TermID]);
    """)
    conn.commit()
    print("  Indexes created")

    # Summary
    cursor.execute(f"""
        SELECT
            COUNT(*) AS Total,
            SUM(CASE WHEN [Status] = 'C' THEN 1 ELSE 0 END) AS Current_C,
            SUM(CASE WHEN [Status] = 'R' THEN 1 ELSE 0 END) AS Redundant_R,
            SUM(CASE WHEN [Status] = 'O' THEN 1 ELSE 0 END) AS Optional_O
        FROM [{TABLE_NAME}]
    """)
    r = cursor.fetchone()
    print()
    print(f"  Total:       {r[0]:,}")
    print(f"  Current (C): {r[1]:,}")
    print(f"  Redundant:   {r[2]:,}")
    print(f"  Optional:    {r[3]:,}")

    # Sample rows
    print()
    print("  Sample rows:")
    cursor.execute(f"SELECT TOP 10 * FROM [{TABLE_NAME}] ORDER BY [ReadCode]")
    for row in cursor.fetchall():
        print(f"    {row[0]:<6} {row[1]:<6} {row[3]}  {row[2]}")

    conn.close()
    print()
    print("=== Done ===")


if __name__ == "__main__":
    main()
