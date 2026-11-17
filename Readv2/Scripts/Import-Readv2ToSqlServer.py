"""
Import Read v2 terminology from Scottish Clinical Terminology Browser DBF files
into SQL Server database READv2.

Source: O:\GitHub\snomed-database-loader\Readv2\Scottish\V2\
Target: SilentPriory\SQLEXPRESS -> READv2
"""

import pyodbc
import os
import sys
import time
from dbfread import DBF

# Configuration
SERVER = r"SilentPriory\SQLEXPRESS"
DATABASE = "READv2"
DRIVER = "ODBC Driver 17 for SQL Server"
DBF_PATH = r"O:\GitHub\snomed-database-loader\Readv2\Scottish\V2"

# DBF type -> SQL type mapping
DBF_TYPE_MAP = {
    'C': lambda length: f"VARCHAR({length})",
    'N': lambda length, dec=0: f"DECIMAL({length},{dec})" if dec > 0 else f"INT" if length <= 9 else f"BIGINT",
    'L': lambda length: "BIT",
    'D': lambda length: "DATE",
    'M': lambda length: "VARCHAR(MAX)",
}

# Tables to import (name, has_data flag based on our survey)
TABLES_TO_IMPORT = [
    "CONCEPT",    # 157,128 - Core concepts
    "Term",       # 176,023 - Term descriptions (30 + 60 char)
    "DESC",       # 176,023 - Code-to-term linkage
    "HIER",       # 157,127 - Hierarchy (parent-child)
    "ANCESTOR",   # 506,820 - Transitive closure
    "ATC",        #  62,430 - ATC drug classification map
    "BNF",        #  58,354 - BNF drug classification map
    "ICD10",      #  37,312 - ICD-10 cross-map
    "ICD10TER",   #  15,758 - ICD-10 term descriptions
    "OPCS4V3",    #  14,924 - OPCS-4 cross-map
    "OPCS4TER",   #  10,896 - OPCS-4 term descriptions
    "TERM198",    #  24,630 - Long terms (198 chars)
    "TYPES",      #      51 - Concept type definitions
    "VIEWROOT",   #     115 - View root codes
]


def get_connection_string(database="master"):
    return (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={SERVER};"
        f"DATABASE={database};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )


def create_database(cursor):
    """Create the READv2 database if it doesn't exist."""
    cursor.execute(
        "SELECT database_id FROM sys.databases WHERE name = ?", DATABASE
    )
    if cursor.fetchone():
        print(f"  Database [{DATABASE}] already exists")
        return False
    else:
        cursor.execute(
            f"CREATE DATABASE [{DATABASE}] COLLATE Latin1_General_CS_AS"
        )
        print(f"  Database [{DATABASE}] created (Latin1_General_CS_AS)")
        return True


def build_create_table_sql(table_name, dbf_fields):
    """Generate CREATE TABLE SQL from DBF field definitions."""
    cols = []
    for f in dbf_fields:
        col_name = f.name
        if f.type == 'C':
            sql_type = f"VARCHAR({f.length})"
        elif f.type == 'N':
            if f.decimal_count > 0:
                sql_type = f"DECIMAL({f.length},{f.decimal_count})"
            elif f.length <= 9:
                sql_type = "INT"
            else:
                sql_type = "BIGINT"
        elif f.type == 'L':
            sql_type = "BIT"
        elif f.type == 'D':
            sql_type = "DATE"
        elif f.type == 'M':
            sql_type = "VARCHAR(MAX)"
        else:
            sql_type = f"VARCHAR({f.length})"

        cols.append(f"  [{col_name}] {sql_type} NULL")

    # Use "Description" instead of DESC to avoid SQL keyword clash
    sql_table_name = "Description" if table_name.upper() == "DESC" else table_name
    return f"CREATE TABLE [{sql_table_name}] (\n" + ",\n".join(cols) + "\n);"


def load_table(conn, table_name, dbf_path):
    """Load a single DBF table into SQL Server using fast executemany."""
    cursor = conn.cursor()
    dbf_file = os.path.join(dbf_path, f"{table_name}.DBF")

    # Handle case-sensitive file names
    if not os.path.exists(dbf_file):
        # Try lowercase
        alt = os.path.join(dbf_path, f"{table_name}.dbf")
        if os.path.exists(alt):
            dbf_file = alt
        else:
            print(f"  WARNING: {dbf_file} not found, skipping")
            return 0

    db = DBF(dbf_file, encoding='latin-1')
    sql_table_name = "Description" if table_name.upper() == "DESC" else table_name

    # Drop existing table
    cursor.execute(f"""
        IF OBJECT_ID('[{sql_table_name}]', 'U') IS NOT NULL
            DROP TABLE [{sql_table_name}]
    """)
    conn.commit()

    # Create table
    create_sql = build_create_table_sql(table_name, db.fields)
    cursor.execute(create_sql)
    conn.commit()

    # Build INSERT statement
    field_names = [f.name for f in db.fields]
    placeholders = ",".join(["?"] * len(field_names))
    col_list = ",".join([f"[{n}]" for n in field_names])
    insert_sql = f"INSERT INTO [{sql_table_name}] ({col_list}) VALUES ({placeholders})"

    # Read all records and batch insert
    start = time.time()
    rows = []
    for rec in db:
        row = []
        for fn in field_names:
            val = rec[fn]
            if isinstance(val, str):
                val = val.strip()
            row.append(val)
        rows.append(tuple(row))

    if rows:
        cursor.fast_executemany = True
        batch_size = 10000
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i + batch_size]
            cursor.executemany(insert_sql, batch)
        conn.commit()

    elapsed = time.time() - start
    return len(rows), elapsed


