"""
Find and remove semantically contradictory mappings from RCGPDataexclusionListtoReadV2Mapping.
E.g. SNOMED "History of X" mapped to ReadV2 "No history of X", or positive/negative inversions.
"""
import pyodbc
import re

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# Get all semantic matches (DMWB ones are authoritative, skip those)
cursor.execute("""
SELECT SNOMED_ConceptID, Exclusion_Category, Preferred_Term, ReadV2Code, ReadV2Term,
       MappingSource, MatchLevel, MatchScore
FROM RCGPDataexclusionListtoReadV2Mapping
WHERE MappingSource = 'SEMANTIC'
  AND ReadV2Code IS NOT NULL AND ReadV2Code <> ''
""")
rows = cursor.fetchall()
print(f"Semantic mappings to check: {len(rows)}")

# Detect contradictory patterns
contradictions = []

for r in rows:
    snomed_id, category, snomed_term, rv2_code, rv2_term, source, level, score = r
    s = snomed_term.lower().strip()
    v = rv2_term.lower().strip()
    
    reasons = []
    
    # 1. Negation mismatch: one has "no " or "not " or "without" but the other doesn't
    s_neg = bool(re.search(r'\bno\b|\bnot\b|\bnon[\s-]|\bwithout\b|\bnegative\b|\babsence\b|\bno history\b', s))
    v_neg = bool(re.search(r'\bno\b|\bnot\b|\bnon[\s-]|\bwithout\b|\bnegative\b|\babsence\b|\bno history\b', v))
    if s_neg != v_neg:
        reasons.append("NEGATION_MISMATCH")
    
    # 2. History vs No history
    s_hx = bool(re.search(r'\bhistory of\b|\bh/o\b|\bh/o:\b', s))
    v_no_hx = bool(re.search(r'\bno history\b|\bno h/o\b|\bno fh\b', v))
    if s_hx and v_no_hx:
        reasons.append("HISTORY_vs_NO_HISTORY")
    
    # 3. Positive vs Negative (lab results)
    s_pos = bool(re.search(r'\bpositive\b', s))
    v_neg_lab = bool(re.search(r'\bnegative\b', v))
    if s_pos and v_neg_lab:
        reasons.append("POSITIVE_vs_NEGATIVE")
    s_neg2 = bool(re.search(r'\bnegative\b', s))
    v_pos = bool(re.search(r'\bpositive\b', v))
    if s_neg2 and v_pos:
        reasons.append("NEGATIVE_vs_POSITIVE")
    
    # 4. Presence vs Absence
    s_present = bool(re.search(r'\bpresence\b|\bpresent\b', s))
    v_absent = bool(re.search(r'\babsence\b|\babsent\b', v))
    if s_present and v_absent:
        reasons.append("PRESENCE_vs_ABSENCE")
    
    # 5. Acute vs Chronic mismatch
    s_acute = bool(re.search(r'\bacute\b', s)) and not bool(re.search(r'\bchronic\b', s))
    v_chronic = bool(re.search(r'\bchronic\b', v)) and not bool(re.search(r'\bacute\b', v))
    if s_acute and v_chronic:
        reasons.append("ACUTE_vs_CHRONIC")
    s_chronic = bool(re.search(r'\bchronic\b', s)) and not bool(re.search(r'\bacute\b', s))
    v_acute = bool(re.search(r'\bacute\b', v)) and not bool(re.search(r'\bchronic\b', v))
    if s_chronic and v_acute:
        reasons.append("CHRONIC_vs_ACUTE")
    
    # 6. Male vs Female
    s_male = bool(re.search(r'\bmale\b|\bman\b|\bmen\b|\bpaternal\b', s)) and not bool(re.search(r'\bfemale\b', s))
    v_female = bool(re.search(r'\bfemale\b|\bwoman\b|\bwomen\b|\bmaternal\b', v)) and not bool(re.search(r'\bmale\b', v))
    if s_male and v_female:
        reasons.append("MALE_vs_FEMALE")
    
    # 7. Screening vs Treatment (very different)
    s_screen = bool(re.search(r'\bscreening\b|\btest\b', s))
    v_treat = bool(re.search(r'\btreatment\b|\btherapy\b', v))
    s_treat = bool(re.search(r'\btreatment\b|\btherapy\b', s))
    v_screen = bool(re.search(r'\bscreening\b|\btest\b', v))
    # Only flag if they're clearly opposite and no overlap
    
    # 8. "Excluded" / "Declined" vs offered/done
    s_declined = bool(re.search(r'\bdeclined\b|\brefused\b|\bexcluded\b', s))
    v_done = not bool(re.search(r'\bdeclined\b|\brefused\b|\bexcluded\b', v))
    # Too broad, skip
    
    if reasons:
        contradictions.append((snomed_id, category, snomed_term, rv2_code, rv2_term, level, score, reasons))

print(f"\nContradictory mappings found: {len(contradictions)}")
print()

for snomed_id, cat, snomed_term, rv2_code, rv2_term, level, score, reasons in sorted(contradictions, key=lambda x: x[3]):
    print(f"  {rv2_code:<8} [{', '.join(reasons)}]")
    print(f"    SNOMED: {snomed_term[:75]}")
    print(f"    ReadV2: {rv2_term[:75]}")
    print(f"    Level: {level}  Score: {score}")
    print()

conn.close()
