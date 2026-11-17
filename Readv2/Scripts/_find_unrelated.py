"""
Find SEMANTIC matches where the ReadV2 term doesn't appear related to the
exclusion category (STD, TOP, Gender, Fertility).
"""
import pyodbc
import re

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

cursor.execute("""
SELECT Exclusion_Category, SNOMED_ConceptID, Preferred_Term,
       ReadV2Code, ReadV2Term, MatchLevel, MatchScore
FROM RCGPDataexclusionListtoReadV2Mapping
WHERE MappingSource = 'SEMANTIC'
  AND ReadV2Code IS NOT NULL AND ReadV2Code <> ''
ORDER BY Exclusion_Category, ReadV2Code
""")
rows = cursor.fetchall()
conn.close()

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

suspect = []

for cat, snomed_id, snomed_term, rv2_code, rv2_term, level, score in rows:
    rv2_lower = rv2_term.lower()
    keywords = category_keywords.get(cat, [])

    # Check if ANY category keyword appears in the ReadV2 term
    found = any(kw in rv2_lower for kw in keywords)

    if not found:
        suspect.append((cat, snomed_id, snomed_term, rv2_code, rv2_term, level, score))

print(f"Total SEMANTIC mappings checked: {len(rows)}")
print(f"Suspect (ReadV2 term unrelated to category): {len(suspect)}")
print()

for cat, sid, sterm, code, vterm, level, score in sorted(suspect, key=lambda x: (x[0], float(x[6]))):
    print(f"  {code:<8} Score:{score}  Level:{level}")
    print(f"    Category: {cat}")
    print(f"    SNOMED:   {sterm[:70]}")
    print(f"    ReadV2:   {vterm[:70]}")
    print()
