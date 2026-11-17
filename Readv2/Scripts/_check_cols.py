import pyodbc
conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
c = conn.cursor()

c.execute("""SELECT name FROM sys.columns
WHERE object_id = OBJECT_ID('RCGPDataexclusionListtoReadV2Mapping')
ORDER BY column_id""")
print("Columns:")
for r in c.fetchall():
    print(f"  {r[0]}")

c.execute("""SELECT Exclusion_Category, COUNT(*) AS n
FROM RCGPDataexclusionListtoReadV2Mapping
GROUP BY Exclusion_Category ORDER BY Exclusion_Category""")
print("\nExclusion_Category counts:")
for r in c.fetchall():
    print(f"  {r[0]} : {r[1]}")

conn.close()
