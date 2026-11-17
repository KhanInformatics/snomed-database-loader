"""Import DataSharingExclusions.xlsx into SQL Server as RCGPDataexclusionListtoReadV2Mapping"""
import openpyxl, pyodbc

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# Drop if exists
cursor.execute("""
IF OBJECT_ID(N'RCGPDataexclusionListtoReadV2Mapping', N'U') IS NOT NULL
    DROP TABLE RCGPDataexclusionListtoReadV2Mapping
""")

# Create table
cursor.execute("""
CREATE TABLE RCGPDataexclusionListtoReadV2Mapping (
    Exclusion_Category   NVARCHAR(60)   NOT NULL,
    RefsetID             VARCHAR(20)    NOT NULL,
    Refset_Name          NVARCHAR(255)  NULL,
    SNOMED_ConceptID     VARCHAR(20)    NOT NULL,
    FSN_Term             NVARCHAR(500)  NULL,
    Preferred_Term       NVARCHAR(500)  NULL,
    ConceptIsActive      VARCHAR(1)     NULL,
    ReadV2Code           VARCHAR(10)    NULL,
    ReadV2Term           NVARCHAR(200)  NULL,
    CTV3Code             VARCHAR(10)    NULL,
    CTV3Term             NVARCHAR(200)  NULL
)
""")
conn.commit()
print("Table created.")

# Load Excel
wb = openpyxl.load_workbook(
    r'O:\GitHub\snomed-database-loader\Readv2\Data\DataSharingExclusions.xlsx', read_only=True
)
ws = wb['All Exclusions']

insert_sql = """INSERT INTO RCGPDataexclusionListtoReadV2Mapping
    (Exclusion_Category, RefsetID, Refset_Name, SNOMED_ConceptID, FSN_Term,
     Preferred_Term, ConceptIsActive, ReadV2Code, ReadV2Term, CTV3Code, CTV3Term)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""

# Columns that hold large numeric IDs (stored as float in Excel)
int_cols = {1, 3}  # RefsetID (B), SNOMED_ConceptID (D)

batch = []
total = 0
for row in ws.iter_rows(min_row=2, values_only=True):
    vals = []
    for i in range(11):  # cols A-K only
        v = row[i]
        if v is None:
            vals.append(None)
        elif i in int_cols:
            vals.append(str(int(v)))
        else:
            vals.append(str(v).strip())
    batch.append(vals)
    if len(batch) >= 500:
        cursor.executemany(insert_sql, batch)
        total += len(batch)
        batch = []

if batch:
    cursor.executemany(insert_sql, batch)
    total += len(batch)

conn.commit()
print(f"Inserted {total} rows.")

# Verify
cursor.execute("SELECT COUNT(*) FROM RCGPDataexclusionListtoReadV2Mapping")
print(f"Row count: {cursor.fetchone()[0]}")

cursor.execute("""
SELECT Exclusion_Category, COUNT(*) AS Cnt
FROM RCGPDataexclusionListtoReadV2Mapping
GROUP BY Exclusion_Category ORDER BY Exclusion_Category
""")
for r in cursor.fetchall():
    print(f"  {r[0]:<30} {r[1]}")

cursor.execute(
    "SELECT COUNT(*) FROM RCGPDataexclusionListtoReadV2Mapping "
    "WHERE ReadV2Code IS NOT NULL AND ReadV2Code <> ''"
)
print(f"Rows with ReadV2 mapping: {cursor.fetchone()[0]}")

conn.close()
