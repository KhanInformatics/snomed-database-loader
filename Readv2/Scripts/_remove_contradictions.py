"""
Remove semantically contradictory SEMANTIC mappings from RCGPDataexclusionListtoReadV2Mapping.
These are TOKEN_OVERLAP matches where the ReadV2 term contradicts the SNOMED term
(e.g. "History of X" matched to "No history of X").
"""
import pyodbc
import re

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# Bad ReadV2 codes to clear (all are SEMANTIC TOKEN_OVERLAP matches with negation issues)
bad_codes = ['115L.', '15431', '4381.', '9Op3.', 'L060x', 'L08x.', 'ZV018']

# Clear the semantic mapping for rows mapped to these contradictory codes
cursor.execute(f"""
UPDATE RCGPDataexclusionListtoReadV2Mapping
SET ReadV2Code = NULL,
    ReadV2Term = NULL,
    MappingSource = NULL,
    MatchLevel = NULL,
    MatchScore = NULL
WHERE MappingSource = 'SEMANTIC'
  AND ReadV2Code IN ({','.join('?' for _ in bad_codes)})
""", *bad_codes)

cleared = cursor.rowcount
conn.commit()
print(f"Cleared {cleared} contradictory SEMANTIC mappings.")

# Summary
cursor.execute("""
SELECT MappingSource, MatchLevel, COUNT(*) AS Cnt
FROM RCGPDataexclusionListtoReadV2Mapping
GROUP BY MappingSource, MatchLevel
ORDER BY MappingSource, MatchLevel
""")
print("\nUpdated summary:")
for r in cursor.fetchall():
    src = r[0] if r[0] else '(unmapped)'
    print(f"  {src:<12} {r[1] or '(none)':<20} {r[2]}")

cursor.execute("""
SELECT COUNT(*) FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NOT NULL AND ReadV2Code <> ''
""")
print(f"\nTotal rows with ReadV2 code: {cursor.fetchone()[0]} / 2834")

conn.close()
