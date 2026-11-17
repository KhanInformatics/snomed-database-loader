"""
Remove unrelated SEMANTIC matches where the ReadV2 term doesn't relate to the
exclusion category. Clears ReadV2Code, ReadV2Term, MappingSource, MatchLevel, MatchScore.
"""
import pyodbc

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# Category-specific keyword sets - terms you'd EXPECT to see
category_keywords = {
    'Sexually Transmitted Disease': [
        'syphil', 'gonorrh', 'chlamyd', 'hiv', 'aids', 'htlv', 'herpes',
        'venereal', 'sexually', 'sexual', 'genital', 'cervic', 'std',
        'trichomon', 'wart', 'condylom', 'hepatit', 'papillom',
        'treponema', 'neisseria', 'immunodeficiency', 'immune deficiency',
        'pelvic inflam', 'pid', 'urethrit', 'prostat', 'epididym',
        'orchit', 'vulv', 'vagin', 'phthir', 'lice', 'pubic',
        'molluscum', 'lymphogranuloma', 'chancr', 'bubo',
        'wassermann', 'vdrl', 'tpi', 'infect', 'spiroch',
        'antibod', 'antigen', 'serology', 'titre', 'titer',
        'screening', 'contact', 'exposure', 'carrier',
        'kaposi', 'pneumocystis', 'toxoplasm',
    ],
    'Termination of Pregnancy': [
        'abort', 'terminat', 'pregnan', 'miscarr', 'ectopic', 'molar',
        'curett', 'evacuat', 'prostaglandin', 'amniot', 'foet', 'fetus',
        'fetal', 'menstru', 'menstrual extract', 'hsa1', 'form a',
        'gestat', 'obstet', 'uterus', 'uterine', 'cervix', 'cervic',
        'dilat', 'suction', 'aspiration', 'conception', 'embryo',
        'trimester', 'antenatal', 'prenatal', 'maternal',
    ],
    'Gender Related Issues': [
        'gender', 'sex reassign', 'transsex', 'transgender', 'transvestis',
        'cross-dress', 'intersex', 'dysphoria', 'identity',
        'vaginoplast', 'colpoplast', 'phalloplast', 'mastectom',
        'hysterectom', 'oophorectom', 'orchiectom', 'penectom',
        'male to female', 'female to male', 'sexual transform',
        'gonadectom', 'genital', 'hormone', 'oestrogen', 'testosterone',
    ],
    'Assisted Fertilisation': [
        'fertil', 'ivf', 'vitro', 'inseminat', 'gamete', 'gift',
        'embryo', 'oocyte', 'ovum', 'egg', 'sperm', 'donor',
        'infertil', 'ovari', 'ovulat', 'hyperstimul', 'implant',
        'fallopian', 'intrauterine', 'conception', 'reproduct',
        'assisted', 'artificial',
    ],
}

# Get all SEMANTIC mappings
cursor.execute("""
SELECT Exclusion_Category, SNOMED_ConceptID, Preferred_Term,
       ReadV2Code, ReadV2Term, MatchLevel, MatchScore
FROM RCGPDataexclusionListtoReadV2Mapping
WHERE MappingSource = 'SEMANTIC'
  AND ReadV2Code IS NOT NULL AND ReadV2Code <> ''
""")
rows = cursor.fetchall()

to_clear = []
for cat, snomed_id, snomed_term, rv2_code, rv2_term, level, score in rows:
    rv2_lower = rv2_term.lower()
    keywords = category_keywords.get(cat, [])
    found = any(kw in rv2_lower for kw in keywords)
    if not found:
        to_clear.append((cat, snomed_id, rv2_code))

print(f"Total SEMANTIC mappings: {len(rows)}")
print(f"Unrelated to clear: {len(to_clear)}")

# Clear the mappings row by row using composite key
for cat, snomed_id, rv2_code in to_clear:
    cursor.execute("""
        UPDATE RCGPDataexclusionListtoReadV2Mapping
        SET ReadV2Code = NULL, ReadV2Term = NULL,
            MappingSource = NULL, MatchLevel = NULL, MatchScore = NULL
        WHERE Exclusion_Category = ?
          AND SNOMED_ConceptID = ?
          AND ReadV2Code = ?
          AND MappingSource = 'SEMANTIC'
    """, cat, snomed_id, rv2_code)

print(f"Rows updated: {cursor.rowcount}")

# Verify new counts
cursor.execute("""
SELECT
    COUNT(*) AS Total,
    SUM(CASE WHEN ReadV2Code IS NOT NULL AND ReadV2Code <> '' THEN 1 ELSE 0 END) AS Mapped,
    SUM(CASE WHEN ReadV2Code IS NULL OR ReadV2Code = '' THEN 1 ELSE 0 END) AS Unmapped
FROM RCGPDataexclusionListtoReadV2Mapping
""")
total, mapped, unmapped = cursor.fetchone()
print(f"\nAfter cleanup:")
print(f"  Total rows:   {total}")
print(f"  Mapped:       {mapped}")
print(f"  Unmapped:     {unmapped}")

cursor.execute("""
SELECT MappingSource, MatchLevel, COUNT(*) AS Cnt
FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NOT NULL AND ReadV2Code <> ''
GROUP BY MappingSource, MatchLevel
ORDER BY MappingSource, MatchLevel
""")
print("\nMapping breakdown:")
for src, lvl, cnt in cursor.fetchall():
    print(f"  {src:10s} {lvl:20s} {cnt}")

conn.commit()
conn.close()
print("\nDone.")
