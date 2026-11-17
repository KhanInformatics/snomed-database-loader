"""
Find Read v2 terms that semantically match unmapped SNOMED preferred terms
from RCGPDataexclusionListtoReadV2Mapping.

Multi-level matching:
  1. Exact case-insensitive
  2. Normalised match (strip prefixes, suffixes, punctuation)
  3. Token-overlap scoring (Jaccard similarity >= 0.6)
"""
import pyodbc
import re
import csv
from collections import defaultdict

conn = pyodbc.connect(
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=SilentPriory\SQLEXPRESS;DATABASE=READv2;'
    'Trusted_Connection=yes;TrustServerCertificate=yes;'
)
cursor = conn.cursor()

# Get unmapped SNOMED preferred terms (distinct)
cursor.execute("""
SELECT DISTINCT Preferred_Term, SNOMED_ConceptID, Exclusion_Category
FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NULL OR ReadV2Code = ''
""")
unmapped = []
for r in cursor.fetchall():
    unmapped.append((r[0], r[1], r[2]))
print(f"Unmapped SNOMED terms to match: {len(unmapped)}")

# Get already-mapped codes so we don't re-report them
cursor.execute("""
SELECT DISTINCT ReadV2Code FROM RCGPDataexclusionListtoReadV2Mapping
WHERE ReadV2Code IS NOT NULL AND ReadV2Code <> ''
""")
already_mapped = set(r[0] for r in cursor.fetchall())
print(f"Already-mapped ReadV2 codes to exclude: {len(already_mapped)}")

# Load entire Readv2Lookup into memory
cursor.execute("SELECT ReadCode, PreferredTerm FROM Readv2Lookup")
rv2_all = [(r[0], r[1]) for r in cursor.fetchall()]
print(f"Read v2 terms loaded: {len(rv2_all)}")
conn.close()

# Build lookup structures
# 1. Case-insensitive exact lookup
rv2_by_lower = defaultdict(list)
for code, term in rv2_all:
    rv2_by_lower[term.lower()].append((code, term))

