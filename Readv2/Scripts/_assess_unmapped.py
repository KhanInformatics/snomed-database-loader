"""Assess unmapped terms and find semantic matches in READv2"""
import pyodbc

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# How many unmapped?
cursor.execute("""
SELECT COUNT(*) FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NULL OR ReadV2Code = ''
""")
print(f"Unmapped rows (no ReadV2Code): {cursor.fetchone()[0]}")

# How many distinct unmapped preferred terms?
cursor.execute("""
SELECT COUNT(DISTINCT Preferred_Term) FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NULL OR ReadV2Code = ''
""")
print(f"Distinct unmapped preferred terms: {cursor.fetchone()[0]}")

# Sample
cursor.execute("""
SELECT TOP 20 Preferred_Term, SNOMED_ConceptID, Exclusion_Category
FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NULL OR ReadV2Code = ''
ORDER BY Preferred_Term
""")
print("\nSample unmapped terms:")
for r in cursor.fetchall():
    print(f"  {r[2][:25]:<27} {r[1]:<20} {r[0][:70]}")

# Readv2Lookup size
cursor.execute("SELECT COUNT(*) FROM Readv2Lookup")
print(f"\nReadv2Lookup total: {cursor.fetchone()[0]} terms")

conn.close()
