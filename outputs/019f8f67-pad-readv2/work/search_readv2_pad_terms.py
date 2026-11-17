from collections import defaultdict
from pathlib import Path
import json
import re

from dbfread import DBF


ROOT = Path(r"O:\GitHub\snomed-database-loader")
V2 = ROOT / "Readv2" / "Scottish" / "V2"
OUTPUT = (
    ROOT
    / "outputs"
    / "019f8f67-pad-readv2"
    / "readv2_semantic_candidates.json"
)

PATTERN = re.compile(
    r"(isch[ae]em|atheroscl|claudicat|gangren|"
    r"arterial.{0,20}ulcer|ulcer.{0,20}arterial|"
    r"rest.{0,15}pain|pain.{0,15}rest|critical|trash foot|"
    r"lower limb.{0,25}occlu|leg arter|peripheral vascular disease)",
    re.IGNORECASE,
)


terms = {
    str(row["TERMID"]).strip(): str(row["TERM60"]).strip()
    for row in DBF(V2 / "Term.dbf", encoding="latin-1")
}
status = {
    str(row["READCODE"]).strip(): str(row["STATUS"]).strip()
    for row in DBF(V2 / "CONCEPT.DBF", encoding="latin-1")
}

matches = defaultdict(list)
all_code_terms = defaultdict(list)
for row in DBF(V2 / "DESC.DBF", encoding="latin-1"):
    code = str(row["CC"]).strip()
    term_id = str(row["TERMID"]).strip()
    term = terms.get(term_id, "")
    all_code_terms[code].append(
        {
            "term_id": term_id,
            "term_type": str(row["TERMTYPE"]).strip(),
            "term": term,
        }
    )
    if PATTERN.search(term):
        matches[code].append(
            {
                "term_id": term_id,
                "term_type": str(row["TERMTYPE"]).strip(),
                "term": term,
            }
        )

result = [
    {
        "read_code": code,
        "status": status.get(code, ""),
        "terms": sorted(
            values,
            key=lambda item: (
                item["term_type"] != "P",
                item["term"].casefold(),
            ),
        ),
    }
    for code, values in sorted(matches.items())
    if status.get(code, "") in {"C", "R", "O"}
]

OUTPUT.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"Wrote {len(result)} matching Read v2 concepts to {OUTPUT}")
for item in result:
    if item["read_code"].startswith(("G7", "M27", "1M", "1D", "2G")):
        rendered_terms = " | ".join(
            f'{term["term_type"]}:{term["term"]}' for term in item["terms"]
        )
        print(f'{item["read_code"]}\t{item["status"]}\t{rendered_terms}')

print("\nFULL_TERMS_FOR_RELEVANT_CODES")
relevant_codes = [
    "1DCA.",
    "1M110",
    "1M111",
    "2G48.",
    "2G54.",
    "2G55.",
    "2G63.",
    "G73..",
    "G732.",
    "G7320",
    "G7321",
    "G733.",
    "G734.",
    "G73y.",
    "G73z0",
    "G742.",
    "G7429",
    "G76A.",
    "M271.",
    "M2710",
    "M2713",
    "M2714",
]
for code in relevant_codes:
    rendered_terms = " | ".join(
        f'{item["term_type"]}:{item["term"]}'
        for item in sorted(
            all_code_terms.get(code, []),
            key=lambda item: (
                item["term_type"] != "P",
                item["term"].casefold(),
            ),
        )
    )
    print(f"{code}\t{status.get(code, '')}\t{rendered_terms}")