def add_indexes(conn):
    """Add useful indexes after data load."""
    cursor = conn.cursor()
    indexes = [
        ("IX_Concept_ReadCode", "CONCEPT", "READCODE"),
        ("IX_Concept_Status", "CONCEPT", "STATUS"),
        ("IX_Term_TermID", "Term", "TERMID"),
        ("IX_Description_CC", "Description", "CC"),
        ("IX_Description_TermID", "Description", "TERMID"),
        ("IX_Description_TermType", "Description", "TERMTYPE"),
        ("IX_Hier_CC", "HIER", "CC"),
        ("IX_Hier_PCC", "HIER", "PCC"),
        ("IX_Ancestor_ReadCode", "ANCESTOR", "READCODE"),
        ("IX_Ancestor_Descendant", "ANCESTOR", "DESCENDANT"),
        ("IX_ATC_ReadCode", "ATC", "READCODE"),
        ("IX_BNF_ReadCode", "BNF", "READCODE"),
        ("IX_ICD10_ReadCode", "ICD10", "READ_CODE"),
        ("IX_OPCS4V3_ReadCode", "OPCS4V3", "READ_CODE"),
        ("IX_Term198_TermID", "TERM198", "TERMID"),
    ]
    for idx_name, tbl, col in indexes:
        try:
            cursor.execute(f"""
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = '{idx_name}')
                    CREATE NONCLUSTERED INDEX [{idx_name}] ON [{tbl}] ([{col}])
            """)
        except Exception as e:
            print(f"  Index {idx_name}: {e}")
    conn.commit()
    print("  Indexes created")


def create_code_lookup_view(conn):
    """Create a convenience view joining codes to their preferred terms."""
    cursor = conn.cursor()
    cursor.execute("""
        IF OBJECT_ID('vw_ReadCodeLookup', 'V') IS NOT NULL
            DROP VIEW vw_ReadCodeLookup
    """)
    conn.commit()
    cursor.execute("""
        CREATE VIEW vw_ReadCodeLookup AS
        SELECT
            c.READCODE,
            c.STATUS,
            c.CONTYPE,
            c.LEVEL,
            d.TERMID,
            d.TERMTYPE,
            t.TERM30,
            t.TERM60,
            t198.TERM198
        FROM CONCEPT c
        INNER JOIN Description d ON d.CC = c.READCODE AND d.TERMTYPE = 'P'
        INNER JOIN Term t ON t.TERMID = d.TERMID
        LEFT JOIN TERM198 t198 ON t198.TERMID = d.TERMID
    """)
    conn.commit()
    print("  View vw_ReadCodeLookup created")


def main():
    print(f"=== Read v2 Import to SQL Server ===")
    print(f"Source: {DBF_PATH}")
    print(f"Target: {SERVER} -> [{DATABASE}]")
    print()

    # Step 1: Create database
    print("[1/4] Creating database...")
    conn_master = pyodbc.connect(get_connection_string("master"), autocommit=True)
    create_database(conn_master.cursor())
    conn_master.close()
    print()

    # Step 2 & 3: Create tables and load data
    print("[2/4] Loading tables...")
    conn = pyodbc.connect(get_connection_string(DATABASE))
    total_rows = 0
    total_time = 0

    for table_name in TABLES_TO_IMPORT:
        sys.stdout.write(f"  {table_name:12s} ... ")
        sys.stdout.flush()
        result = load_table(conn, table_name, DBF_PATH)
        if isinstance(result, tuple):
            count, elapsed = result
            total_rows += count
            total_time += elapsed
            print(f"{count:>10,} rows  ({elapsed:.1f}s)")
        else:
            print(f"skipped")

    print(f"\n  Total: {total_rows:,} rows loaded in {total_time:.1f}s")
    print()

    # Step 4: Create indexes
    print("[3/4] Creating indexes...")
    add_indexes(conn)
    print()

    # Step 5: Create convenience view
    print("[4/4] Creating views...")
    create_code_lookup_view(conn)
    print()

    # Summary query
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM vw_ReadCodeLookup")
    view_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM vw_ReadCodeLookup WHERE [STATUS] = 'C'")
    current_count = cursor.fetchone()[0]
    print(f"=== Complete ===")
    print(f"  Codes in lookup view: {view_count:,}")
    print(f"  Current (active) codes: {current_count:,}")

    conn.close()


if __name__ == "__main__":
    main()