# Normalisation function
def normalise(text):
    """Strip clinical term prefixes/suffixes and normalise for comparison."""
    t = text.lower().strip()
    # Remove common prefixes
    t = re.sub(r'^\[x\]\s*', '', t)
    t = re.sub(r'^\[v\]\s*', '', t)
    t = re.sub(r'^\[d\]\s*', '', t)
    # Remove trailing NOS, NEC, unspecified
    t = re.sub(r'\s*-?\s*nos$', '', t)
    t = re.sub(r'\s*-?\s*nec$', '', t)
    t = re.sub(r',?\s*unspecified$', '', t)
    # Remove content in parentheses for normalised compare
    # but keep the core meaning
    # Normalise punctuation
    t = t.replace('&/or', 'or').replace('&', 'and')
    t = re.sub(r'[,;:\.\-/]+', ' ', t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t

# 2. Normalised lookup
rv2_by_norm = defaultdict(list)
for code, term in rv2_all:
    n = normalise(term)
    rv2_by_norm[n].append((code, term))

# Tokenise for overlap matching
def tokenise(text):
    """Extract meaningful tokens from a clinical term."""
    t = normalise(text)
    # Remove very short words and stopwords
    stopwords = {'a', 'an', 'the', 'of', 'in', 'to', 'and', 'or', 'for',
                 'with', 'by', 'on', 'at', 'is', 'as', 'not', 'no', 'nos',
                 'nec', 'other', 'x', 'v', 'd', 'unspecified'}
    tokens = set(re.findall(r'[a-z0-9]{3,}', t)) - stopwords
    return tokens

# Pre-tokenise all rv2 terms and build inverted index for fast lookup
rv2_tokens = {}  # code -> (term, token_set)
token_to_codes = defaultdict(set)  # token -> set of rv2 codes

for code, term in rv2_all:
    if code in already_mapped:
        continue
    tokens = tokenise(term)
    rv2_tokens[code] = (term, tokens)
    for tok in tokens:
        token_to_codes[tok].add(code)

print(f"Indexed {len(rv2_tokens)} non-mapped rv2 terms, {len(token_to_codes)} unique tokens")
print("Starting matching...\n")

# Results
results = []  # (snomed_term, snomed_id, category, match_level, rv2_code, rv2_term, score)

matched_snomed = 0
unmatched_snomed = 0

for snomed_term, snomed_id, category in unmapped:
    found = False
    
    # Level 1: Exact case-insensitive
    lower = snomed_term.lower()
    if lower in rv2_by_lower:
        for code, rv2term in rv2_by_lower[lower]:
            if code not in already_mapped:
                results.append((snomed_term, snomed_id, category, 'EXACT', code, rv2term, 1.0))
                found = True
        if found:
            matched_snomed += 1
            continue
    
    # Level 2: Normalised match
    norm = normalise(snomed_term)
    if norm in rv2_by_norm:
        for code, rv2term in rv2_by_norm[norm]:
            if code not in already_mapped:
                results.append((snomed_term, snomed_id, category, 'NORMALISED', code, rv2term, 0.95))
                found = True
        if found:
            matched_snomed += 1
            continue
    
    # Level 3: Token overlap via inverted index (Jaccard >= 0.6, at least 2 shared tokens)
    snomed_tokens = tokenise(snomed_term)
    if len(snomed_tokens) < 2:
        unmatched_snomed += 1
        continue
    
    # Find candidate rv2 codes that share at least one token
    candidate_codes = set()
    for tok in snomed_tokens:
        candidate_codes.update(token_to_codes.get(tok, set()))
    
    best_matches = []
    for code in candidate_codes:
        rv2term, rv2tok = rv2_tokens[code]
        if not rv2tok:
            continue
        intersection = snomed_tokens & rv2tok
        if len(intersection) < 2:
            continue
        union = snomed_tokens | rv2tok
        jaccard = len(intersection) / len(union)
        if jaccard >= 0.6:
            best_matches.append((jaccard, code, rv2term))
    
    # Take top matches (sorted by score descending)
    best_matches.sort(reverse=True, key=lambda x: x[0])
    for score, code, rv2term in best_matches[:3]:  # top 3 per SNOMED term
        results.append((snomed_term, snomed_id, category, 'TOKEN_OVERLAP', code, rv2term, round(score, 3)))
        found = True
    
    if found:
        matched_snomed += 1
    else:
        unmatched_snomed += 1

print(f"SNOMED terms with matches found: {matched_snomed}")
print(f"SNOMED terms with no match: {unmatched_snomed}")
print(f"Total result rows: {len(results)}")

# Count by level
from collections import Counter
level_counts = Counter(r[3] for r in results)
for level in ['EXACT', 'NORMALISED', 'TOKEN_OVERLAP']:
    print(f"  {level}: {level_counts.get(level, 0)} matches")

# Write CSV
outpath = r'O:\GitHub\snomed-database-loader\Readv2\Data\UnmappedSNOMED_to_ReadV2_Matches.csv'
with open(outpath, 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['SNOMED_PreferredTerm', 'SNOMED_ConceptID', 'Exclusion_Category',
                'MatchLevel', 'ReadV2Code', 'ReadV2Term', 'Score'])
    for r in sorted(results, key=lambda x: (-x[6], x[2], x[0])):
        w.writerow(r)

print(f"\nResults written to: {outpath}")

# Show sample of each level
for level in ['EXACT', 'NORMALISED', 'TOKEN_OVERLAP']:
    samples = [r for r in results if r[3] == level][:5]
    if samples:
        print(f"\n--- Sample {level} matches ---")
        for snomed_term, sid, cat, ml, code, rv2term, score in samples:
            print(f"  SNOMED: {snomed_term[:55]}")
            print(f"  ReadV2: {code} = {rv2term[:55]}  (score={score})")
            print()
