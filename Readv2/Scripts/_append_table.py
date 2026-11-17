"""
Convert query output to markdown table and append to MAPPING_STRATEGY.md
"""
lines = []
with open(r'O:\GitHub\snomed-database-loader\Readv2\_query_output.txt', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line or 'rows affected' in line:
            continue
        parts = line.split('|')
        if len(parts) == 8:
            lines.append(parts)

# Group by category
from collections import defaultdict
cats = defaultdict(list)
for parts in lines:
    cats[parts[0].strip()].append([p.strip() for p in parts])

# Build markdown
md = []
md.append("")
md.append("---")
md.append("")
md.append("## Appendix: Final Mapped Read V2 Codes")
md.append("")
md.append(f"**{len(lines)} unique Read V2 codes** after deduplication (DMWB preferred over SEMANTIC, highest score wins).")
md.append("")

for cat in sorted(cats.keys()):
    rows = cats[cat]
    md.append(f"### {cat} ({len(rows)} codes)")
    md.append("")
    md.append("| SNOMED ConceptID | SNOMED Preferred Term | ReadV2Code | ReadV2 Term | MappingSource | MatchLevel | MatchScore |")
    md.append("|---|---|---|---|---|---|---|")
    for parts in rows:
        # parts: cat, snomed_id, snomed_term, rv2code, rv2term, source, level, score
        snomed_id = parts[1]
        snomed_term = parts[2].replace('|', '\\|')
        rv2code = parts[3]
        rv2term = parts[4].replace('|', '\\|')
        source = parts[5]
        level = parts[6]
        score = parts[7]
        md.append(f"| {snomed_id} | {snomed_term} | {rv2code} | {rv2term} | {source} | {level} | {score} |")
    md.append("")

result = '\n'.join(md)

with open(r'O:\GitHub\snomed-database-loader\Readv2\MAPPING_STRATEGY.md', 'a', encoding='utf-8') as f:
    f.write(result)

print(f"Appended {len(lines)} rows across {len(cats)} categories")
