"""
Create and populate the Albasoft table in the READv2 database.
Extracts Read v2 codes from the $providedCodes list in compare-readcodes.ps1
and matches each to its preferred term from the READv2 database.
"""

import re
import pyodbc

SERVER = r"SilentPriory\SQLEXPRESS"
DATABASE = "READv2"
DRIVER = "ODBC Driver 17 for SQL Server"
PS1_PATH = r"O:\GitHub\snomed-database-loader\compare-readcodes.ps1"


def get_conn():
    return pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;"
    )


def extract_albasoft_codes():
    with open(PS1_PATH, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"\$providedCodes\s*=\s*@\(([\s\S]*?)\)", content)
    if not m:
        raise ValueError("Could not find $providedCodes in compare-readcodes.ps1")
    raw = m.group(1)
    codes = []
    for token in re.split(r"[,\r\n]+", raw):
        c = token.strip().strip("'").strip('"')
        if c:
            codes.append(c)
    return codes


def main():
    print("=== Albasoft Table Import ===")

    # Step 1: Extract codes
    codes = extract_albasoft_codes()
    print(f"  Albasoft codes found: {len(codes)}")

    conn = get_conn()
    cursor = conn.cursor()

    # Step 2: Drop and recreate Albasoft table
    cursor.execute("""
        IF OBJECT_ID('[AlbasoftSensitiveCodeList]', 'U') IS NOT NULL
            DROP TABLE [AlbasoftSensitiveCodeList]
    """)
    conn.commit()

    cursor.execute("""
        CREATE TABLE [AlbasoftSensitiveCodeList] (
            [AlbasoftCode]   VARCHAR(10)  NOT NULL,
            [ReadCode]       VARCHAR(5)   NULL,
            [Status]         VARCHAR(1)   NULL,
            [ConceptLevel]   INT          NULL,
            [Term30]         VARCHAR(30)  NULL,
            [Term60]         VARCHAR(60)  NULL,
            [Term198]        VARCHAR(198) NULL,
            [MatchedInREADv2] BIT         NOT NULL DEFAULT 0
        )
    """)
    conn.commit()
    print("  Table [AlbasoftSensitiveCodeList] created")

    # Step 3: Build lookup from READv2 - preferred terms for each code
    print("  Loading READv2 concept lookup...")
    cursor.execute("""
        SELECT
            c.READCODE,
            c.STATUS,
            c.LEVEL,
            t.TERM30,
            t.TERM60,
            t198.TERM198
        FROM CONCEPT c
        INNER JOIN Description d ON d.CC = c.READCODE AND d.TERMTYPE = 'P'
        INNER JOIN Term t ON t.TERMID = d.TERMID
        LEFT JOIN TERM198 t198 ON t198.TERMID = d.TERMID
    """)
    readv2 = {}
    for row in cursor.fetchall():
        rc = row[0].strip() if row[0] else None
        if rc and rc not in readv2:
            readv2[rc] = row  # keep first preferred term per code

    print(f"  READv2 concepts loaded: {len(readv2):,}")

    # Step 4: Match and insert
    rows = []
    matched = 0
    unmatched = 0

    for code in codes:
        # Try exact match, then right-pad with dots to 5 chars
        rec = readv2.get(code)
        if rec is None:
            # Pad to 5 chars with dots
            padded = (code + ".....").ljust(5, ".")[:5]
            rec = readv2.get(padded)

        if rec:
            matched += 1
            rows.append((
                code,
                rec[0].strip(),   # ReadCode
                rec[1],           # Status
                rec[2],           # Level
                rec[3].strip() if rec[3] else None,   # Term30
                rec[4].strip() if rec[4] else None,   # Term60
                rec[5].strip() if rec[5] else None,   # Term198
                1                 # MatchedInREADv2
            ))
        else:
            unmatched += 1
            rows.append((
                code,
                None, None, None, None, None, None,
                0
            ))

    insert_sql = """
        INSERT INTO [AlbasoftSensitiveCodeList]
            ([AlbasoftCode],[ReadCode],[Status],[ConceptLevel],[Term30],[Term60],[Term198],[MatchedInREADv2])
        VALUES (?,?,?,?,?,?,?,?)
    """
    cursor.fast_executemany = True
    cursor.executemany(insert_sql, rows)
    conn.commit()

    print(f"  Rows inserted: {len(rows)}")
    print(f"  Matched to READv2: {matched}")
    print(f"  Unmatched (not in READv2): {unmatched}")

    # Step 5: Index
    cursor.execute("""
        CREATE NONCLUSTERED INDEX [IX_AlbasoftSensitiveCodeList_Code] ON [AlbasoftSensitiveCodeList] ([AlbasoftCode]);
        CREATE NONCLUSTERED INDEX [IX_AlbasoftSensitiveCodeList_ReadCode] ON [AlbasoftSensitiveCodeList] ([ReadCode]);
    """)
    conn.commit()
    print("  Indexes created")

    # Step 6: Show sample
    print()
    print("  Sample matched rows:")
    cursor.execute("""
        SELECT TOP 10 AlbasoftCode, ReadCode, Status, Term60
        FROM AlbasoftSensitiveCodeList
        WHERE MatchedInREADv2 = 1
        ORDER BY AlbasoftCode
    """)
    for r in cursor.fetchall():
        print(f"    {r[0]:<10}  {r[1]:<6}  {r[2]}  {r[3]}")

    print()
    unmatched_codes = [r[0] for r in rows if r[7] == 0]
    if unmatched_codes:
        print(f"  Unmatched codes ({len(unmatched_codes)}):")
        for c in unmatched_codes:
            print(f"    {c}")

    conn.close()
    print()
    print("=== Done ===")


if __name__ == "__main__":
    main()
