"""
Add MatchLevel, MatchScore, MappingSource columns to RCGPDataexclusionListtoReadV2Mapping
and populate with semantic match results.
"""
import pyodbc
import csv

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# 1. Add new columns (if they don't already exist)
for col, typedef in [
    ('MappingSource', 'VARCHAR(20)'),
    ('MatchLevel', 'VARCHAR(20)'),
    ('MatchScore', 'DECIMAL(4,3)'),
]:
    cursor.execute(f"""
        IF NOT EXISTS (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID('RCGPDataexclusionListtoReadV2Mapping')
            AND name = '{col}'
        )
        ALTER TABLE RCGPDataexclusionListtoReadV2Mapping ADD {col} {typedef} NULL
    """)
conn.commit()
print("Columns added (or already exist).")

# 2. Mark existing DMWB-mapped rows
cursor.execute("""
UPDATE RCGPDataexclusionListtoReadV2Mapping
SET MappingSource = 'DMWB',
    MatchLevel = 'DMWB_CROSSMAP',
    MatchScore = 1.000
WHERE ReadV2Code IS NOT NULL AND ReadV2Code <> ''
""")
dmwb_count = cursor.rowcount
conn.commit()
print(f"Marked {dmwb_count} existing rows as DMWB.")

# 3. Load the semantic match CSV, pick best match per (SNOMED_ConceptID, Category)
best = {}  # (snomed_id, category) -> (score, level, rv2code, rv2term)
with open(r'O:\GitHub\snomed-database-loader\Readv2\Data\UnmappedSNOMED_to_ReadV2_Matches.csv',
          encoding='utf-8') as f:
    for row in csv.DictReader(f):
        key = (row['SNOMED_ConceptID'], row['Exclusion_Category'])
        score = float(row['Score'])
        # Priority: EXACT > NORMALISED > TOKEN_OVERLAP, then by score
        level_priority = {'EXACT': 3, 'NORMALISED': 2, 'TOKEN_OVERLAP': 1}
        lp = level_priority.get(row['MatchLevel'], 0)
        existing = best.get(key)
        if existing is None or (lp, score) > (existing[0], existing[1]):
            best[key] = (lp, score, row['MatchLevel'], row['ReadV2Code'], row['ReadV2Term'])

print(f"Best matches loaded: {len(best)} (SNOMED, Category) pairs")

# 4. Update the table with semantic matches
updated = 0
for (snomed_id, category), (_, score, level, rv2code, rv2term) in best.items():
    cursor.execute("""
        UPDATE RCGPDataexclusionListtoReadV2Mapping
        SET ReadV2Code = ?,
            ReadV2Term = ?,
            MappingSource = 'SEMANTIC',
            MatchLevel = ?,
            MatchScore = ?
        WHERE SNOMED_ConceptID = ?
          AND Exclusion_Category = ?
          AND (ReadV2Code IS NULL OR ReadV2Code = '')
    """, rv2code, rv2term, level, score, snomed_id, category)
    updated += cursor.rowcount
conn.commit()
print(f"Updated {updated} rows with semantic matches.")

# 5. Summary
cursor.execute("""
SELECT MappingSource, MatchLevel, COUNT(*) AS Cnt
FROM RCGPDataexclusionListtoReadV2Mapping
GROUP BY MappingSource, MatchLevel
ORDER BY MappingSource, MatchLevel
""")
print("\nSummary:")
for r in cursor.fetchall():
    src = r[0] if r[0] else '(unmapped)'
    print(f"  {src:<12} {r[1] or '(none)':<20} {r[2]}")

cursor.execute("""
SELECT COUNT(*) FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NOT NULL AND ReadV2Code <> ''
""")
print(f"\nTotal rows with ReadV2 code: {cursor.fetchone()[0]} / 2834")

conn.close()
