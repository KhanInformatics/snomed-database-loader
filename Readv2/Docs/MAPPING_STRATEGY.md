# RCGP Data Sharing Exclusions - Read V2 Mapping Strategy

## Background

The RCGP (Royal College of General Practitioners) publishes a set of SNOMED CT reference sets that define clinical codes which should be excluded from GP summary data sharing. These fall into four sensitive categories:

1. **Sexually Transmitted Disease** - *General practice summary data sharing exclusion for sexually transmitted disease simple reference set*
2. **Termination of Pregnancy** - *General practice summary data sharing exclusion for termination of pregnancy simple reference set*
3. **Gender Related Issues** - *General practice summary data sharing exclusion for gender related issues simple reference set*
4. **Assisted Fertilisation** - *General practice summary data sharing exclusion for assisted fertilisation simple reference set*

The exclusion list contains **2,834 SNOMED CT concepts** across these categories. Our goal was to map as many as possible back to **Read V2 codes**, since many GP systems still use Read V2 internally.

---

## Phase 1: Database Foundation

### Problem - Case-Insensitive Collation

The original `READv2` database was created with `SQL_Latin1_General_CP1_CI_AS` (case-insensitive) collation. Read V2 TERMIDs are **case-sensitive** - for example, `000gs` = "Married" while `000gS` = "FH: Female genital mutilation". With 176,023 terms but only 61,623 case-insensitive distinct TERMIDs, there were **114,400 collisions**, causing wrong terms to appear throughout downstream outputs.

### Fix

- Dropped and recreated the `READv2` database with **`Latin1_General_CS_AS`** (case-sensitive) collation.
- Reimported all **14 DBF tables** from the Scottish Clinical Terminology Browser V2 source files (1,397,591 rows total).
- Created a flat **`Readv2Lookup`** table (157,128 rows) from `Readv2_codes_full.csv` for fast term lookups.
- Reimported the **`AlbasoftSensitiveCodeList`** (487 rows) and verified 485/485 term match.

---

## Phase 2: DMWB Crossmap (Primary Source)

The **Data Migration Workbench (DMWB)** provides an official NHS crossmap between SNOMED CT and Read V2 via the `DMWB_NHS_READ_RCT` table.

- Ran `Export-DataSharingExclusions.ps1` to join the SNOMED exclusion refsets against the DMWB crossmap.
- This produced **601 mappings** (SNOMED → Read V2) where an official crossmap existed.
- Read V2 terms were sourced from `READv2.dbo.Readv2Lookup` (not DMWB's T60 field, which had blanks for many entries).
- Exported to `DataSharingExclusions.xlsx` and verified 591/591 term match against the Read V2 database.

**Result: 601 of 2,834 SNOMED concepts mapped via DMWB.**

---

## Phase 3: Import to SQL Server

To enable further analysis, the full Excel workbook was imported into SQL Server:

- Created `_import_exclusions.py` to load `DataSharingExclusions.xlsx` into the **`RCGPDataexclusionListtoReadV2Mapping`** table.
- Columns A–K: `Exclusion_Category`, `RefsetID`, `Refset_Name`, `SNOMED_ConceptID`, `FSN_Term`, `Preferred_Term`, `ConceptIsActive`, `ReadV2Code`, `ReadV2Term`, `CTV3Code`, `CTV3Term`.
- Handled float-to-int conversion for `RefsetID` and `SNOMED_ConceptID`.
- Verified 2,834/2,834 exact row match.

---

## Phase 4: Semantic Matching (Unmapped Terms)

With 2,233 SNOMED concepts having no DMWB crossmap, we attempted automated term matching against the full Read V2 terminology.

### Matching Levels

Created `_match_unmapped.py` with a three-tier approach:

| Level | Method | Threshold |
|---|---|---|
| **EXACT** | Case-insensitive string equality between SNOMED Preferred Term and Read V2 term | 100% |
| **NORMALISED** | Strip common prefixes/suffixes (NOS, unspecified, etc.), then compare | High similarity |
| **TOKEN_OVERLAP** | Tokenise both terms, compute Jaccard similarity using an inverted index | ≥ 0.6 |

### Results

- **302 EXACT** matches - identical term text across terminologies
- **25 NORMALISED** matches - same concept after stripping qualifiers
- **416 TOKEN_OVERLAP** matches - significant word overlap (Jaccard ≥ 0.6)

**Total: 743 additional mappings found, covering 377 distinct Read V2 codes.**

---

## Phase 5: Provenance Tracking

Added three columns to the mapping table via `_update_mapping_source.py`:

| Column | Purpose |
|---|---|
| `MappingSource` | `DMWB` or `SEMANTIC` - where the mapping came from |
| `MatchLevel` | `DMWB_CROSSMAP`, `EXACT`, `NORMALISED`, or `TOKEN_OVERLAP` |
| `MatchScore` | Numeric confidence (1.000 for DMWB/EXACT, variable for others) |

This allows downstream consumers to filter by confidence level.

---

## Phase 6: Quality Assurance - Contradiction Removal

### Round 1: Negation Mismatches

Created `_find_contradictions.py` to detect semantic mismatches where a SNOMED term was mapped to a Read V2 term with opposite meaning:

- "History of X" → "No history of X"
- "With complication" → "Without complication"
- Positive condition → Negative/absent condition

Found and removed **30 contradictory mappings** across 7 Read V2 codes (`115L.`, `15431`, `4381.`, `9Op3.`, `L060x`, `L08x.`, `ZV018`).

### Round 2: Category Relevance Check

Created `_find_unrelated.py` to verify that each SEMANTIC match's Read V2 term is actually relevant to its exclusion category, using category-specific keyword lists.

Found **63 unrelated matches** where TOKEN_OVERLAP had matched on generic structural words while losing the disease-specific qualifier. Common patterns:

- **Generic swaps**: "Syphilitic optic atrophy" → "Unspecified optic atrophy"
- **Lost specifiers**: "Referral to genitourinary clinic" → "Referral to other clinic"
- **Disease-to-generic**: "Gonococcal urethral abscess" → "Urethral abscess unspecified"
- **Abortion complications**: "Abortion with electrolyte imbalance" → "Electrolyte imbalance NOS"
- **Cross-disease**: "Maternal gonorrhea" → "Maternal malaria"

All 63 cleared from the mapping table.

---

## Phase 7: Manual  Review

After automated QA, a guided line-by-line review of all remaining mapped Read V2 codes was carried out to catch errors that rule-based scripts cannot detect, particularly where TOKEN_OVERLAP matched on shared structural words while the clinical meaning diverged.

### Round 3: Targeted Code Review

Initial spot-checking identified **6 incorrect mappings** removed individually:

| ReadV2 | SNOMED Term | ReadV2 Term | Problem |
|---|---|---|---|
| 43aO. | Treponema pallidum antibody | Anticardiolipin antibody | Different antibody entirely |
| 43ec. | Psittacosis LGV | Psittacosis | LGV (lymphogranuloma venereum) is a distinct STI; psittacosis is a respiratory infection from birds |
| F5914 | Syphilitic deafness | Deafness unspecified | Generic, lost the syphilitic qualifier |
| K409. | Acute on chronic pelvic inflammatory disease | Acute parametritis and pelvic cellulitis | Different clinical entity (acute-on-chronic vs acute) |
| L0621 | Unspecified illegal abortion | Complete illegal abortion with genital infection | Incomplete vs complete - different stage |
| PK03. | Syphilitic splenomegaly | Congenital splenomegaly | Generic, lost the syphilitic qualifier |

### Round 4: Comprehensive Review

All **841 remaining mapped Read V2 codes** (post-Round 3) were reviewed across all four category tables. This identified **15 further incorrect mappings** (25 database rows, since multiple SNOMED concepts can map to the same Read V2 code):

| ReadV2 | SNOMED Term | ReadV2 Term | Problem |
|---|---|---|---|
| 43mJ. | HIV2 antibody level | Yo antibody level | Yo is a paraneoplastic antibody, completely unrelated to HIV |
| 7N402 | Syphilis of tricuspid valve | [SO]Tricuspid valve | [SO] = Site of Operation - just an anatomy code, not a disease |
| 6812. | Syphilis screening offered | Screening offered | Generic screening, not syphilis-specific |
| 8IH3. | Gonorrhoea screening declined | Screening declined | Generic screening, not gonorrhoea-specific |
| Ayu8F | Gonococcal infection of the CNS | [X]Unspecified viral infection/CNS | Gonococcal is bacterial; matched to a viral CNS infection |
| n4z.. | Human papillomavirus (organism) | HUMAN PAPILLOMAVIRUS VACCINE | Organism vs vaccine - different concept types |
| P2xz1 | Late congenital syphilitic optic atrophy | Congenital optic atrophy | Generic, lost the syphilitic qualifier |
| PB6y1 | Congenital syphilitic hepatomegaly | Congenital hepatomegaly | Generic, lost the syphilitic qualifier |
| K242. | Chlamydial epididymo-orchitis | Epididymo-orchitis | Generic, lost the chlamydial qualifier |
| L0910 | Oliguria following abortive pregnancy | Afibrinogenaemia following abortive pregnancy | Different complication (urine vs clotting) - matched on "following abortive pregnancy" |
| 7G094 | Painting of perineal warts | Painting of warts NEC | NEC is broader but "perineal" qualifier lost |
| 7G097 | Cryotherapy of vulval wart | Cryotherapy to wart | Generic wart treatment, lost "vulval" qualifier |
| K1801 | Urethral stricture due to gonococcal infection | Urethral stricture due to infection EC | EC is broader, lost the gonococcal specifier |
| L431z | Abortion with amniotic fluid embolism | Amniotic fluid pulmonary embolism NOS | The SNOMED term is abortion-specific; the Read V2 term is a general embolism |
| Ayu3V | Genital mycoplasma infection | [X]Mycoplasma infection, unspecified | Same organism but lost the genital qualifier |

### Error Patterns Identified

Across all manual QA rounds, the errors fell into recurring categories:

1. **Lost disease qualifier** (most common) - The TOKEN_OVERLAP algorithm matched on shared anatomical or procedural words while dropping the critical disease specifier (syphilitic, gonococcal, chlamydial).
2. **Generic fallback** - A disease-specific screening, procedure or anatomy code matched to a generic equivalent (e.g. "Syphilis screening offered" → "Screening offered").
3. **Cross-domain mismatch** - Terms sharing structural words but from different clinical domains (HIV antibody → paraneoplastic antibody, bacterial infection → viral infection).
4. **Concept type mismatch** - Organism matched to vaccine, or disease matched to anatomical site code.

### Cumulative QA Summary

| QA Step | Mappings Removed |
|---|---|
| Automated: Negation contradictions | 30 |
| Automated: Category relevance | 63 |
| Manual: Targeted code review | 6 |
| Manual: Comprehensive review | 25 |
| **Total removed** | **124** |

---

## Final State

| Source | Match Level | Count |
|---|---|---|
| DMWB | DMWB_CROSSMAP | 601 |
| SEMANTIC | EXACT | 295 |
| SEMANTIC | NORMALISED | 24 |
| SEMANTIC | TOKEN_OVERLAP | 300 |
| **Mapped** | | **1,220** |
| Unmapped | | 1,614 |
| **Total** | | **2,834** |

### Unique Read V2 Codes

The `RCGPExclusion.sql` query uses a `ROW_NUMBER()` CTE to deduplicate by `ReadV2Code`, preferring DMWB mappings over SEMANTIC, and higher scores within SEMANTIC. This yields **819 unique Read V2 codes** after all QA rounds:

| Category | Unique Read V2 Codes |
|---|---|
| Assisted Fertilisation | 47 |
| Gender Related Issues | 30 |
| Sexually Transmitted Disease | 579 |
| Termination of Pregnancy | 163 |
| **Total (deduplicated)** | **819** |

---

## Scripts Reference

All Python scripts are in `Readv2/Scripts/`, data files in `Readv2/Data/`.

| Script | Purpose |
|---|---|
| `Readv2/Scripts/Import-Readv2ToSqlServer.py` | Import 14 DBF tables into READv2 database (CS_AS collation) |
| `Readv2/Scripts/Import-Readv2CsvToSqlServer.py` | Import Readv2Lookup flat table |
| `Readv2/Scripts/Import-AlbasoftToSqlServer.py` | Import Albasoft sensitive code list |
| `Readv2/Scripts/_import_exclusions.py` | Import DataSharingExclusions.xlsx → SQL table |
| `Readv2/Scripts/_match_unmapped.py` | Three-tier semantic matching engine |
| `Readv2/Scripts/_update_mapping_source.py` | Add provenance columns (MappingSource, MatchLevel, MatchScore) |
| `Readv2/Scripts/_find_contradictions.py` | Detect negation/semantic mismatches |
| `Readv2/Scripts/_remove_contradictions.py` | Clear contradictory mappings (30 rows) |
| `Readv2/Scripts/_find_unrelated.py` | Detect category-irrelevant matches |
| `Readv2/Scripts/_remove_unrelated.py` | Clear unrelated matches (63 rows) |
| `Export-DataSharingExclusions.ps1` | Export SNOMED exclusion refsets to Excel with Read V2 terms |
| `Queries/RCGPExclusion.sql` | Creates and populates `RCGPSNOMEDtoREADv2` table |
| `Queries/AnalyseRCGPvsAlbasoft.sql` | Full RCGP vs Albasoft comparison analysis |
| `Queries/CreateSensitiveCodeListCombined.sql` | Creates unified `SensitiveCodeListCombined` table |

---

## Key Lessons

1. **Collation matters.** Read V2 is case-sensitive by design; using a CI collation silently corrupts lookups.
2. **Official crossmaps have gaps.** DMWB only covered 601/2,834 (21%) of the exclusion concepts.
3. **Token overlap is powerful but noisy.** Jaccard similarity catches genuine matches but also matches generic terms that share structural words with disease-specific terms. Of 416 initial TOKEN_OVERLAP matches, 124 (30%) were removed during QA.
4. **Layered QA is essential.** Automated checks (negation detection, category relevance) catch systematic errors, but manual expert review is needed to catch clinical nuances - particularly lost disease qualifiers and cross-domain mismatches that share high lexical overlap.
5. **Provenance columns pay for themselves.** Being able to filter by `MappingSource` and `MatchLevel` lets consumers choose their confidence threshold.
6. **Manual review scales poorly but catches what automation misses.** The 21 codes removed by manual review included patterns (organism vs vaccine, bacterial vs viral, disease vs anatomy code) that would require domain-specific ontological rules to detect automatically.

---

## Appendix: Final Mapped Read V2 Codes

**819 unique Read V2 codes** after deduplication (DMWB preferred over SEMANTIC, highest score wins).

### Assisted Fertilisation (47 codes)

| SNOMED ConceptID | SNOMED Preferred Term | ReadV2Code | ReadV2 Term | MappingSource | MatchLevel | MatchScore |
|---|---|---|---|---|---|---|
| 765291000000105 | History of in-vitro fertilisation | 14e.. | History of in-vitro fertilisation | DMWB | DMWB_CROSSMAP | 1.000 |
| 312645003 | Percutaneous epididymal sperm aspiration | 7C263 | Percutaneous epididymal sperm aspiration | DMWB | DMWB_CROSSMAP | 1.000 |
| 236364009 | Micro-epididymal sperm aspiration | 7C264 | Micro-epididymal sperm aspiration | DMWB | DMWB_CROSSMAP | 1.000 |
| 229971000000102 | Testicular sperm extraction | 7C265 | Testicular sperm extraction | DMWB | DMWB_CROSSMAP | 1.000 |
| 177038005 | Endoscopic transurethral ultrasound directed oocyte recovery | 7E240 | Endoscopic transurethral ultrasound directed oocyte recovery | DMWB | DMWB_CROSSMAP | 1.000 |
| 177039002 | Endoscopic transvesical oocyte recovery | 7E241 | Endoscopic transvesical oocyte recovery | DMWB | DMWB_CROSSMAP | 1.000 |
| 265082003 | Laparoscopic oocyte recovery | 7E242 | Laparoscopic oocyte recovery | DMWB | DMWB_CROSSMAP | 1.000 |
| 177042008 | Transvaginal oocyte recovery | 7E243 | Transvaginal oocyte recovery | DMWB | DMWB_CROSSMAP | 1.000 |
| 176843009 | Gamete intrauterine transfer | 7E0A. | Introduction of gamete into uterine cavity | DMWB | DMWB_CROSSMAP | 1.000 |
| 75456002 | Embryo transfer | 7E0A0 | Implantation of fertilised egg into uterus | DMWB | DMWB_CROSSMAP | 1.000 |
| 176844003 | Intracervical artificial insemination | 7E0A1 | Intracervical artificial insemination | DMWB | DMWB_CROSSMAP | 1.000 |
| 265064001 | Intrauterine artificial insemination | 7E0A2 | Intrauterine artificial insemination | DMWB | DMWB_CROSSMAP | 1.000 |
| 426968007 | Intrauterine insemination with superovulation using partner sperm | 7E0A3 | Intrauterine insemination superovulation partner sperm | DMWB | DMWB_CROSSMAP | 1.000 |
| 425644009 | Intrauterine insemination with superovulation using donor sperm | 7E0A4 | Intrauterine insemination superovulation using donor sperm | DMWB | DMWB_CROSSMAP | 1.000 |
| 426389008 | Intrauterine insemination without superovulation using partner sperm | 7E0A5 | Intrauterine insemination without superovulat partner sperm | DMWB | DMWB_CROSSMAP | 1.000 |
| 426250000 | Intrauterine insemination without superovulation using donor sperm | 7E0A6 | Intrauterine insemination without superovulation donor sperm | DMWB | DMWB_CROSSMAP | 1.000 |
| 233111000000108 | Transfer of embryo to uterus | 7E0A7 | Transfer of embryo to uterus | DMWB | DMWB_CROSSMAP | 1.000 |
| 448543003 | Transmyometrial transfer of embryo to uterus | 7E0J0 | Transmyometrial transfer of embryo to uterus | DMWB | DMWB_CROSSMAP | 1.000 |
| 176996001 | Endoscopic intrafallopian transfer of gamete | 7E1F2 | Endoscopic intrafallopian transfer of gamete | DMWB | DMWB_CROSSMAP | 1.000 |
| 177037000 | Oocyte recovery | 7E24. | Oocyte recovery | DMWB | DMWB_CROSSMAP | 1.000 |
| 52637005 | In vitro fertilisation procedure | 7M0h. | In vitro fertilisation (IVF) | DMWB | DMWB_CROSSMAP | 1.000 |
| 427664000 | IVF - In vitro fertilisation using donor sperm | 7M0h0 | IVF with donor sperm | DMWB | DMWB_CROSSMAP | 1.000 |
| 425866000 | In vitro fertilization using donor eggs | 7M0h1 | IVF with donor eggs | DMWB | DMWB_CROSSMAP | 1.000 |
| 425901007 | IVF - In vitro fertilisation with intracytoplasmic sperm injection (ICSI) | 7M0h2 | IVF with intracytoplasmic sperm injection (ICSI) | DMWB | DMWB_CROSSMAP | 1.000 |
| 426914002 | IVF - In vitro fertilisation with intracytoplasmic sperm injection (ICSI) and donor egg | 7M0h3 | IVF intracytoplasmic sperm injection (ICSI) and donor egg | DMWB | DMWB_CROSSMAP | 1.000 |
| 426417003 | IVF - In vitro fertilisation with pre-implantation genetic diagnosis | 7M0h4 | IVF with pre-implantation for genetic diagnosis | DMWB | DMWB_CROSSMAP | 1.000 |
| 711544002 | IVF (in vitro fertilisation) with surrogacy | 7M0h5 | IVF with surrogacy | DMWB | DMWB_CROSSMAP | 1.000 |
| 268771000000104 | Other specified in vitro fertilisation (IVF) | 7M0hy | Other specified in vitro fertilisation (IVF) | SEMANTIC | EXACT | 1.000 |
| 268781000000102 | In vitro fertilisation (IVF) NOS | 7M0hz | In vitro fertilisation (IVF) NOS | SEMANTIC | EXACT | 1.000 |
| 65046005 | Infertility therapy | 8C8.. | Treatment for infertility | DMWB | DMWB_CROSSMAP | 1.000 |
| 58533008 | AI - Artificial insemination | 8C81. | Artificial insemination | DMWB | DMWB_CROSSMAP | 1.000 |
| 183036001 | Female infertility therapy | 8C82. | Female infertility therapy | DMWB | DMWB_CROSSMAP | 1.000 |
| 183037005 | Male infertility therapy | 8C83. | Male infertility therapy | DMWB | DMWB_CROSSMAP | 1.000 |
| 268701000000107 | In vitro fertilisation procedure | 8C84. | In vitro fertilisation procedure | SEMANTIC | EXACT | 1.000 |
| 236912008 | GIFT - Gamete intrafallopian transfer | 8C85. | Gamete intrafallopian transfer | DMWB | DMWB_CROSSMAP | 1.000 |
| 213199004 | Complications associated with artificial fertilization | Kyu9H | [X]Other complicatns associated wth artificial fertilization | DMWB | DMWB_CROSSMAP | 1.000 |
| 198598005 | [X]Other complications associated with artificial fertilization | SP0D. | Complications associated with artificial fertilization | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 213200001 | Infection associated with artificial insemination | SP0D0 | Infection associated with artificial insemination | DMWB | DMWB_CROSSMAP | 1.000 |
| 213201002 | Hyperstimulation of ovaries | SP0D1 | Hyperstimulation of ovaries | DMWB | DMWB_CROSSMAP | 1.000 |
| 213202009 | Complications of attempted introduction of fertilised ovum following in vitro fertilisation | SP0D2 | Compltns of attemptd intro fertil ovum follow in vitro fert | DMWB | DMWB_CROSSMAP | 1.000 |
| 213203004 | Complications of attempted introduction of embryo in embryo transfer | SP0D3 | Complctns/attemptd introduction of embryo in embryo transfer | DMWB | DMWB_CROSSMAP | 1.000 |
| 427961000000100 | [V]AI - artificial insemination | ZV261 | [V]Artificial insemination NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 236895005 | Artificial insemination by husband | ZV265 | [V]Artificial insemination from husband | DMWB | DMWB_CROSSMAP | 1.000 |
| 236896006 | DI - Donor insemination | ZV266 | [V]Artificial insemination from donor | DMWB | DMWB_CROSSMAP | 1.000 |
| 440691000000100 | [V] IVF | ZV267 | [V]In vitro fertilization | DMWB | DMWB_CROSSMAP | 1.000 |
| 411101000000103 | [V]Other assisted fertilisation methods | ZV268 | [V]Other assisted fertilization methods | DMWB | DMWB_CROSSMAP | 1.000 |
| 391241000000101 | [X]Other assisted fertilisation methods | ZVu21 | [X]Other assisted fertilization methods | DMWB | DMWB_CROSSMAP | 1.000 |

### Gender Related Issues (30 codes)

| SNOMED ConceptID | SNOMED Preferred Term | ReadV2Code | ReadV2 Term | MappingSource | MatchLevel | MatchScore |
|---|---|---|---|---|---|---|
| 282272009 | Gender reassignment patient | 1K4.. | Gender reassignment patient | DMWB | DMWB_CROSSMAP | 1.000 |
| 176532008 | Construction of penis | 7C220 | Construction of penis | DMWB | DMWB_CROSSMAP | 1.000 |
| 176687003 | Colpoplasty | 7D16. | Plastic operations on vagina | DMWB | DMWB_CROSSMAP | 1.000 |
| 265619004 | Colpopoiesis | 7D160 | Construction of vagina | DMWB | DMWB_CROSSMAP | 1.000 |
| 176691008 | McIndoe vaginoplasty | 7D163 | Reconstruction of vagina with skin graft | DMWB | DMWB_CROSSMAP | 1.000 |
| 719670005 | Sex reassignment surgery | 7L0B. | Operations for sexual transformation | DMWB | DMWB_CROSSMAP | 1.000 |
| 51427007 | Combined operation for transformation from male to female | 7L0B0 | Combined operations for transformation from male to female | DMWB | DMWB_CROSSMAP | 1.000 |
| 42775008 | Combined operation for transformation from female to male | 7L0B1 | Combined operations for transformation from female to male | DMWB | DMWB_CROSSMAP | 1.000 |
| 441524006 | Construction of scrotum | 7L0B3 | Construction of scrotum | DMWB | DMWB_CROSSMAP | 1.000 |
| 24878005 | Gender assignment surgery | 7L0By | Other specified operation for sexual transformation | DMWB | DMWB_CROSSMAP | 1.000 |
| 149785007 | Operation for sexual transformation NOS | 7L0Bz | Operation for sexual transformation NOS | SEMANTIC | EXACT | 1.000 |
| 472948001 | Cross-dressing | E223. | Transvestism | DMWB | DMWB_CROSSMAP | 1.000 |
| 407374003 | Transsexual | E225. | Trans-sexualism | DMWB | DMWB_CROSSMAP | 1.000 |
| 472945003 | Previously asexual transsexual | E2251 | Trans-sexuality with asexual history | DMWB | DMWB_CROSSMAP | 1.000 |
| 472947006 | Previously homosexual transsexual | E2252 | Trans-sexuality with homosexual history | DMWB | DMWB_CROSSMAP | 1.000 |
| 472946002 | Previously heterosexual transsexual | E2253 | Trans-sexuality with heterosexual history | DMWB | DMWB_CROSSMAP | 1.000 |
| 191787001 | Psychosexual identity disorder | E226. | Psychosexual identity disorder | DMWB | DMWB_CROSSMAP | 1.000 |
| 191790007 | Psychosexual identity disorder NOS | E226z | Psychosexual identity disorder NOS | SEMANTIC | EXACT | 1.000 |
| 191798000 | Gender role disorder of adolescent or adult | E22y4 | Gender role disorder of adolescent or adult | DMWB | DMWB_CROSSMAP | 1.000 |
| 87991007 | Gender identity disorder | Eu64. | [X]Gender identity disorders | DMWB | DMWB_CROSSMAP | 1.000 |
| 192508005 | Transsexualism | Eu640 | [X]Transsexualism | SEMANTIC | NORMALISED | .950 |
| 472989003 | Dual-role transvestism | Eu641 | [X]Dual-role transvestism | DMWB | DMWB_CROSSMAP | 1.000 |
| 5095008 | Gender identity disorder of childhood | Eu642 | [X]Gender identity disorder of childhood | DMWB | DMWB_CROSSMAP | 1.000 |
| 192507000 | [X]Gender identity disorders | Eu64y | [X]Other gender identity disorders | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 412321000000104 | [X]Gender identity disorder, unspecified | Eu64z | [X]Gender identity disorder, unspecified | SEMANTIC | EXACT | 1.000 |
| 472981000 | Fetishistic transvestism | Eu651 | [X]Fetishistic transvestism | DMWB | DMWB_CROSSMAP | 1.000 |
| 268229003 | Indeterminate sex and pseudohermaphroditism | PC7.. | Indeterminate sex and pseudohermaphroditism | DMWB | DMWB_CROSSMAP | 1.000 |
| 111332007 | Male pseudohermaphroditism | PC71. | Male pseudohermaphroditism | DMWB | DMWB_CROSSMAP | 1.000 |
| 8800006 | Female pseudohermaphroditism | PC72. | Female pseudohermaphroditism | DMWB | DMWB_CROSSMAP | 1.000 |
| 93461009 | Gender dysphoria | ZV62A | [V] Gender dysphoria | DMWB | DMWB_CROSSMAP | 1.000 |

### Sexually Transmitted Disease (577 codes)

| SNOMED ConceptID | SNOMED Preferred Term | ReadV2Code | ReadV2 Term | MappingSource | MatchLevel | MatchScore |
|---|---|---|---|---|---|---|
| 160281003 | FH: Syphilis | 1232 | FH: Syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 137684006 | FH: Syphilis | 1232. | FH: Syphilis | SEMANTIC | EXACT | 1.000 |
| 160282005 | FH: Gonorrhea | 1233 | FH: Gonorrhoea | DMWB | DMWB_CROSSMAP | 1.000 |
| 137685007 | FH: Gonorrhoea | 1233. | FH: Gonorrhoea | SEMANTIC | EXACT | 1.000 |
| 266974005 | Human immunodeficiency virus (HIV) risk lifestyle | 13N5. | HIV risk lifestyle | DMWB | DMWB_CROSSMAP | 1.000 |
| 200631000000105 | Sexual contact with high risk partner | 13N9. | Sexual contact with high risk partner | DMWB | DMWB_CROSSMAP | 1.000 |
| 275881005 | H/O sexually transmitted infection | 1415 | H/O: venereal disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 138691006 | H/O: venereal disease | 1415. | H/O: venereal disease | SEMANTIC | EXACT | 1.000 |
| 472954000 | History of chlamydial infection | 14150 | H/O: chlamydia infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 764281000000109 | H/O: gonorrhoea | 14151 | H/O: gonorrhoea | DMWB | DMWB_CROSSMAP | 1.000 |
| 872251000000104 | H/O: genital warts | 14152 | H/O: genital warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 872271000000108 | H/O: genital herpes | 14153 | H/O: genital herpes | DMWB | DMWB_CROSSMAP | 1.000 |
| 829691000000100 | H/O hepatitis C antiviral drug therapy | 14i.. | H/O hepatitis C antiviral drug therapy | DMWB | DMWB_CROSSMAP | 1.000 |
| 407560009 | At risk of sexually transmitted infection | 14OP. | At risk of sexually transmitted infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 702479006 | At high risk of sexually transmitted infection | 14OP0 | At high risk of sexually transmitted infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 702480009 | At low risk of sexually transmitted infection | 14OP1 | At low risk of sexually transmitted infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 164029004 | O/E - Argyll Robertson pupils | 2BG3. | O/E - Argyll Robertson pupils | DMWB | DMWB_CROSSMAP | 1.000 |
| 164811005 | Special female test normal | 3183 | Special female test normal | DMWB | DMWB_CROSSMAP | 1.000 |
| 164826007 | Special male test abnormal | 3194 | Special male test abnormal | DMWB | DMWB_CROSSMAP | 1.000 |
| 1015571000000106 | TPI (syphilis) test | 438.. | Syphilis infectious titre test | DMWB | DMWB_CROSSMAP | 1.000 |
| 165780000 | Syphilis titre test negative | 4381 | Syphilis titre test negative | DMWB | DMWB_CROSSMAP | 1.000 |
| 165781001 | Syphilis titer test positive | 4382 | Syphilis titre test positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 143187000 | Syphilis titre test positive | 4382. | Syphilis titre test positive | SEMANTIC | EXACT | 1.000 |
| 1028721000000102 | Wassermann reaction | 4383 | Wassermann's test (W.R.) | DMWB | DMWB_CROSSMAP | 1.000 |
| 165782008 | Wassermann's test | 4383. | Wassermann's test (W.R.) | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 1015581000000108 | VDRL (Venereal Disease Research Laboratory) test | 4384 | V.D.R.L. test | DMWB | DMWB_CROSSMAP | 1.000 |
| 252407006 | TPI - Treponema pallidum immobilisation test | 4385 | T.P.I test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1015591000000105 | Fluorescent treponemal antibody test | 4386 | Fluorescent treponemal antibody test | DMWB | DMWB_CROSSMAP | 1.000 |
| 9232009 | FTA(Abs) - Fluorescent treponemal antibody test | 4386. | Fluorescent treponemal antibody test | SEMANTIC | TOKEN_OVERLAP | .667 |
| 1015601000000104 | Treponema pallidum haemagglutination test | 4387 | Treponema pallidum haemaglutination test | DMWB | DMWB_CROSSMAP | 1.000 |
| 991941000000103 | Treponema pallidum particle inhibition test | 4388 | Treponema pallidum particle inhibition test | DMWB | DMWB_CROSSMAP | 1.000 |
| 401262008 | Treponema pallidum particle agglutination test | 4388. | Treponema pallidum particle inhibition test | SEMANTIC | TOKEN_OVERLAP | .667 |
| 991951000000100 | Syphilis serology | 4389 | Syphilis serology | DMWB | DMWB_CROSSMAP | 1.000 |
| 165787002 | Syphilis serology | 4389. | Syphilis serology | SEMANTIC | EXACT | 1.000 |
| 390879000 | Treponema pallidum ELISA negative | 438A. | Treponema pallidum ELISA negative | DMWB | DMWB_CROSSMAP | 1.000 |
| 390880002 | Treponema pallidum ELISA positive | 438B. | Treponema pallidum ELISA positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 992931000000104 | Treponema pallidum particle agglutination test | 438C. | Treponema pallidum particle agglutination test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1005361000000109 | Treponema pallidum gelatin agglutination test | 438D. | Treponema pallidum gelatin agglutination test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1018861000000106 | Total Treponema antibody level | 438E. | Total treponema antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1002021000000108 | Treponema pallidum total antibodies measurement | 438F. | Treponema pallidum total antibodies measurement | DMWB | DMWB_CROSSMAP | 1.000 |
| 269828009 | Syphilis infectious titre test | 438Z. | Syphilis titre test NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 165803005 | Blood sent: SH-antigen test | 43B1. | Blood sent: SH-antigen test | DMWB | DMWB_CROSSMAP | 1.000 |
| 46898007 | Serologic test for herpes simplex | 43bS. | Serologic test for herpes simplex | DMWB | DMWB_CROSSMAP | 1.000 |
| 1027831000000105 | Human immunodeficiency virus test | 43C.. | HTLV-3 antibody test | DMWB | DMWB_CROSSMAP | 1.000 |
| 165814008 | Blood sent for HTLV-3 serology | 43C1. | Blood sent for HTLV-3 serology | DMWB | DMWB_CROSSMAP | 1.000 |
| 165815009 | HIV negative | 43C2. | HTLV-3 antibody negative | DMWB | DMWB_CROSSMAP | 1.000 |
| 165816005 | HIV positive | 43C3. | HTLV-3 antibody positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 248981000000107 | Human immunodeficiency virus test equivocal | 43C4. | Human immunodeficiency virus test equivocal | DMWB | DMWB_CROSSMAP | 1.000 |
| 250514000 | Human immunodeficiency virus antibody titre measurement | 43CZ. | HTLV-3 antibody NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 1014171000000103 | HIV (human immunodeficiency virus) antibody/antigen (Duo) | 43d5. | HIV antibody/antigen (Duo) | DMWB | DMWB_CROSSMAP | 1.000 |
| 1014181000000101 | HTLV 1 (human T-lymphotropic virus 1) antibody level | 43d6. | HTLV 1 antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 998861000000101 | HTLV 2 (human T-lymphotropic virus 2) antibody level | 43dc. | HTLV 2 antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1005081000000102 | Herpes simplex IgM level | 43de. | Herpes simplex IgM level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1014251000000101 | Herpes simplex antibody level | 43dE. | Herpes simplex antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1013481000000106 | Herpes simplex IgG level | 43dm. | Herpes simplex IgG level | DMWB | DMWB_CROSSMAP | 1.000 |
| 992041000000109 | Gonorrhoea titre test | 43E6. | Gonorrhoea infect. titre test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1023351000000100 | Chlamydia trachomatis L2 antibody level | 43eC. | Chlamydia trachomatis L2 antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1023371000000109 | Chlamydia antibody level | 43eE. | Chlamydia antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1029021000000105 | Syphilis IgG level | 43ef. | Syphilis IgG level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1031371000000108 | Chlamydia group CFT (complement fixation test) | 43eF. | Chlamydia group complement fixation test | DMWB | DMWB_CROSSMAP | 1.000 |
| 992711000000105 | Treponema pallidum IgG level | 43eh. | Treponema pallidum IgG level | DMWB | DMWB_CROSSMAP | 1.000 |
| 992721000000104 | Treponema pallidum IgM level | 43ei. | Treponema pallidum IgM level | DMWB | DMWB_CROSSMAP | 1.000 |
| 995221000000102 | VDRL (Venereal Disease Research Laboratory) titre | 43ej. | VDRL titre | DMWB | DMWB_CROSSMAP | 1.000 |
| 1023411000000108 | Chlamydia trachomatis IgG level | 43eJ. | Chlamydia trachomatis IgG level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1028971000000100 | Fluorescent treponemal antibody absorption IgG level | 43eO. | Fluorescent treponemal antibody absorption IgG level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1028981000000103 | Fluorescent treponemal antibody absorption IgM level | 43eP. | Fluorescent treponemal antibody absorption IgM level | DMWB | DMWB_CROSSMAP | 1.000 |
| 999001000000101 | Chlamydia trachomatis IgM level | 43ez. | Chlamydia trachomatis IgM level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1026621000000109 | Chlamydia trachomatis PCR | 43h0. | Chlamydia trachomatis polymerase chain reaction | DMWB | DMWB_CROSSMAP | 1.000 |
| 1026641000000102 | HIV (human immunodeficiency virus) 1 PCR (polymerase chain reaction) | 43h2. | HIV 1 PCR | DMWB | DMWB_CROSSMAP | 1.000 |
| 1026651000000104 | Herpes simplex polymerase chain reaction | 43h4. | Herpes simplex polymerase chain reaction | DMWB | DMWB_CROSSMAP | 1.000 |
| 1026661000000101 | Neisseria gonorrhoeae polymerase chain reaction | 43h6. | Neisseria gonorrhoeae polymerase chain reaction | DMWB | DMWB_CROSSMAP | 1.000 |
| 1030231000000108 | Human immunodeficiency virus proviral deoxyribonucleic acid polymerase chain reaction | 43h9. | HIV proviral deoxyribonucleic acid polymerase chain reaction | DMWB | DMWB_CROSSMAP | 1.000 |
| 998611000000102 | Chlamydia trachomatis nucleic acid detection assay | 43j1. | Chlamydia trachomatis nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1000261000000105 | Chlamydia trachomatis (lymphogranuloma venereum serovar) deoxyribonucleic acid detection | 43j10 | Chlamydia trachomatis (LGV serovar) DNA detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 817771000000106 | Chlamydia trachomatis detection by nucleic acid amplification test | 43j11 | Chlamydia trachomatis detection by NAAT | DMWB | DMWB_CROSSMAP | 1.000 |
| 1030521000000108 | Herpes simplex nucleic acid detection assay | 43j6. | Herpes simplex nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008421000000104 | Herpes simplex DNA (deoxyribonucleic acid) detection assay | 43j61 | Herpes simplex deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008351000000102 | HIV (human immunodeficiency virus) 1 ribonucleic acid detection assay | 43j7. | HIV 1 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 907191000000100 | HIV 1 nucleic acid detection assay | 43j70 | HIV 1 nucleic acid detection assay | SEMANTIC | EXACT | 1.000 |
| 1008361000000104 | HIV (human immunodeficiency virus) 1 provirus DNA (deoxyribonucleic acid) detection assay | 43j71 | HIV 1 provirus deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 934551000000101 | HIV 1 ribonucleic acid detection assay | 43j72 | HIV 1 ribonucleic acid detection assay | SEMANTIC | EXACT | 1.000 |
| 1008331000000109 | HTLV 1 (human T-lymphotropic virus 1) RNA (ribonucleic acid) detection assay | 43j8. | HTLV 1 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008341000000100 | HTLV 1 (human T-lymphotropic virus 1) provirus DNA (deoxyribonucleic acid) detection assay | 43j81 | HTLV 1 provirus deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 998651000000103 | Neisseria gonorrhoeae nucleic acid detection assay | 43jA. | Neisseria gonorrhoeae nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 907521000000109 | Neisseria gonorrhoeae nucleic acid detection assay | 43jA0 | Neisseria gonorrhoeae nucleic acid detection assay | SEMANTIC | EXACT | 1.000 |
| 1008311000000101 | HTLV 2 (human T-lymphotropic virus 2) RNA (ribonucleic acid) detection assay | 43jE. | HTLV 2 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008321000000107 | HTLV 2 (human T-lymphotropic virus 2) provirus DNA (deoxyribonucleic acid) detection assay | 43jE1 | HTLV 2 provirus deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1002681000000104 | Chlamydia deoxyribonucleic acid detection | 43jK. | Chlamydia deoxyribonucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008291000000102 | HTLV (human T-lymphotropic virus) RNA (ribonucleic acid) detection assay | 43jr. | Human T-lymphotropic virus nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008301000000103 | HTLV (human T-lymphotropic virus) provirus DNA (deoxyribonucleic acid) detection assay | 43jr1 | HTLV provirus deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1029701000000104 | Human herpes virus 6 nucleic acid detection assay | 43jt. | Human herpes virus 6 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008391000000105 | Human herpesvirus 6 DNA (deoxyribonucleic acid) detection assay | 43jt1 | Human herpesvirus 6 deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1029711000000102 | Human herpes virus 7 nucleic acid detection assay | 43ju. | Human herpes virus 7 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008381000000108 | Human herpesvirus 7 DNA (deoxyribonucleic acid) detection assay | 43ju1 | Human herpesvirus 7 deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1029721000000108 | Human herpes virus 8 nucleic acid detection assay | 43jv. | Human herpes virus 8 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008371000000106 | Human herpesvirus 8 DNA (deoxyribonucleic acid) detection assay | 43jv1 | Human herpesvirus 8 deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1029511000000109 | Human papilloma virus nucleic acid detection assay | 43jY. | Human papilloma virus nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008271000000101 | Human papilloma virus deoxyribonucleic acid detection assay | 43jY1 | Human papilloma virus deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1011651000000101 | Chlamydia trachomatis IgA level | 43n9. | Chlamydia trachomatis IgA level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1031431000000104 | Chlamydia antigen test | 43U.. | Chlamydia antigen test | DMWB | DMWB_CROSSMAP | 1.000 |
| 310862001 | Chlamydia antigen by enzyme-linked immunosorbent assay | 43U0. | Chlamydia antigen by ELISA | DMWB | DMWB_CROSSMAP | 1.000 |
| 314527009 | Chlamydia antigen enzyme-linked immunosorbent assay positive | 43U1. | Chlamydia antigen ELISA positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 314526000 | Chlamydia antigen enzyme-linked immunosorbent assay negative | 43U2. | Chlamydia antigen ELISA negative | DMWB | DMWB_CROSSMAP | 1.000 |
| 1005381000000100 | Chlamydia trachomatis antigen test | 43U3. | Chlamydia trachomatis antigen test | DMWB | DMWB_CROSSMAP | 1.000 |
| 413079006 | Chlamydia PCR positive | 43U4. | Chlamydia PCR positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 247371000000107 | Chlamydia test equivocal | 43U7. | Chlamydia test equivocal | DMWB | DMWB_CROSSMAP | 1.000 |
| 201441000000107 | Chlamydia test positive | 43U8. | Chlamydia test positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 448374002 | Chlamydia trachomatis NAAT (nucleic acid amplification test) inhibitory | 43U9. | Chlamydia trachomatis NAAT inhibitory | DMWB | DMWB_CROSSMAP | 1.000 |
| 996081000000100 | HIV (human immunodeficiency virus) ribonucleic acid/deoxyribonucleic acid ratio | 43w3. | Human immunodeficiency virus RNA/DNA ratio | DMWB | DMWB_CROSSMAP | 1.000 |
| 1029781000000109 | Herpes simplex virus type 1 nucleic acid detection assay | 43w4. | Herpes simplex virus type 1 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008411000000105 | Herpes simplex type 1 deoxyribonucleic acid detection assay | 43w41 | Herpes simplex type 1 deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1003991000000103 | Herpes simplex virus type 2 nucleic acid detection assay | 43w5. | Herpes simplex virus type 2 nucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008401000000108 | Herpes simplex type 2 deoxyribonucleic acid detection assay | 43w51 | Herpes simplex type 2 deoxyribonucleic acid detection assay | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008801000000105 | HIV1 (human immunodeficiency virus 1) antibody level | 43W7. | HIV1 antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 1008811000000107 | HIV2 (human immunodeficiency virus 2) antibody level | 43W8. | HIV2 antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 818821000000104 | Treponema pallidum detection by nucleic acid amplification test | 43wA. | Treponema pallidum detection by NAAT | DMWB | DMWB_CROSSMAP | 1.000 |
| 1004141000000107 | Treponema pallidum deoxyribonucleic acid detection | 43wB. | Treponema pallidum deoxyribonucleic acid detection | DMWB | DMWB_CROSSMAP | 1.000 |
| 1014121000000102 | HIV (human immunodeficiency virus) antibody level | 43WK. | Human immunodeficiency virus antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 998731000000100 | Treponema pallidum reagin antibody level | 43WL. | Treponema pallidum reagin antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 998741000000109 | Chlamydia group antibody level | 43WM. | Chlamydia group antibody level | DMWB | DMWB_CROSSMAP | 1.000 |
| 415798001 | Urine chlamydia trachomatis test positive | 46H6. | Urine chlamydia trachomatis test positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 415797006 | Urine chlamydia trachomatis test negative | 46H7. | Urine chlamydia trachomatis test negative | DMWB | DMWB_CROSSMAP | 1.000 |
| 1011071000000104 | Neisseria gonorrhoeae culture | 4J2D. | Neisseria gonorrhoeae culture | DMWB | DMWB_CROSSMAP | 1.000 |
| 998701000000106 | HIV (human immunodeficiency virus) viral load | 4J34. | HIV viral load | DMWB | DMWB_CROSSMAP | 1.000 |
| 998711000000108 | HIV (human immunodeficiency virus) p24 antigen level | 4J35. | HIV p24 antigen level | DMWB | DMWB_CROSSMAP | 1.000 |
| 998721000000102 | Herpes simplex antigen (enzyme immunoassay) | 4J36. | Herpes simplex antigen (EIA) | DMWB | DMWB_CROSSMAP | 1.000 |
| 1021331000000108 | Herpes simplex virus isolation | 4J3C. | Herpes simplex virus isolation | DMWB | DMWB_CROSSMAP | 1.000 |
| 998171000000102 | Human immunodeficiency virus viral load by log rank | 4J3F. | Human immunodeficiency virus viral load by log rank | DMWB | DMWB_CROSSMAP | 1.000 |
| 1010871000000101 | HIV (human immunodeficiency virus) drug resistance test | 4J3N. | Human immunodeficiency virus drug resistance test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1007761000000101 | Human immunodeficiency virus type 1 subtype identification | 4J3P. | Human immunodeficiency virus type 1 subtype identification | DMWB | DMWB_CROSSMAP | 1.000 |
| 1007841000000109 | Human immunodeficiency virus IgG avidity | 4J3Q. | Human immunodeficiency virus IgG avidity | DMWB | DMWB_CROSSMAP | 1.000 |
| 200731000000100 | Trichomonas seen | 4J54. | Trichomonas seen | DMWB | DMWB_CROSSMAP | 1.000 |
| 200741000000109 | Trichomonas not seen | 4J55. | Trichomonas not seen | DMWB | DMWB_CROSSMAP | 1.000 |
| 996221000000106 | Human T-lymphotropic virus (1 and 2) serology | 4JDc. | Human T-lymphotropic virus (1&2) serology | DMWB | DMWB_CROSSMAP | 1.000 |
| 1009781000000101 | Chlamydia serology | 4JDM. | Chlamydia serology | DMWB | DMWB_CROSSMAP | 1.000 |
| 1009791000000104 | Human herpes virus serology | 4JDN. | Human herpes virus serology | DMWB | DMWB_CROSSMAP | 1.000 |
| 1020841000000100 | HIV (human immunodeficiency virus) serology | 4JDT. | HIV serology | DMWB | DMWB_CROSSMAP | 1.000 |
| 754591000000103 | Rapid human immunodeficiency virus antibody test | 4JDT0 | Rapid human immunodeficiency virus antibody test | DMWB | DMWB_CROSSMAP | 1.000 |
| 707982002 | Taking throat swab for Chlamydia test | 4JF42 | Throat swab for chlamydia | DMWB | DMWB_CROSSMAP | 1.000 |
| 707983007 | Taking throat swab for gonorrhea | 4JF43 | Throat swab for gonorrhoea | DMWB | DMWB_CROSSMAP | 1.000 |
| 168326009 | Anal swab culture negative | 4JH61 | Anal swab culture negative | DMWB | DMWB_CROSSMAP | 1.000 |
| 472859009 | Taking anal swab for Chlamydia test | 4JH63 | Anal swab for chlamydia | DMWB | DMWB_CROSSMAP | 1.000 |
| 472860004 | Taking anal swab for gonorrhea | 4JH64 | Anal swab for gonorrhoea | DMWB | DMWB_CROSSMAP | 1.000 |
| 168343007 | Urethral swab culture positive | 4JK10 | Urethral swab culture positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 168348003 | HVS culture - trichomonas vaginalis | 4JK22 | HVS culture - trichomonas vaginalis | DMWB | DMWB_CROSSMAP | 1.000 |
| 168359007 | Penile swab taken | 4JK8. | Penile swab taken | DMWB | DMWB_CROSSMAP | 1.000 |
| 168361003 | Penile swab culture positive | 4JK80 | Penile swab culture positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 390784004 | Taking endocervical swab for Chlamydia test | 4JK9. | Endocervical chlamydia swab | DMWB | DMWB_CROSSMAP | 1.000 |
| 390785003 | Taking urethral swab for Chlamydia test | 4JKA. | Urethral chlamydia swab | DMWB | DMWB_CROSSMAP | 1.000 |
| 400993006 | Taking cervical swab for Neisseria gonorrhoeae test | 4JKB. | Gonococcal cervical swab | DMWB | DMWB_CROSSMAP | 1.000 |
| 401002001 | Taking urethral swab for Neisseria gonorrhoeae test | 4JKC. | Gonococcal urethral swab | DMWB | DMWB_CROSSMAP | 1.000 |
| 200761000000105 | LVS (low vaginal swab) for chlamydia taken by patient | 4JKD. | Low vaginal swab for chlamydia taken by patient | DMWB | DMWB_CROSSMAP | 1.000 |
| 400994000 | Taking swab for Neisseria gonorrhoeae test | 4JLA. | Gonococcal swab | DMWB | DMWB_CROSSMAP | 1.000 |
| 285586000 | Taking swab for Chlamydia test | 4JLC. | Chlamydia swab | DMWB | DMWB_CROSSMAP | 1.000 |
| 247401000000109 | Gonorrhoea test equivocal | 4JQ9. | Gonorrhoea test equivocal | DMWB | DMWB_CROSSMAP | 1.000 |
| 247411000000106 | Gonorrhoea test positive | 4JQA. | Gonorrhoea test positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 993791000000109 | Treponema screening test | 4JR4. | Treponema screening test | DMWB | DMWB_CROSSMAP | 1.000 |
| 992781000000103 | HIV (human immunodeficiency virus) screening test | 4JR7. | HIV screening test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1024481000000104 | Viral hepatitis screening test | 4JRF. | Viral hepatitis screening test | DMWB | DMWB_CROSSMAP | 1.000 |
| 1046211000000102 | Treponema pallidum microscopy | 4JSD. | Treponema pallidum microscopy | DMWB | DMWB_CROSSMAP | 1.000 |
| 1046231000000105 | Neisseria gonorrhoeae microscopy | 4JSE. | Neisseria gonorrhoeae microscopy | DMWB | DMWB_CROSSMAP | 1.000 |
| 888111000000103 | Cervical smear - human papillomavirus positive | 4K2R. | Cervical smear - human papillomavirus positive | DMWB | DMWB_CROSSMAP | 1.000 |
| 168417005 | Cervical smear - trichomonas | 4K33. | Cervical smear - trichomonas | DMWB | DMWB_CROSSMAP | 1.000 |
| 269963000 | Cervical smear - viral inflammation unspecified | 4K35. | Cerv.smear - viral infl.unsp. | DMWB | DMWB_CROSSMAP | 1.000 |
| 269964006 | Cervical smear - wart virus | 4K36. | Cervical smear - wart virus | DMWB | DMWB_CROSSMAP | 1.000 |
| 168421003 | Cervical smear - herpes | 4K37. | Cervical smear - herpes | DMWB | DMWB_CROSSMAP | 1.000 |
| 168424006 | Cervical smear - koilocytosis | 4K3A. | Cervical smear: koilocytosis | DMWB | DMWB_CROSSMAP | 1.000 |
| 444451006 | Exposure to sexually transmissible disorder | 65P7. | Venereal disease contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 444356002 | Exposure to Human immunodeficiency virus | 65P8. | AIDS contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 444418002 | Exposure to Chlamydia trachomatis | 65PJ. | Chlamydia trachomatis contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 444376008 | Exposure to gonorrhea | 65PK. | Gonorrhoea contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 444380003 | Exposure to Treponema pallidum | 65PN. | Syphilis contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 200401000000102 | Trichomonas vaginalis contact | 65PP. | Trichomonas vaginalis contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 444487004 | Exposure to anogenital Herpes simplex virus | 65PQ. | Genital herpes simplex contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 200681000000109 | HIV (human immunodeficiency virus) contact | 65PR. | Human immunodeficiency virus contact | DMWB | DMWB_CROSSMAP | 1.000 |
| 281635007 | Sexually transmitted infection contact | 65PS. | Sexually transmitted infection contact | SEMANTIC | EXACT | 1.000 |
| 170490008 | Gonorrhea carrier | 65Q8. | Gonorrhoea carrier | DMWB | DMWB_CROSSMAP | 1.000 |
| 1094401000000104 | Sexually transmitted disease carrier | 65Q9. | Venereal disease carrier NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 699433000 | Human immunodeficiency virus (HIV) carrier | 65QA. | AIDS carrier | DMWB | DMWB_CROSSMAP | 1.000 |
| 170530008 | Notification of AIDS | 65VE. | Notification of AIDS | DMWB | DMWB_CROSSMAP | 1.000 |
| 504871000000109 | Human immunodeficiency virus monitoring | 66j.. | Human immunodeficiency virus monitoring | DMWB | DMWB_CROSSMAP | 1.000 |
| 504901000000109 | Human immunodeficiency virus annual review | 66j0. | Human immunodeficiency virus annual review | DMWB | DMWB_CROSSMAP | 1.000 |
| 200641000000101 | Chlamydia screening counselling | 677L. | Chlamydia screening counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 200801000000100 | Gonorrhoea screening counselling | 677M. | Gonorrhoea screening counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 200901000000108 | HIV (human immunodeficiency virus) screening counselling | 677N. | HIV screening counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 204661000000108 | Syphilis screening counselling | 677P. | Syphilis screening counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 204671000000101 | Hepatitis C screening counselling | 677Q. | Hepatitis C screening counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 204681000000104 | Hepatitis B screening counselling | 677R. | Hepatitis B screening counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 439057000 | Education about sexually transmitted disease prevention | 679K9 | Education about prevention of sexually transmitted disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 171121004 | HIV screening test | 6827 | AIDS (HTLV-III) screening | DMWB | DMWB_CROSSMAP | 1.000 |
| 171128005 | Sexually transmitted infection screening | 6832 | Venereal disease screening | DMWB | DMWB_CROSSMAP | 1.000 |
| 442487003 | Screening for Chlamydia trachomatis | 683C. | Chlamydia trachomatis screening | DMWB | DMWB_CROSSMAP | 1.000 |
| 391144006 | Human papillomavirus test consent given | 685N. | HPV - Human papillomavirus test consent given | DMWB | DMWB_CROSSMAP | 1.000 |
| 412761009 | Urine screen for chlamydia | 68K7. | Urine screen for chlamydia | DMWB | DMWB_CROSSMAP | 1.000 |
| 449013002 | Cauterisation of anal wart | 77323 | Cauterisation of perianal warts NEC | DMWB | DMWB_CROSSMAP | 1.000 |
| 174342008 | Cryotherapy to perianal warts | 77324 | Cryotherapy to perianal warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 174343003 | Painting of perianal warts | 77325 | Painting of perianal warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 176610008 | Painting of vulval warts | 7D035 | Painting of vulval warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 230091000000109 | Human immunodeficiency virus blood test | 7P1A0 | Human immunodeficiency virus blood test | DMWB | DMWB_CROSSMAP | 1.000 |
| 768841000000107 | Post exposure prophylaxis after sexual exposure | 8B6e. | Post exposure prophylaxis after sexual exposure | DMWB | DMWB_CROSSMAP | 1.000 |
| 829241000000108 | 12 week virologic response to hepatitis C treatment | 8BB5. | 12 week virologic response to hepatitis C treatment | DMWB | DMWB_CROSSMAP | 1.000 |
| 198781000000103 | Patient advised to notify sexual partners of sexual transmitted infection | 8CAd. | Pt ad notify sexual partners of sexual transmitted infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 183083004 | Patient advised about the risks of HIV | 8CAE. | Patient advised about the risks of HIV | DMWB | DMWB_CROSSMAP | 1.000 |
| 835401000000109 | Discussion about human immunodeficiency virus post exposure prophylaxis | 8CP9. | Discussion about HIV post exposure prophylaxis | DMWB | DMWB_CROSSMAP | 1.000 |
| 864511000000102 | Sexually transmitted infection in-house follow-up | 8HBQ0 | Sexually transmitted infection in-house follow-up | DMWB | DMWB_CROSSMAP | 1.000 |
| 817381000000107 | Referral to community human immunodeficiency virus nurse specialist | 8Hle. | Referral to community HIV nurse specialist | DMWB | DMWB_CROSSMAP | 1.000 |
| 415272006 | Referral to genitourinary clinic | 8HTa. | Referral to genitourinary clinic | DMWB | DMWB_CROSSMAP | 1.000 |
| 412712007 | Referral to sexually transmitted infections clinic | 8HTR. | Referral to sexually transmitted infections clinic | DMWB | DMWB_CROSSMAP | 1.000 |
| 183905006 | Private referral to venereologist | 8HVP. | Private referral to venereologist | DMWB | DMWB_CROSSMAP | 1.000 |
| 200651000000103 | Gonorrhoea screening declined | 8I3o. | Gonorrhoea screening declined | DMWB | DMWB_CROSSMAP | 1.000 |
| 202261000000101 | Syphilis screening declined | 8I3t. | Syphilis screening declined | DMWB | DMWB_CROSSMAP | 1.000 |
| 412718006 | Chlamydia screening declined | 8I3T. | Chlamydia screening declined | DMWB | DMWB_CROSSMAP | 1.000 |
| 355251000000105 | Urine neisseria gonorrhoeae test positive | 9ka.. | Urine neisseria gonorrhoeae test positive - enhan serv admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 355281000000104 | Urine neisseria gonorrhoeae test negative | 9kb.. | Urine neisseria gonorrhoeae test negative - enhan serv admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 166401000000102 | Specialised sexual health enhanced services administration | 9kF.. | Specialised sexual health - enhanced services administration | DMWB | DMWB_CROSSMAP | 1.000 |
| 166491000000109 | Specialised sexual health enhanced service completed | 9kF0. | Specialised sexual health - enhanced service completed | DMWB | DMWB_CROSSMAP | 1.000 |
| 355161000000101 | Patient reviewed following treatment for sexually transmitted disease | 9kF1. | Patient reviewed following treatment for STD - enh ser admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 362881000000103 | Urine screen for gonorrhoea | 9kF2. | Urine screen for gonorrhoea - enhanced services administratn | DMWB | DMWB_CROSSMAP | 1.000 |
| 363091000000104 | Counselling for genital herpes screening | 9kF3. | Counselling for genital herpes screening - enhanc serv admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 355221000000100 | Syphilis screen 3 months post treatment | 9kF4. | Syphilis screen 3 month post treatment - enhanced serv admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 355651000000107 | Syphilis screen 6 months post treatment | 9kF5. | Syphilis screen 6 month post treatment - enhanced serv admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 355681000000101 | Syphilis screen 1 year post treatment | 9kF6. | Syphilis screen 1 year post treatment - enhanced serv admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 364771000000102 | Treatment of recurrent genital herpes | 9kF8. | Treatment of recurrent genital herpes - enhanced services ad | DMWB | DMWB_CROSSMAP | 1.000 |
| 504931000000103 | HIV (Human immunodeficiency virus) positive general health check service declined - enhanced services administration | 9kl.. | HIV pos gen health check serv declind - enhanc service admin | DMWB | DMWB_CROSSMAP | 1.000 |
| 894621000000106 | Human immunodeficiency virus infection monitoring invitation | 9mN.. | Human immunodeficiency virus infection monitoring invitation | DMWB | DMWB_CROSSMAP | 1.000 |
| 894641000000104 | Human immunodeficiency virus infection monitoring telephone invitation | 9mN0. | HIV infection monitoring telephone invitation | DMWB | DMWB_CROSSMAP | 1.000 |
| 894661000000103 | Human immunodeficiency virus infection monitoring first telephone invitation | 9mN00 | HIV infection monitoring first telephone invitation | DMWB | DMWB_CROSSMAP | 1.000 |
| 894781000000104 | Human immunodeficiency virus infection monitoring second telephone invitation | 9mN01 | HIV infection monitoring second telephone invitation | DMWB | DMWB_CROSSMAP | 1.000 |
| 894801000000103 | Human immunodeficiency virus infection monitoring third telephone invitation | 9mN02 | HIV infection monitoring third telephone invitation | DMWB | DMWB_CROSSMAP | 1.000 |
| 185180001 | Seen in GU medicine clinic | 9N0L. | Seen in GU medicine clinic | DMWB | DMWB_CROSSMAP | 1.000 |
| 839551000000107 | Consultation for complex sexual health need | 9Na4. | Consultation for complex sexual health need | DMWB | DMWB_CROSSMAP | 1.000 |
| 503241000000102 | Did not attend genitourinary medicine clinic | 9NiP. | Did not attend genitourinary medicine clinic | DMWB | DMWB_CROSSMAP | 1.000 |
| 786221000000101 | In-house genitourinary medicine | 9NJu. | In-house genitourinary medicine | DMWB | DMWB_CROSSMAP | 1.000 |
| 786251000000106 | In-house genitourinary medicine first appointment | 9NJu0 | In-house genitourinary medicine first appointment | DMWB | DMWB_CROSSMAP | 1.000 |
| 787781000000107 | In-house genitourinary medicine follow-up appointment | 9NJu1 | In-house genitourinary medicine follow-up appointment | DMWB | DMWB_CROSSMAP | 1.000 |
| 787801000000108 | In-house genitourinary medicine discharge | 9NJu2 | In-house genitourinary medicine discharge | DMWB | DMWB_CROSSMAP | 1.000 |
| 862191000000107 | Seen by community HIV (human immunodeficiency virus) nurse | 9Nt10 | Seen by community HIV (human immunodeficiency virus) nurse | DMWB | DMWB_CROSSMAP | 1.000 |
| 1103711000000100 | HIV (human immunodeficiency virus) test offered | 9Op0. | HIV screening offered | DMWB | DMWB_CROSSMAP | 1.000 |
| 200591000000105 | Chlamydia test offered | 9Oq0. | Chlamydia test offered | DMWB | DMWB_CROSSMAP | 1.000 |
| 202241000000102 | Syphilis screening offered | 9Oq1. | Syphilis screening offered | DMWB | DMWB_CROSSMAP | 1.000 |
| 504751000000108 | Chlamydia screening programme test kit issued | 9Oq4. | Chlamydia screening programme test kit issued | DMWB | DMWB_CROSSMAP | 1.000 |
| 835261000000109 | Sexually transmitted infection screening offered | 9OqB. | Sexually transmitted infection screening offered | DMWB | DMWB_CROSSMAP | 1.000 |
| 67915005 | Intestinal trichomoniasis | A063. | Intestinal trichomoniasis | DMWB | DMWB_CROSSMAP | 1.000 |
| 33839006 | Genital herpes simplex | A541. | Genital herpes simplex | DMWB | DMWB_CROSSMAP | 1.000 |
| 10754701000119100 | Genital herpes in childbirth | A5410 | Genital herpes unspecified | SEMANTIC | TOKEN_OVERLAP | .667 |
| 27420004 | Herpetic vulvovaginitis | A5411 | Herpetic vulvovaginitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 59819007 | Herpes simplex vulvitis | A5412 | Herpetic ulceration of vulva | DMWB | DMWB_CROSSMAP | 1.000 |
| 10227000 | Herpetic infection of penis | A5413 | Herpetic infection of penis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186537009 | Herpesviral infection of perianal skin and rectum | A5414 | Herpesviral infection of perianal skin and rectum | DMWB | DMWB_CROSSMAP | 1.000 |
| 186538004 | Anogenital herpesviral infection | A5415 | Anogenital herpesviral infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 440714005 | Genital herpes simplex type 1 | A5416 | Genital herpes simplex type 1 | DMWB | DMWB_CROSSMAP | 1.000 |
| 423391007 | Genital herpes simplex type 2 | A5417 | Genital herpes simplex type 2 | DMWB | DMWB_CROSSMAP | 1.000 |
| 439912007 | Recurrent genital herpes simplex type 1 | A5418 | Recurrent genital herpes simplex type 1 | DMWB | DMWB_CROSSMAP | 1.000 |
| 439913002 | Recurrent genital herpes simplex type 2 | A5419 | Recurrent genital herpes simplex type 2 | DMWB | DMWB_CROSSMAP | 1.000 |
| 402894005 | Recurrent genital herpes simplex | A541z | Genital herpes simplex NOS | SEMANTIC | TOKEN_OVERLAP | .750 |
| 359814004 | Monkey pox | A57y5 | Monkeypox | DMWB | DMWB_CROSSMAP | 1.000 |
| 543791000000108 | Other viral or chlamydial diseases | A7... | Other viral and chlamydial diseases | DMWB | DMWB_CROSSMAP | 1.000 |
| 57019003 | Verruca vulgaris | A781. | Viral warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 266113007 | Genital warts | A7812 | Genital warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 266114001 | Perianal warts | A7813 | Perianal warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 868341000000102 | Recurrent genital warts | A7817 | Recurrent genital warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 62479008 | AIDS | A788. | Acquired immune deficiency syndrome | DMWB | DMWB_CROSSMAP | 1.000 |
| 111880001 | Acute HIV infection | A7880 | Acute human immunodeficiency virus infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 91947003 | Asymptomatic human immunodeficiency virus infection | A7881 | Asymptomatic human immunodeficiency virus infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 95892003 | Persistent generalized lymphadenopathy caused by human immunodeficiency virus | A7882 | HIV infection with persistent generalised lymphadenopathy | DMWB | DMWB_CROSSMAP | 1.000 |
| 186706006 | Human immunodeficiency virus infection constitutional disease | A7883 | Human immunodeficiency virus with constitutional disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 186707002 | Human immunodeficiency virus infection with neurological disease | A7884 | Human immunodeficiency virus with neurological disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 186708007 | Human immunodeficiency virus infection with secondary clinical infectious disease | A7885 | Human immunodeficiency virus with secondary infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 713572001 | Malignant neoplastic disease co-occurrent with human immunodeficiency virus infection | A7886 | Human immunodeficiency virus with secondary cancers | DMWB | DMWB_CROSSMAP | 1.000 |
| 943041000000105 | HIV (human immunodeficiency virus) disease resulting in haematological and immunological abnormalities | A788U | HIV disease result/haematological+immunologic abnorms,NEC | DMWB | DMWB_CROSSMAP | 1.000 |
| 86406008 | HIV - Human immunodeficiency virus infection | A788V | HIV disease resulting in multiple diseases CE | DMWB | DMWB_CROSSMAP | 1.000 |
| 664701000000103 | Human immunodeficiency virus with other clinical findings | A788y | Human immunodeficiency virus with other clinical findings | SEMANTIC | EXACT | 1.000 |
| 577001000000106 | Acquired human immunodeficiency virus infection syndrome NOS | A788z | Acquired human immunodeficiency virus infection syndrome NOS | SEMANTIC | EXACT | 1.000 |
| 81000119104 | Symptomatic human immunodeficiency virus infection | A789. | Human immunodef virus resulting in other disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 420818005 | Mycobacteriosis with acquired immunodeficiency syndrome | A7890 | HIV disease resulting in mycobacterial infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 420403001 | Pneumocystosis with acquired immunodeficiency syndrome | A7893 | HIV disease resulting in Pneumocystis carinii pneumonia | DMWB | DMWB_CROSSMAP | 1.000 |
| 420524008 | Kaposi's sarcoma with acquired immunodeficiency syndrome | A7895 | HIV disease resulting in Kaposi's sarcoma | DMWB | DMWB_CROSSMAP | 1.000 |
| 713897006 | Burkitt's lymphoma co-occurrent with human immunodeficiency virus infection | A7896 | HIV disease resulting in Burkitt's lymphoma | DMWB | DMWB_CROSSMAP | 1.000 |
| 442537007 | Non-Hodgkin lymphoma associated with Human immunodeficiency virus infection | A7897 | HIV dis resulting oth types of non-Hodgkin's lymphoma | DMWB | DMWB_CROSSMAP | 1.000 |
| 186725009 | HIV disease resulting in multiple malignant neoplasms | A7898 | HIV disease resulting in multiple malignant neoplasms | SEMANTIC | EXACT | 1.000 |
| 421671002 | Pneumonia with acquired immunodeficiency syndrome | A7899 | HIV disease resulting in lymphoid interstitial pneumonitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 422003001 | Cachexia associated with AIDS | A789A | HIV disease resulting in wasting syndrome | DMWB | DMWB_CROSSMAP | 1.000 |
| 105629000 | Chlamydial infection | A78A. | Chlamydial infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 186729003 | Chlamydial infection of lower genitourinary tract | A78A0 | Chlamydial infection of lower genitourinary tract | DMWB | DMWB_CROSSMAP | 1.000 |
| 232403001 | Chlamydial pharyngitis | A78A1 | Chlamydial infection of pharynx | DMWB | DMWB_CROSSMAP | 1.000 |
| 186731007 | Chlamydial infection of anus and rectum | A78A2 | Chlamydial infection of anus and rectum | DMWB | DMWB_CROSSMAP | 1.000 |
| 312099009 | Genitourinary chlamydia infection | A78A3 | Chlamydial inf of pelviperitoneum oth genitourinary organs | DMWB | DMWB_CROSSMAP | 1.000 |
| 231861005 | Chlamydial conjunctivitis | A78A4 | Chlamydial conjunctivitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 105635000 | Retrovirus infection | A798. | Retrovirus infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 240532009 | Human papillomavirus infection | A79B. | Human papilloma virus infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 8098009 | Sexually transmitted infectious disease | A9... | Syphilis and other venereal diseases | DMWB | DMWB_CROSSMAP | 1.000 |
| 35742006 | Congenital syphilis | A90.. | Congenital syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 266125005 | Early congenital syphilis, symptomatic (less than 2 years) | A900. | Early congenital syphilis with symptoms | DMWB | DMWB_CROSSMAP | 1.000 |
| 186833000 | Early congenital syphilis - latent | A901. | Early latent congenital syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 4359001 | Early congenital syphilis | A902. | Early congenital syphilis NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 44568006 | Syphilitic interstitial keratitis | A903. | Syphilitic interstitial keratitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 266126006 | Late congenital neurosyphilis | A904. | Juvenile neurosyphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 32735002 | Congenital syphilitic encephalitis | A9041 | Congenital syphilitic encephalitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 6267005 | Congenital syphilitic meningitis | A9042 | Congenital syphilitic meningitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 82323002 | Juvenile syphilis | A905. | Other late congenital syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 87318008 | Congenital syphilis with gumma | A9050 | Congenital syphilitic gumma | DMWB | DMWB_CROSSMAP | 1.000 |
| 86443005 | Hutchinson's teeth | A9051 | Hutchinson's teeth | DMWB | DMWB_CROSSMAP | 1.000 |
| 77782006 | Syphilitic saddle nose | A9052 | Syphilitic saddle nose | DMWB | DMWB_CROSSMAP | 1.000 |
| 186842007 | Late congenital syphilitic oculopathy | A9053 | Late congenital syphilitic oculopathy | DMWB | DMWB_CROSSMAP | 1.000 |
| 186843002 | Other late congenital syphilis NOS | A905z | Other late congenital syphilis NOS | SEMANTIC | EXACT | 1.000 |
| 827006 | Late congenital syphilis, latent (+ sero., - C.S.F., 2 years OR more) | A906. | Latent late congenital syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 608551000000101 | Unspecified late congenital syphilis | A907. | Unspecified late congenital syphilis | SEMANTIC | EXACT | 1.000 |
| 186845009 | Congenital syphilis NOS | A90z. | Congenital syphilis NOS | SEMANTIC | EXACT | 1.000 |
| 186846005 | Early symptomatic syphilis | A91.. | Early symptomatic syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186847001 | Primary genital syphilis | A910. | Primary genital syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 31015008 | Primary anal syphilis | A911. | Primary anal syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 266127002 | Primary syphilis | A912. | Other primary syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 27460003 | Primary breast syphilis | A9120 | Primary breast syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 54274001 | Primary finger syphilis | A9121 | Primary finger syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 28198007 | Primary lip syphilis | A9122 | Primary lip syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 10345003 | Primary tonsil syphilis | A9123 | Primary tonsil syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 266209006 | Primary syphilis | A912z | Other primary syphilis NOS | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 186850003 | Secondary syphilis of skin and mucous membrane | A913. | Secondary syphilis of skin or mucus membranes | DMWB | DMWB_CROSSMAP | 1.000 |
| 77028001 | Secondary syphilis of anus | A9130 | Secondary syphilis of anus | DMWB | DMWB_CROSSMAP | 1.000 |
| 60528006 | Secondary syphilis of mouth | A9131 | Secondary syphilis of mouth | DMWB | DMWB_CROSSMAP | 1.000 |
| 51960003 | Secondary syphilis of pharynx | A9132 | Secondary syphilis of pharynx | DMWB | DMWB_CROSSMAP | 1.000 |
| 59233003 | Secondary syphilis of skin | A9133 | Secondary syphilis of skin | DMWB | DMWB_CROSSMAP | 1.000 |
| 81339006 | Secondary syphilis of tonsils | A9134 | Secondary syphilis of tonsils | DMWB | DMWB_CROSSMAP | 1.000 |
| 52414005 | Secondary syphilis of vulva | A9135 | Secondary syphilis of vulva | DMWB | DMWB_CROSSMAP | 1.000 |
| 186852006 | Secondary syphilis of skin or mucus membranes NOS | A913z | Secondary syphilis of skin or mucus membranes NOS | SEMANTIC | EXACT | 1.000 |
| 59934002 | Adenopathy due to secondary syphilis | A914. | Adenopathy due to secondary syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186854007 | Uveitis due to secondary syphilis | A915. | Uveitis due to secondary syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 410478005 | Ocular syphilis | A9150 | Syphilitic uveitis unspecified | DMWB | DMWB_CROSSMAP | 1.000 |
| 66281009 | Secondary syphilitic chorioretinitis | A9151 | Secondary syphilitic chorioretinitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 30080002 | Secondary syphilitic iridocyclitis | A9152 | Secondary syphilitic iridocyclitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186857000 | Secondary syphilitic uveitis NOS | A915z | Secondary syphilitic uveitis NOS | SEMANTIC | EXACT | 1.000 |
| 266129004 | Secondary syphilis of viscera or bone | A916. | Secondary syphilis of viscera or bone | DMWB | DMWB_CROSSMAP | 1.000 |
| 69595007 | Secondary syphilitic periostitis | A9160 | Secondary syphilitic periostitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 80770009 | Secondary syphilis of liver | A9161 | Secondary syphilitic hepatitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 58227000 | Secondary syphilis of viscera | A916z | Secondary syphilis of viscera and bone NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 186861006 | Secondary syphilis relapse | A917. | Secondary syphilis relapse | DMWB | DMWB_CROSSMAP | 1.000 |
| 240557004 | Secondary syphilis | A918. | Other forms of secondary syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186863009 | Acute secondary syphilitic meningitis | A9180 | Acute secondary syphilitic meningitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 59307008 | Syphilitic alopecia | A9181 | Syphilitic alopecia | DMWB | DMWB_CROSSMAP | 1.000 |
| 154382002 | Secondary syphilis | A918z | Other secondary syphilis NOS | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 186865002 | Unspecified secondary syphilis | A919. | Unspecified secondary syphilis | SEMANTIC | EXACT | 1.000 |
| 186867005 | Latent early syphilis | A92.. | Latent early syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186868000 | Serological relapse after treatment of latent early syphilis | A920. | Serological relapse after treatment of latent early syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 266130009 | Acquired syphilis - early latent | A92z. | Latent early syphilis NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 83883001 | Cardiovascular syphilis | A93.. | Cardiovascular syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 12232008 | Syphilitic aneurysm of aorta | A930. | Syphilitic aortic aneurysm | DMWB | DMWB_CROSSMAP | 1.000 |
| 20735004 | Syphilis-associated aortitis | A931. | Syphilitic aortitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 67391006 | Syphilitic endocarditis | A932. | Syphilitic endocarditis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186874000 | Syphilitic endocarditis of unspecified valve | A9320 | Syphilitic endocarditis of unspecified valve | SEMANTIC | EXACT | 1.000 |
| 186875004 | Syphilitic endocarditis of mitral valve | A9321 | Syphilitic endocarditis of mitral valve | DMWB | DMWB_CROSSMAP | 1.000 |
| 278480000 | Syphilitic endocarditis of aortic valve | A9322 | Syphilitic endocarditis of aortic valve | DMWB | DMWB_CROSSMAP | 1.000 |
| 186877007 | Syphilitic endocarditis of tricuspid valve | A9323 | Syphilitic endocarditis of tricuspid valve | DMWB | DMWB_CROSSMAP | 1.000 |
| 186878002 | Syphilitic endocarditis of pulmonary valve | A9324 | Syphilitic endocarditis of pulmonary valve | DMWB | DMWB_CROSSMAP | 1.000 |
| 186879005 | Syphilitic endocarditis of heart valve NOS | A932z | Syphilitic endocarditis of heart valve NOS | SEMANTIC | EXACT | 1.000 |
| 577011000000108 | Other specified cardiovascular system syphilis | A93y. | Other specified cardiovascular system syphilis | SEMANTIC | EXACT | 1.000 |
| 3589003 | Syphilitic pericarditis | A93y0 | Syphilitic pericarditis | DMWB | DMWB_CROSSMAP | 1.000 |
| 4082005 | Myocarditis caused by Treponema pallidum | A93y1 | Syphilitic myocarditis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186882000 | Other specified cardiovascular system syphilis NOS | A93yz | Other specified cardiovascular system syphilis NOS | SEMANTIC | EXACT | 1.000 |
| 186883005 | Cardiovascular syphilis NOS | A93z. | Cardiovascular syphilis NOS | SEMANTIC | EXACT | 1.000 |
| 26039008 | Neurosyphilis | A94.. | Neurosyphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 316841006 | Tabes dorsalis - neurosyphilis | A940. | Tabes dorsalis - neurosyphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 51928006 | Paralytic dementia | A941. | General paresis - neurosyphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 301086002 | Syphilitic meningitis | A942. | Syphilitic meningitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 37754005 | Asymptomatic neurosyphilis | A943. | Asymptomatic neurosyphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 266133006 | Late quaternary neurosyphilis | A94y. | Other specified neurosyphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 26135000 | Syphilitic encephalitis | A94y0 | Syphilitic encephalitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 38523005 | Syphilitic parkinsonism | A94y1 | Syphilitic parkinsonism | DMWB | DMWB_CROSSMAP | 1.000 |
| 77939001 | Syphilitic disseminated retinochoroiditis | A94y2 | Syphilitic disseminated retinochoroiditis | DMWB | DMWB_CROSSMAP | 1.000 |
| 22386003 | Syphilitic optic atrophy | A94y3 | Syphilitic optic atrophy | DMWB | DMWB_CROSSMAP | 1.000 |
| 36276008 | Syphilitic retrobulbar neuritis | A94y4 | Syphilitic retrobulbar neuritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 19206003 | Syphilitic acoustic neuritis | A94y5 | Syphilitic acoustic neuritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186893003 | Rupture of syphilitic cerebral aneurysm | A94y6 | Rupture of syphilitic cerebral aneurysm | DMWB | DMWB_CROSSMAP | 1.000 |
| 186884004 | Neurosyphilis | A94z. | Neurosyphilis NOS | SEMANTIC | NORMALISED | .950 |
| 72083004 | Late syphilis | A95.. | Other forms of late syphilis with symptoms | DMWB | DMWB_CROSSMAP | 1.000 |
| 11338007 | Syphilitic episcleritis | A950. | Syphilitic episcleritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 8555001 | Syphilis of lung | A951. | Syphilis of lung | DMWB | DMWB_CROSSMAP | 1.000 |
| 34964002 | Peritonitis - syphilitic | A952. | Syphilitic peritonitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 86028001 | Syphilis of liver | A953. | Syphilis of liver | DMWB | DMWB_CROSSMAP | 1.000 |
| 59530001 | Renal syphilis | A954. | Syphilis of kidney | DMWB | DMWB_CROSSMAP | 1.000 |
| 50528008 | Syphilis of bone | A955. | Syphilis of bone | DMWB | DMWB_CROSSMAP | 1.000 |
| 88943008 | Syphilis of muscle | A956. | Syphilis of muscle | DMWB | DMWB_CROSSMAP | 1.000 |
| 186899004 | Syphilis of synovium, tendon or bursa | A957. | Syphilis of synovium, tendon or bursa | DMWB | DMWB_CROSSMAP | 1.000 |
| 37430004 | Syphilis of synovium | A9570 | Syphilis of synovium | DMWB | DMWB_CROSSMAP | 1.000 |
| 49923008 | Syphilis of tendon | A9571 | Syphilis of tendon | DMWB | DMWB_CROSSMAP | 1.000 |
| 23550005 | Syphilis of bursa | A9572 | Syphilis of bursa | DMWB | DMWB_CROSSMAP | 1.000 |
| 186900009 | Syphilis of synovium, tendon or bursa NOS | A957z | Syphilis of synovium, tendon or bursa NOS | SEMANTIC | EXACT | 1.000 |
| 562111000000104 | Other specified late syphilis | A95y. | Other specified late syphilis | SEMANTIC | EXACT | 1.000 |
| 577061000000105 | Late symptomatic syphilis NOS | A95z. | Late symptomatic syphilis NOS | SEMANTIC | EXACT | 1.000 |
| 186903006 | Late latent syphilis | A96.. | Late latent syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 76272004 | Syphilis | A97.. | Other and unspecified syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186905004 | Late syphilis unspecified | A970. | Late syphilis unspecified | SEMANTIC | EXACT | 1.000 |
| 567541000000109 | Latent syphilis unspecified | A971. | Latent syphilis unspecified | SEMANTIC | EXACT | 1.000 |
| 186907007 | Syphilis NOS | A97z. | Syphilis NOS | SEMANTIC | EXACT | 1.000 |
| 15628003 | GC - Gonococcus infection | A98.. | Gonococcal infections | DMWB | DMWB_CROSSMAP | 1.000 |
| 54825009 | Acute gonorrhoea of lower genitourinary tract | A980. | Acute gonorrhoea of lower genitourinary tract | DMWB | DMWB_CROSSMAP | 1.000 |
| 80604007 | Acute gonococcal bartholinitis | A9800 | Acute gonococcal Bartholinitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 29864006 | Acute gonococcal urethritis | A9801 | Acute gonococcal urethritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 2390000 | Acute gonococcal vulvovaginitis | A9802 | Acute gonococcal vulvovaginitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 577091000000104 | Acute gonorrhoea of lower genitourinary tract NOS | A980z | Acute gonorrhoea of lower genitourinary tract NOS | SEMANTIC | EXACT | 1.000 |
| 50970007 | Acute gonorrhoea of upper genitourinary tract | A981. | Acute gonorrhoea of upper genitourinary tract | DMWB | DMWB_CROSSMAP | 1.000 |
| 186910000 | Acute gonorrhoea of upper genitourinary tract | A9810 | Acute unspecified gonorrhoea of upper genitourinary tract | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 24868007 | Bladder gonorrhoea - acute | A9811 | Acute gonococcal cystitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 111806005 | Acute gonococcal prostatitis | A9812 | Acute gonococcal prostatitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 30168008 | Acute gonococcal epididymo-orchitis | A9813 | Acute gonococcal epididymo-orchitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 65049003 | Acute gonococcal seminal vesiculitis | A9814 | Acute gonococcal seminal vesiculitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 20943002 | Acute gonococcal cervicitis | A9815 | Acute gonococcal cervicitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 65295003 | Acute gonococcal endometritis | A9816 | Acute gonococcal endometritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 45377007 | Acute gonococcal salpingitis | A9817 | Acute gonococcal salpingitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 577111000000109 | Acute gonorrhoea upper genitourinary tract NOS | A981z | Acute gonorrhoea upper genitourinary tract NOS | SEMANTIC | EXACT | 1.000 |
| 186915005 | Chronic gonorrhoea of lower genitourinary tract | A982. | Chronic gonorrhoea lower genitourinary tract | DMWB | DMWB_CROSSMAP | 1.000 |
| 12373006 | Chronic gonococcal bartholinitis | A9820 | Chronic gonococcal bartholinitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 44412000 | Chronic inflammation of urethra caused by Neisseria gonorrhoeae | A9821 | Chronic gonococcal urethritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 11906007 | Chronic gonococcal vulvovaginitis | A9822 | Chronic gonococcal vulvovaginitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186916006 | Chronic gonorrhoea of lower genitourinary tract NOS | A982z | Chronic gonorrhoea of lower genitourinary tract NOS | SEMANTIC | EXACT | 1.000 |
| 80388004 | Chronic gonorrhea of upper genitourinary tract | A983. | Chronic gonorrhoea of upper genitourinary tract | DMWB | DMWB_CROSSMAP | 1.000 |
| 186918007 | Chronic unspecified gonorrhoea of upper genitourinary tract | A9830 | Chronic unspecified gonorrhoea of upper genitourinary tract | SEMANTIC | EXACT | 1.000 |
| 88813005 | Chronic gonococcal cystitis | A9831 | Chronic gonococcal cystitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 60893000 | Chronic gonococcal prostatitis | A9832 | Chronic gonococcal prostatitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 35526001 | Chronic gonococcal epididymo-orchitis | A9833 | Chronic gonococcal epididymo-orchitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 23975003 | Chronic gonococcal seminal vesiculitis | A9834 | Chronic gonococcal seminal vesiculitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 76802005 | Chronic gonococcal cervicitis | A9835 | Chronic gonococcal cervicitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 31999004 | Uterus - chronic gonorrhoea | A9836 | Chronic gonococcal endometritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 53529004 | Chronic gonococcal salpingitis | A9837 | Chronic gonococcal salpingitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 547711000000106 | Chronic gonorrhoea of upper genitourinary tract NOS | A983z | Chronic gonorrhoea of upper genitourinary tract NOS | SEMANTIC | EXACT | 1.000 |
| 35876006 | Gonococcal eye infection | A984. | Gonococcal eye infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 28438004 | Opthalmia neonatorum caused by Neisseria | A9840 | Neonatal gonococcal conjunctivits | DMWB | DMWB_CROSSMAP | 1.000 |
| 111807001 | Gonococcal endophthalmia | A9842 | Gonococcal endophthalmia | DMWB | DMWB_CROSSMAP | 1.000 |
| 40149008 | Gonococcal keratitis | A9843 | Gonococcal keratitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 44743006 | Gonococcal joint infection | A985. | Gonococcal joint infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 266138002 | Gonococcal synovitis or tenosynovitis | A9851 | Gonococcal synovitis or tenosynovitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 46699001 | Bursitis caused by Neisseria gonorrhoeae | A9852 | Gonococcal bursitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 53664003 | Gonococcal spondylitis | A9853 | Gonococcal spondylitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 74372003 | Gonococcal pharyngitis | A986. | Gonococcal pharynx infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 42746002 | Gonorrhoea of rectum | A987. | Gonococcal proctitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 186931002 | Gonorrhoea of anus | A9870 | Gonococcal anal infection | DMWB | DMWB_CROSSMAP | 1.000 |
| 60335002 | Gonococcal keratosis | A98y0 | Gonococcal keratosis | DMWB | DMWB_CROSSMAP | 1.000 |
| 151004 | Meningitis due to gonococcus | A98y1 | Gonococcal meningitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 90428001 | Gonococcal pericarditis | A98y2 | Gonococcal pericarditis | DMWB | DMWB_CROSSMAP | 1.000 |
| 61048000 | Gonococcal endocarditis | A98y3 | Gonococcal endocarditis | DMWB | DMWB_CROSSMAP | 1.000 |
| 9241004 | Gonococcal heart disease | A98y4 | Other gonococcal heart disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 186939000 | Gonococcal peritonitis | A98y5 | Gonococcal peritonitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 237041005 | Fitz-Hugh and Curtis syndrome | A98y6 | Fitzhugh Curtis syndrome | DMWB | DMWB_CROSSMAP | 1.000 |
| 634361000000106 | Other venereal diseases | A99.. | Other venereal diseases | SEMANTIC | EXACT | 1.000 |
| 266143009 | Chancroid | A990. | Chancroid | DMWB | DMWB_CROSSMAP | 1.000 |
| 186946009 | Nicholas Favre disease | A991. | Lymphogranuloma venereum | DMWB | DMWB_CROSSMAP | 1.000 |
| 446594000 | Pharyngeal lymphogranuloma venereum | A9910 | Pharyngeal lymphogranuloma venereum | DMWB | DMWB_CROSSMAP | 1.000 |
| 447372001 | Rectal lymphogranuloma venereum | A9911 | Rectal lymphogranuloma venereum | DMWB | DMWB_CROSSMAP | 1.000 |
| 28867007 | Granuloma inguinale | A992. | Granuloma inguinale | DMWB | DMWB_CROSSMAP | 1.000 |
| 67224007 | Reiter's disease | A993. | Reiter's disease / syndrome | DMWB | DMWB_CROSSMAP | 1.000 |
| 84619001 | Nongonococcal urethritis | A994. | Nonspecific urethritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 444458000 | Exposure to nonspecific genital infection | A995. | Nonspecific genital infection | SEMANTIC | TOKEN_OVERLAP | .750 |
| 634371000000104 | Other specified venereal diseases | A99y. | Other specified venereal diseases | SEMANTIC | EXACT | 1.000 |
| 611051000000101 | Venereal disease NOS | A99z. | Venereal disease NOS | SEMANTIC | EXACT | 1.000 |
| 186950002 | Other specified syphilis or other venereal diseases | A9y.. | Other specified syphilis or other venereal diseases | SEMANTIC | EXACT | 1.000 |
| 607321000000101 | Syphilis or venereal disease NOS | A9z.. | Syphilis or venereal disease NOS | SEMANTIC | EXACT | 1.000 |
| 41116009 | Spirochaetal infection | AA... | Other spirochaetal diseases | DMWB | DMWB_CROSSMAP | 1.000 |
| 56335008 | Trichomonas infection | AD1.. | Trichomoniasis - trichomonas | DMWB | DMWB_CROSSMAP | 1.000 |
| 35089004 | TV - Trichomonas vaginalis infection | AD10. | Urogenital trichomonas | DMWB | DMWB_CROSSMAP | 1.000 |
| 81598001 | Trichomonal vulvovaginitis | AD101 | Trichomonal vulvovaginitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 30116001 | Trichomonal urethritis | AD102 | Trichomonal urethritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 71590000 | Trichomonal prostatitis | AD103 | Trichomonal prostatitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 71011005 | Infestation by Phthirus pubis | AD22. | Phthirus pubis - pubic lice | DMWB | DMWB_CROSSMAP | 1.000 |
| 187348005 | [X]Infections with a predominantly sexual mode of transmission | Ayu4. | [X]Infections with a predominantly sexual mode of transmiss | SEMANTIC | TOKEN_OVERLAP | .667 |
| 413891000000100 | [X]Early congenital syphilis, unspecified | Ayu40 | [X]Early congenital syphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 735515000 | Symptomatic late congenital syphilis | Ayu41 | [X]Other late congenital syphilis, symptomatic | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 427851000000108 | [X]Late congenital syphilis, unspecified | Ayu42 | [X]Late congenital syphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 187352005 | [X]Congenital syphilis, unspecified | Ayu43 | [X]Congenital syphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 187353000 | [X]Primary syphilis of other sites | Ayu44 | [X]Primary syphilis of other sites | SEMANTIC | EXACT | 1.000 |
| 399271000000106 | [X]Other secondary syphilis | Ayu45 | [X]Other secondary syphilis | SEMANTIC | EXACT | 1.000 |
| 187355007 | [X]Early syphilis, unspecified | Ayu46 | [X]Early syphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 396281000000100 | [X]Neurosyphilis, unspecified | Ayu47 | [X]Neurosyphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 278481001 | Quaternary syphilis | Ayu48 | [X]Other symptomatic late syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 187358009 | [X]Late syphilis, unspecified | Ayu49 | [X]Late syphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 187359001 | [X]Syphilis, unspecified | Ayu4A | [X]Syphilis, unspecified | SEMANTIC | EXACT | 1.000 |
| 438971000000108 | [X]Other gonococcal infections | Ayu4B | [X]Other gonococcal infections | SEMANTIC | EXACT | 1.000 |
| 390531000000100 | [X]Gonococcal infection, unspecified | Ayu4C | [X]Gonococcal infection, unspecified | SEMANTIC | EXACT | 1.000 |
| 478751000000103 | [X]Sexually transmitted chlamydial infection of other sites | Ayu4D | [X]Sexually transmitted chlamydial infection of other sites | SEMANTIC | EXACT | 1.000 |
| 187366000 | [X]Other specified predominantly sexually transmitted diseases | Ayu4H | [X]Other specifd predominantly sexually transmitted diseases | SEMANTIC | TOKEN_OVERLAP | .667 |
| 187367009 | [X]Unspecified sexually transmitted disease | Ayu4J | [X]Unspecified sexually transmitted disease | SEMANTIC | EXACT | 1.000 |
| 402081000000102 | [X]Chlamydial infection of genitourinary tract, unspecified | Ayu4K | [X]Chlamydial infection of genitourinary tract, unspecified | SEMANTIC | EXACT | 1.000 |
| 237109002 | Vulval warts | Ayu4L | [X]Vulval warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 298128008 | Perineal wart | Ayu4M | [X]Perineal warts | DMWB | DMWB_CROSSMAP | 1.000 |
| 471481000000108 | [X]Other diseases caused by chlamydiae | Ayu6. | [X]Other diseases caused by chlamydiae | SEMANTIC | EXACT | 1.000 |
| 240590004 | Neonatal chlamydial infection | Ayu62 | [X]Chlamydial infection, unspecified | SEMANTIC | TOKEN_OVERLAP | .667 |
| 468931000000102 | [X]Human immunodeficiency virus disease | AyuC. | [X]Human immunodeficiency virus disease | SEMANTIC | EXACT | 1.000 |
| 411831000000102 | [X]HIV disease resulting in other bacterial infections | AyuC0 | [X]HIV disease resulting in other bacterial infections | SEMANTIC | EXACT | 1.000 |
| 441561000000104 | [X]HIV disease resulting in other viral infections | AyuC1 | [X]HIV disease resulting in other viral infections | SEMANTIC | EXACT | 1.000 |
| 413621000000104 | [X]HIV disease resulting in other mycoses | AyuC2 | [X]HIV disease resulting in other mycoses | SEMANTIC | EXACT | 1.000 |
| 186721000 | Human immunodeficiency virus (HIV) disease resulting in multiple infections | AyuC3 | [X]HIV disease resulting in multiple infections | SEMANTIC | TOKEN_OVERLAP | .625 |
| 418661000000104 | [X]Hiv disease resulting in other infectious and parasitic diseases | AyuC4 | [X]HIV disease resulting/other infectious+parasitic diseases | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 466811000000104 | [X]Hiv disease resulting in unspecified infectious and parasitic disease | AyuC5 | [X]HIV disease resulting/unspcf infectious+parasitic disease | SEMANTIC | TOKEN_OVERLAP | .833 |
| 442351000000104 | [X]HIV disease resulting in other non-Hodgkin's lymphoma | AyuC6 | [X]HIV disease resulting in other non-Hodgkin's lymphoma | SEMANTIC | EXACT | 1.000 |
| 455571000000106 | [X]HIV disease resulting in other malignant neoplasms | AyuC8 | [X]HIV disease resulting in other malignant neoplasms | SEMANTIC | EXACT | 1.000 |
| 186712001 | [X]HIV disease resulting in unspecified malignant neoplasm | AyuC9 | [X]HIV disease resulting in unspecified malignant neoplasm | SEMANTIC | EXACT | 1.000 |
| 187450003 | [X]HIV disease resulting in multiple diseases classified elsewhere | AyuCA | [X]HIV disease resulting in multiple diseases CE | SEMANTIC | TOKEN_OVERLAP | .714 |
| 428061000000103 | [X]HIV disease resulting in other specified conditions | AyuCC | [X]HIV disease resulting in other specified conditions | SEMANTIC | EXACT | 1.000 |
| 439901000000106 | [X]Unspecified human immunodeficiency virus [HIV] disease | AyuCD | [X]Unspecified human immunodeficiency virus [HIV] disease | SEMANTIC | EXACT | 1.000 |
| 402913004 | Bowenoid papulosis | B829. | Bowenoid papulosis | DMWB | DMWB_CROSSMAP | 1.000 |
| 421529006 | Acquired immune deficiency syndrome-related dementia | Eu024 | [X]Dementia in human immunodef virus [HIV] disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 192647003 | Secondary syphilitic meningitis | F0075 | Meningitis due to secondary syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 192699001 | Syphilis encephalitis (& congenital) | F0331 | Encephalitis due to congenital syphilis | SEMANTIC | TOKEN_OVERLAP | .750 |
| 192700000 | Encephalitis due to syphilis unspecified | F0332 | Encephalitis due to syphilis unspecified | SEMANTIC | EXACT | 1.000 |
| 193786000 | Keratitis due to syphilis | F4A54 | Keratitis due to syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 4129001 | Argyll-Robertson pupil | F4K44 | Argyll Robertson pupil | DMWB | DMWB_CROSSMAP | 1.000 |
| 24225004 | Adie's pupil syndrome | F4K46 | Adie's pupil syndrome | DMWB | DMWB_CROSSMAP | 1.000 |
| 194907008 | Acute syphilitic pericarditis | G5002 | Acute pericarditis - syphilitic | DMWB | DMWB_CROSSMAP | 1.000 |
| 194910001 | Acute gonococcal pericarditis | G5005 | Acute pericarditis - gonococcal | DMWB | DMWB_CROSSMAP | 1.000 |
| 194947001 | Acute syphilitic myocarditis | G5204 | Acute myocarditis - syphilitic | DMWB | DMWB_CROSSMAP | 1.000 |
| 186871008 | Syphilitic aortic aneurysm | G717. | Aortic aneurysm - syphilitic | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 186872001 | Syphilitic aortitis | G767. | Aortitis - syphilitic | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 154383007 | Cardiovascular syphilis | Gy0.. | Cardiovascular syphilis | SEMANTIC | EXACT | 1.000 |
| 233610007 | Neonatal chlamydial pneumonia | H233. | Chlamydial pneumonia | SEMANTIC | TOKEN_OVERLAP | .667 |
| 196139002 | Lung disease with syphilis | H57y5 | Lung disease with syphilis | SEMANTIC | EXACT | 1.000 |
| 186898007 | Syphilitic peritonitis | J5501 | Peritonitis - syphilitic | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 197172005 | Chlamydial peritonitis | J5504 | Chlamydial peritonitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 197305002 | Syphilitic portal cirrhosis | J615F | Syphilitic portal cirrhosis | DMWB | DMWB_CROSSMAP | 1.000 |
| 197347003 | Quaternary syphilitic hepatitis | J6321 | Hepatitis in late syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 197348008 | Hepatitis in secondary syphilis | J6322 | Hepatitis in secondary syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 197757004 | Late syphilis of kidney | K0y0. | Late syphilis of kidney | DMWB | DMWB_CROSSMAP | 1.000 |
| 197848003 | Gonococcal cystitis | K1545 | Cystitis in gonorrhoea | DMWB | DMWB_CROSSMAP | 1.000 |
| 197850006 | Trichomonal cystitis | K1547 | Cystitis in trichomoniasis | DMWB | DMWB_CROSSMAP | 1.000 |
| 31822004 | Inflammation of urethra | K17y. | Other urethritis | DMWB | DMWB_CROSSMAP | 1.000 |
| 89656008 | Urethral meatitis | K17y4 | Urethral meatitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 197966009 | Syphilitic prostatitis | K2142 | Prostatitis in syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 197967000 | Gonococcal prostatitis | K2144 | Prostatitis in gonorrhoea | DMWB | DMWB_CROSSMAP | 1.000 |
| 236767000 | Chlamydial epididymitis | K2416 | Chlamydial epididymitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 198130006 | Female pelvic inflammation | K4... | Female pelvic inflammatory diseases | DMWB | DMWB_CROSSMAP | 1.000 |
| 398319002 | Abscess of fallopian tube | K4020 | Fallopian tube abscess | DMWB | DMWB_CROSSMAP | 1.000 |
| 88157006 | Salpingitis | K4026 | Salpingitis unspecified | DMWB | DMWB_CROSSMAP | 1.000 |
| 237037006 | Acute PID - acute pelvic inflammatory disease | K403. | Acute parametritis and pelvic cellulitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 237044002 | Chronic pelvic inflammatory disease | K404z | Chronic pelvic inflammatory diseases NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 198175009 | Female syphilitic pelvic inflammatory disease | K40y0 | Female syphilitic pelvic inflammatory disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 198176005 | Female chlamydial pelvic inflammatory disease | K40y1 | Female chlamydial pelvic inflammatory disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 237084006 | Chlamydial cervicitis | K4209 | Chlamydia cervicitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 198242009 | Female gonococcal pelvic inflammatory disease | K44.. | Female gonococcal pelvic inflammatory disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 562441000000107 | Female pelvic inflammatory disease NOS | K4z.. | Female pelvic inflammatory disease NOS | SEMANTIC | EXACT | 1.000 |
| 199154009 | Maternal syphilis during pregnancy, childbirth and the puerperium | L170. | Maternal syphilis in pregnancy/childbirth/puerperium | DMWB | DMWB_CROSSMAP | 1.000 |
| 199155005 | Maternal syphilis, unspecified whether during pregnancy or the puerperium | L1700 | Maternal syphilis, unspec whether in pregnancy or puerperium | SEMANTIC | TOKEN_OVERLAP | .714 |
| 199156006 | Maternal syphilis during pregnancy - baby delivered | L1701 | Maternal syphilis during pregnancy - baby delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199157002 | Maternal syphilis in the puerperium - baby delivered during current episode of care | L1702 | Maternal syphilis in puerperium - baby delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199158007 | Maternal syphilis during pregnancy - baby not yet delivered | L1703 | Maternal syphilis during pregnancy - baby not yet delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199159004 | Maternal syphilis in the puerperium - baby delivered during previous episode of care | L1704 | Maternal syphilis in puerperium - baby previously delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199160009 | Maternal syphilis during pregnancy, childbirth or the puerperium NOS | L170z | Maternal syphilis in pregnancy/childbirth/puerperium NOS | SEMANTIC | TOKEN_OVERLAP | .833 |
| 199161008 | Maternal gonorrhoea during pregnancy, childbirth and the puerperium | L171. | Maternal gonorrhoea during pregnancy/childbirth/puerperium | DMWB | DMWB_CROSSMAP | 1.000 |
| 593761000000107 | Maternal gonorrhoea, unspecified whether during pregnancy or the puerperium | L1710 | Maternal gonorrhoea, unspec whether in pregnancy/puerperium | SEMANTIC | TOKEN_OVERLAP | .714 |
| 199163006 | Postpartum gonorrhea | L1711 | Maternal gonorrhoea during pregnancy - baby delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199164000 | Maternal gonorrhea in the puerperium - baby delivered during current episode of care | L1712 | Maternal gonorrhoea in puerperium - baby delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199165004 | Maternal gonorrhoea during pregnancy - baby not yet delivered | L1713 | Maternal gonorrhoea in pregnancy - baby not yet delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 199166003 | Maternal gonorrhea in the puerperium - baby delivered during previous episode of care | L1714 | Maternal gonorrhoea in puerperium- baby previously delivered | DMWB | DMWB_CROSSMAP | 1.000 |
| 274118001 | Venereal disease in pregnancy | L172. | Other venereal diseases in pregnancy/childbirth/puerperium | DMWB | DMWB_CROSSMAP | 1.000 |
| 199169005 | Other maternal venereal disease, unspecified whether during pregnancy or the puerperium | L1720 | Other maternal venereal disease, unspec pregnancy/puerperium | SEMANTIC | TOKEN_OVERLAP | .625 |
| 199170006 | Other maternal venereal disease in pregnancy - baby delivered | L1722 | Other maternal venereal disease in puerperium-baby delivered | SEMANTIC | TOKEN_OVERLAP | .714 |
| 27075004 | Venereal disease in mother complicating pregnancy, childbirth AND/OR puerperium | L172z | Other mat. venereal dis. in pregnancy/childbirth/puerp. NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 267883008 | Post-genitourinary infection reactive arthritis | N011. | Sexually acquired reactive arthropathy | DMWB | DMWB_CROSSMAP | 1.000 |
| 201474006 | Reactive arthritis of joint of shoulder region due to and following sexually transmitted disease | N0111 | Sexually acquired reactive arthropathy of shoulder region | DMWB | DMWB_CROSSMAP | 1.000 |
| 201477004 | Sexually acquired reactive arthritis of joint of hand | N0114 | Sexually acquired reactive arthropathy of the hand | DMWB | DMWB_CROSSMAP | 1.000 |
| 201478009 | Sexually acquired reactive arthropathy of the pelvic region and thigh | N0115 | Sexually acquired reactive arthropathy of the pelvis/thigh | DMWB | DMWB_CROSSMAP | 1.000 |
| 201480003 | Sexually acquired reactive arthropathy of the ankle and/or foot | N0117 | Sexually acquired reactive arthropathy of the ankle and foot | DMWB | DMWB_CROSSMAP | 1.000 |
| 201481004 | Reactive arthritis of multiple sites due to and following sexually transmitted disease | N011x | Sexually acquired reactive arthropathy of multiple sites | DMWB | DMWB_CROSSMAP | 1.000 |
| 201738001 | Post-infective arthropathy in syphilis | N0381 | Postinfective arthropathy in syphilis | DMWB | DMWB_CROSSMAP | 1.000 |
| 202933002 | Syphilitic bursitis | N2227 | Syphilitic bursitis | DMWB | DMWB_CROSSMAP | 1.000 |
| 206289001 | Congenital chlamydial pneumonia | Q3106 | Congenital pneumonia due to Chlamydia | DMWB | DMWB_CROSSMAP | 1.000 |
| 91576008 | Congenital herpes simplex infection | Q4020 | Congenital herpes simplex | DMWB | DMWB_CROSSMAP | 1.000 |
| 268842008 | Neonatal dacryocystitis or conjunctivitis caused by chlamydiae | Q4067 | Neonatal dacryocystitis or conjunctivitis due to chlamydiae | DMWB | DMWB_CROSSMAP | 1.000 |
| 499821000000104 | [D]Laboratory evidence of human immunodeficiency virus [HIV] | R109. | [D]Laboratory evidence of human immunodeficiency virus [HIV] | SEMANTIC | EXACT | 1.000 |
| 274684006 | False-positive serological test for syphilis | R156. | [D]False positive serological syphilis test | DMWB | DMWB_CROSSMAP | 1.000 |
| 442377003 | False positive complement fixation test for syphilis | R1560 | [D]False positive Wasserman test | DMWB | DMWB_CROSSMAP | 1.000 |
| 464851000000107 | [V]VD - venereal disease contact | ZV016 | [V]Contact with or exposure to venereal disease | SEMANTIC | TOKEN_OVERLAP | .750 |
| 428541000000106 | [V]Contact with and exposure to human immunodeficiency virus | ZV019 | [V]Contact with+exposure to human immunodeficiency virus | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 427921000000108 | [V]Asymptomatic human immunodeficiency virus infection status | ZV01A | [V]Asymptomatic human immunodeficency virus infection status | DMWB | DMWB_CROSSMAP | 1.000 |
| 428141000000103 | [V]Gonorrhoea carrier | ZV027 | [V]Gonorrhoea carrier | SEMANTIC | EXACT | 1.000 |
| 315675000 | [V]Other venereal disease carrier | ZV028 | [V]Other venereal disease carrier | SEMANTIC | EXACT | 1.000 |
| 427251000000107 | [V]Carrier of human T-lymphotropic virus type-1 infect | ZV029 | [V]Carrier of human T-lymphotropic virus type-1 infect | SEMANTIC | EXACT | 1.000 |
| 1090431000000102 | History of pelvic inflammatory disease | ZV138 | [V]Personal history of pelvic inflammatory disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 438998000 | Family history of human immunodeficiency virus infection | ZV19B | [V]Family history of human immunodefiency virus disease | DMWB | DMWB_CROSSMAP | 1.000 |
| 313077009 | HIV counseling | ZV6D4 | [V]Human immunodefiency virus counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 469321000000107 | [V]Screening for venereal disease | ZV745 | [V]Screening for venereal disease | SEMANTIC | EXACT | 1.000 |

### Termination of Pregnancy (166 codes)

| SNOMED ConceptID | SNOMED Preferred Term | ReadV2Code | ReadV2 Term | MappingSource | MatchLevel | MatchScore |
|---|---|---|---|---|---|---|
| 713651007 | History of pregnancy with abortive outcome | 1543 | H/O: abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 161756005 | H/O: 1 abortion | 15432 | H/O: 1 abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 161757001 | H/O: 2 abortions | 15433 | H/O: 2 abortions | DMWB | DMWB_CROSSMAP | 1.000 |
| 161758006 | H/O: 3 abortions | 15434 | H/O: 3 abortions | DMWB | DMWB_CROSSMAP | 1.000 |
| 161759003 | H/O: 4 abortions | 15435 | H/O: 4 abortions | DMWB | DMWB_CROSSMAP | 1.000 |
| 161760008 | H/O: 5 abortions | 15436 | H/O: 5 abortions | DMWB | DMWB_CROSSMAP | 1.000 |
| 161761007 | H/O: 6 abortions | 15437 | H/O: 6 abortions | DMWB | DMWB_CROSSMAP | 1.000 |
| 161762000 | H/O: abortion NOS | 1543Z | H/O: abortion NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 412758008 | History of medical termination of pregnancy | 1547 | H/O: medical termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 285409006 | Medical termination of pregnancy | 1547. | H/O: medical termination of pregnancy | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 707998009 | Assessment for termination of pregnancy | 389B. | Assessment for termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 10383002 | Counselling for termination of pregnancy | 6776 | Preg. termination counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 225326008 | Post-termination counseling | 67760 | Post-termination counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 225327004 | Pre-termination counseling | 67761 | Pre-termination counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 18302006 | Hysterotomy and termination of pregnancy | 7E066 | Hysterotomy and termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 265062002 | Dilation of cervix uteri and curettage of products of conception from uterus | 7E070 | Dilation cervix uteri & curettage products conception uterus | DMWB | DMWB_CROSSMAP | 1.000 |
| 386641000 | Therapeutic abortion procedure | 7E083 | Extraction of menses | DMWB | DMWB_CROSSMAP | 1.000 |
| 391897002 | Aspiration curettage of uterus for termination of pregnancy | 7E084 | Suction termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 29682007 | Dilatation and evacuation termination of pregnancy | 7E085 | Dilation of cervix and extraction termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 386639001 | Termination of pregnancy | 7E086 | Termination of pregnancy NEC | DMWB | DMWB_CROSSMAP | 1.000 |
| 176821001 | Dilation cervix uteri and curettage products of conception (& [termination] or [retained]) | 7E070 | Dilation cervix uteri & curettage products conception uterus | SEMANTIC | TOKEN_OVERLAP | .667 |
| 149997001 | Suction termination of pregnancy | 7E084 | Suction termination of pregnancy | SEMANTIC | EXACT | 1.000 |
| 176831008 | Termination of pregnancy NEC | 7E086 | Termination of pregnancy NEC | SEMANTIC | EXACT | 1.000 |
| 176849008 | Introduction of abortifacient into uterine cavity | 7E0B. | Introduction of abortifacient into uterine cavity | DMWB | DMWB_CROSSMAP | 1.000 |
| 176850008 | Intra-amniotic prostaglandin instillation | 7E0B0 | Intraamniotic injection of prostaglandin | DMWB | DMWB_CROSSMAP | 1.000 |
| 450678004 | Intraamniotic injection of abortifacient | 7E0B1 | Intraamniotic injection of abortifacient NEC | SEMANTIC | NORMALISED | .950 |
| 176852000 | Extra-amniotic prostaglandin instillation | 7E0B2 | Extraamniotic injection of prostaglandin | DMWB | DMWB_CROSSMAP | 1.000 |
| 450679007 | Extraamniotic injection of abortifacient | 7E0B3 | Extraamniotic injection of abortifacient NEC | SEMANTIC | NORMALISED | .950 |
| 176854004 | Insertion of prostaglandin abortifacient suppository | 7E0B4 | Insertion of prostaglandin abortifacient pessary | DMWB | DMWB_CROSSMAP | 1.000 |
| 285434006 | Insertion of abortifacient suppository | 7E0B5 | Insertion of abortifacient pessary NEC | DMWB | DMWB_CROSSMAP | 1.000 |
| 176857006 | Introduction of abortifacient into uterine cavity NOS | 7E0Bz | Introduction of abortifacient into uterine cavity NOS | SEMANTIC | EXACT | 1.000 |
| 265633004 | Selective destruction of foetus | 7F02. | Selective destruction of fetus | DMWB | DMWB_CROSSMAP | 1.000 |
| 177095006 | Early selective feticide | 7F020 | Early selective feticide | DMWB | DMWB_CROSSMAP | 1.000 |
| 177096007 | Late selective feticide | 7F021 | Late selective feticide | DMWB | DMWB_CROSSMAP | 1.000 |
| 562001000000102 | Other specified selective destruction of fetus | 7F02y | Other specified selective destruction of fetus | SEMANTIC | EXACT | 1.000 |
| 177099000 | Selective destruction of fetus NOS | 7F02z | Selective destruction of fetus NOS | SEMANTIC | EXACT | 1.000 |
| 906211000000103 | Destruction of fetus | 7F09. | Destruction of fetus | DMWB | DMWB_CROSSMAP | 1.000 |
| 1287687008 | Destruction of fetus | 7F09z | Unspecified destruction of fetus | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 386394001 | Pregnancy termination care | 8Cg.. | Pregnancy termination care | DMWB | DMWB_CROSSMAP | 1.000 |
| 183606009 | Referral for counseling for termination of pregnancy | 8H7W. | Refer to TOP counselling | DMWB | DMWB_CROSSMAP | 1.000 |
| 769411000000104 | Self referral to termination of pregnancy service | 8Hh3. | Self referral to termination of pregnancy service | DMWB | DMWB_CROSSMAP | 1.000 |
| 415262008 | Referral for termination of pregnancy | 8HHV. | Referral for termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 184005004 | Requests pregnancy termination | 8M6.. | Requests pregnancy termination | DMWB | DMWB_CROSSMAP | 1.000 |
| 9391000000101 | HSA1 therapeutic abortion green form | 956.. | Form A - therapeutic abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 9401000000103 | HSA1 form eligible | 9561 | Form A - eligible | DMWB | DMWB_CROSSMAP | 1.000 |
| 9411000000101 | HSA1 form signed | 9562 | Form A - signed | DMWB | DMWB_CROSSMAP | 1.000 |
| 9421000000107 | HSA1 form refused to sign | 9563 | Form A - refused to sign | DMWB | DMWB_CROSSMAP | 1.000 |
| 10671000000104 | Form A therapeutic abortion - refused to sign | 9563. | Form A - refused to sign | SEMANTIC | TOKEN_OVERLAP | .600 |
| 13961000000108 | HSA1 form status | 956Z. | Form A - NOS | DMWB | DMWB_CROSSMAP | 1.000 |
| 310506006 | Reason for termination of pregnancy | 9Ea.. | Reason for termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 185020000 | Risk to the life of the pregnant woman greater than if the pregnancy was terminated | 9Ea0. | Risk life pregnant woman greater than if pregnancy terminatd | SEMANTIC | TOKEN_OVERLAP | .700 |
| 363681007 | Pregnancy with abortive outcome | L0... | Pregnancy with abortive outcome | DMWB | DMWB_CROSSMAP | 1.000 |
| 267294003 | Abortion - spontaneous | L040. | Spontaneous abortion unspecified | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 156071003 | Abortion: [spontaneous] or [complete] or [incomplete] | L042. | Spontaneous abortion complete | SEMANTIC | TOKEN_OVERLAP | .750 |
| 669831000000102 | Complete spontaneous abortion with complication NOS | L042x | Complete spontaneous abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 672481000000104 | Complete spontaneous abortion NOS | L042z | Complete spontaneous abortion NOS | SEMANTIC | EXACT | 1.000 |
| 18119004 | Abortion complicated by embolism | L0432 | Unspecified inevitable abortion complicated by embolism | SEMANTIC | TOKEN_OVERLAP | .750 |
| 51830007 | Abortion without complication | L043z | Unspecified inevitable abortion without complication | SEMANTIC | TOKEN_OVERLAP | .750 |
| 39406005 | Legally induced abortion - TOP | L05.. | Legally induced abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 198691008 | Legal abortion unspecified | L050. | Legal abortion unspecified | SEMANTIC | EXACT | 1.000 |
| 672511000000105 | Unspecified legal abortion with genital tract or pelvic infection | L0500 | Unspecified legal abortion + genital tract/pelvic infection | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 58071009 | Legal termination of pregnancy complicated by delayed and/or excessive hemorrhage | L0501 | Unspecified legal abortion + delayed/excessive haemorrhage | DMWB | DMWB_CROSSMAP | 1.000 |
| 626771000000105 | Unspecified legal abortion with damage to pelvic organs or tissues | L0502 | Unspecified legal abortion + damage to pelvic organs/tissues | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198695004 | Unspecified legal abortion with renal failure | L0503 | Unspecified legal abortion with renal failure | SEMANTIC | EXACT | 1.000 |
| 198696003 | Unspecified legal abortion with metabolic disorder | L0504 | Unspecified legal abortion with metabolic disorder | SEMANTIC | EXACT | 1.000 |
| 198697007 | Unspecified legal abortion with shock | L0505 | Unspecified legal abortion with shock | SEMANTIC | EXACT | 1.000 |
| 198698002 | Unspecified legal abortion with embolism | L0506 | Unspecified legal abortion with embolism | SEMANTIC | EXACT | 1.000 |
| 19123002 | Legal abortion with specified complication, NEC | L050w | Unspecified legal abortion with other specified complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198701005 | Unspecified legal abortion with complication NOS | L050x | Unspecified legal abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 34500003 | Legal termination of pregnancy without complication | L050y | Unspecified legal abortion with no mention of complication | DMWB | DMWB_CROSSMAP | 1.000 |
| 613991000000109 | Unspecified legal abortion NOS | L050z | Unspecified legal abortion NOS | SEMANTIC | EXACT | 1.000 |
| 198782001 | Unspecified incomplete abortion with genital tract or pelvic infection | L0510 | Incomplete legal abortion + genital tract/pelvic infection | SEMANTIC | TOKEN_OVERLAP | .857 |
| 579571000000102 | Unspecified incomplete abortion with damage to pelvic organs or tissues | L0512 | Incomplete legal abortion + damage to pelvic organs/tissues | SEMANTIC | TOKEN_OVERLAP | .857 |
| 749781000000109 | Incomplete medical abortion | L0517 | Incomplete medical abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 614001000000104 | Incomplete legal abortion with other specified complication | L051w | Incomplete legal abortion with other specified complication | SEMANTIC | EXACT | 1.000 |
| 599091000000102 | Incomplete legal abortion with complication NOS | L051x | Incomplete legal abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 198715007 | Incomplete legal abortion with no mention of complication | L051y | Incomplete legal abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 198716008 | Incomplete legal abortion NOS | L051z | Incomplete legal abortion NOS | SEMANTIC | EXACT | 1.000 |
| 267194005 | Complete legal termination of pregnancy | L052. | Legal abortion complete | DMWB | DMWB_CROSSMAP | 1.000 |
| 198794005 | Unspecified complete abortion with genital tract or pelvic infection | L0520 | Complete legal abortion + genital tract or pelvic infection | SEMANTIC | TOKEN_OVERLAP | .857 |
| 198693006 | Unspecified legal abortion with delayed or excessive haemorrhage | L0521 | Complete legal abortion with delayed/excessive haemorrhage | SEMANTIC | TOKEN_OVERLAP | .833 |
| 698441000000100 | Unspecified complete abortion with damage to pelvic organs or tissues | L0522 | Complete legal abortion + damage to pelvic organs or tissues | SEMANTIC | TOKEN_OVERLAP | .857 |
| 599111000000107 | Complete legal abortion with other specified complication | L052w | Complete legal abortion with other specified complication | SEMANTIC | EXACT | 1.000 |
| 592131000000109 | Complete legal abortion with complication NOS | L052x | Complete legal abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 198727005 | Complete legal abortion with no mention of complication | L052y | Complete legal abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 198728000 | Complete legal abortion NOS | L052z | Complete legal abortion NOS | SEMANTIC | EXACT | 1.000 |
| 599131000000104 | Legally induced abortion NOS | L05z. | Legally induced abortion NOS | SEMANTIC | EXACT | 1.000 |
| 49632008 | Illegal termination of pregnancy | L06.. | Illegally induced abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 198731004 | Illegal abortion unspecified | L060. | Illegal abortion unspecified | SEMANTIC | EXACT | 1.000 |
| 599151000000106 | Unspecified illegal abortion with genital tract or pelvic infection | L0600 | Unspec illegal abortion + genital tract or pelvic infection | SEMANTIC | TOKEN_OVERLAP | .857 |
| 198735008 | Unspecified illegal abortion with renal failure | L0603 | Unspecified illegal abortion with renal failure | SEMANTIC | EXACT | 1.000 |
| 198736009 | Unspecified illegal abortion with metabolic disorder | L0604 | Unspecified illegal abortion with metabolic disorder | SEMANTIC | EXACT | 1.000 |
| 198737000 | Unspecified illegal abortion with shock | L0605 | Unspecified illegal abortion with shock | SEMANTIC | EXACT | 1.000 |
| 198738005 | Unspecified illegal abortion with embolism | L0606 | Unspecified illegal abortion with embolism | SEMANTIC | EXACT | 1.000 |
| 22442009 | Illegal abortion with specified complication, NEC | L060w | Unspecified illegal abortion + other specified complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 660151000000107 | Unspecified illegal abortion with no mention of complication | L060y | Unspecified illegal abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 198742008 | Unspecified illegal abortion NOS | L060z | Unspecified illegal abortion NOS | SEMANTIC | EXACT | 1.000 |
| 198783006 | Unspecified incomplete abortion with delayed or excessive haemorrhage | L0611 | Incomplete illegal abortion + delayed/excessive haemorrhage | SEMANTIC | TOKEN_OVERLAP | .833 |
| 599191000000103 | Incomplete illegal abortion with other specified complication | L061w | Incomplete illegal abortion + other specified complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198752007 | Incomplete illegal abortion with complication NOS | L061x | Incomplete illegal abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 198753002 | Incomplete illegal abortion with no mention of complication | L061y | Incomplete illegal abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 198754008 | Incomplete illegal abortion NOS | L061z | Incomplete illegal abortion NOS | SEMANTIC | EXACT | 1.000 |
| 198755009 | Illegal termination of pregnancy, complete | L062. | Illegal abortion complete | DMWB | DMWB_CROSSMAP | 1.000 |
| 198763005 | Complete illegal abortion with other specified complication | L062w | Complete illegal abortion with other specified complication | SEMANTIC | EXACT | 1.000 |
| 198764004 | Complete illegal abortion with complication NOS | L062x | Complete illegal abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 529611000000105 | Complete illegal abortion with no mention of complication | L062y | Complete illegal abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 198766002 | Complete illegal abortion NOS | L062z | Complete illegal abortion NOS | SEMANTIC | EXACT | 1.000 |
| 198767006 | Illegally induced abortion NOS | L06z. | Illegally induced abortion NOS | SEMANTIC | EXACT | 1.000 |
| 70317007 | Abortion | L07.. | Unspecified abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 198768001 | Unspecified abortion | L070. | Unspecified abortion | SEMANTIC | EXACT | 1.000 |
| 198770005 | Unspecified abortion with genital tract or pelvic infection | L0700 | Unspecified abortion with genital tract or pelvic infection | SEMANTIC | EXACT | 1.000 |
| 198771009 | Unspecified abortion with delayed or excessive haemorrhage | L0701 | Unspecified abortion with delayed or excessive haemorrhage | SEMANTIC | EXACT | 1.000 |
| 659001000000109 | Unspecified abortion with damage to pelvic organs or tissues | L0702 | Unspecified abortion with damage to pelvic organs or tissues | SEMANTIC | EXACT | 1.000 |
| 587081000000108 | Unspecified abortion with renal failure | L0703 | Unspecified abortion with renal failure | SEMANTIC | EXACT | 1.000 |
| 587071000000106 | Unspecified abortion with metabolic disorder | L0704 | Unspecified abortion with metabolic disorder | SEMANTIC | EXACT | 1.000 |
| 198775000 | Unspecified abortion with shock | L0705 | Unspecified abortion with shock | SEMANTIC | EXACT | 1.000 |
| 639891000000108 | Unspecified abortion with embolism | L0706 | Unspecified abortion with embolism | SEMANTIC | EXACT | 1.000 |
| 2787008 | Unspecified abortion with specified complication, NEC | L070w | Unspecified abortion with other specified complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198778003 | Unspecified abortion with complication NOS | L070x | Unspecified abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 198779006 | Unspecified abortion with no mention of complication | L070y | Unspecified abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 639931000000103 | Unspecified abortion NOS | L070z | Unspecified abortion NOS | SEMANTIC | EXACT | 1.000 |
| 639941000000107 | Unspecified abortion incomplete | L071. | Unspecified abortion incomplete | SEMANTIC | EXACT | 1.000 |
| 632901000000101 | Unspecified incomplete abortion with renal failure | L0713 | Unspecified incomplete abortion with renal failure | SEMANTIC | EXACT | 1.000 |
| 602701000000107 | Unspecified incomplete abortion with metabolic disorder | L0714 | Unspecified incomplete abortion with metabolic disorder | SEMANTIC | EXACT | 1.000 |
| 198787007 | Unspecified incomplete abortion with shock | L0715 | Unspecified incomplete abortion with shock | SEMANTIC | EXACT | 1.000 |
| 602721000000103 | Unspecified incomplete abortion with embolism | L0716 | Unspecified incomplete abortion with embolism | SEMANTIC | EXACT | 1.000 |
| 198790001 | Unspecified incomplete abortion with complication NOS | L071x | Unspecified incomplete abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 198791002 | Unspecified incomplete abortion with no mention of complication | L071y | Unspecified incomplete abortion + no mention of complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198792009 | Unspecified incomplete abortion NOS | L071z | Unspecified incomplete abortion NOS | SEMANTIC | EXACT | 1.000 |
| 644601000000100 | Unspecified abortion complete | L072. | Unspecified abortion complete | SEMANTIC | EXACT | 1.000 |
| 198795006 | Unspecified complete abortion with delayed or excessive haemorrhage | L0721 | Unspecified complete abortion +delayed/excessive haemorrhage | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198797003 | Unspecified complete abortion with renal failure | L0723 | Unspecified complete abortion with renal failure | SEMANTIC | EXACT | 1.000 |
| 198798008 | Unspecified complete abortion with metabolic disorder | L0724 | Unspecified complete abortion with metabolic disorder | SEMANTIC | EXACT | 1.000 |
| 626811000000105 | Unspecified complete abortion with shock | L0725 | Unspecified complete abortion with shock | SEMANTIC | EXACT | 1.000 |
| 198800001 | Unspecified complete abortion with embolism | L0726 | Unspecified complete abortion with embolism | SEMANTIC | EXACT | 1.000 |
| 698451000000102 | Unspecified complete abortion with other specified complication | L072w | Unspecified complete abortion + other specified complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198802009 | Unspecified complete abortion with complication NOS | L072x | Unspecified complete abortion with complication NOS | SEMANTIC | EXACT | 1.000 |
| 700141000000102 | Unspecified complete abortion with no mention of complication | L072y | Unspecified complete abortion + no mention of complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 592141000000100 | Unspecified complete abortion NOS | L072z | Unspecified complete abortion NOS | SEMANTIC | EXACT | 1.000 |
| 49416000 | Failed attempted termination of pregnancy | L08.. | Failed attempted abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 390431000000101 | [X]Other and unspecified failed induced abortion, complicated by genital tract and pelvic infection | L080. | Failed attempted abortion + genital tract/pelvic infection | SEMANTIC | TOKEN_OVERLAP | .667 |
| 409481000000104 | [X]Other and unspecified failed induced abortion, complicated by delayed or excessive haemorrhage | L081. | Failed attempted abortion + delayed or excessive haemorrhage | SEMANTIC | TOKEN_OVERLAP | .625 |
| 42755004 | Failed attempted abortion with pyaemic embolism | L086. | Failed attempted abortion with embolism | SEMANTIC | TOKEN_OVERLAP | .800 |
| 56083002 | Failed attempted abortion with specified complication, NEC | L08w. | Failed attempted abortion with other specified complication | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198816004 | Failed attempted abortion with no mention of complication | L08y. | Failed attempted abortion with no mention of complication | SEMANTIC | EXACT | 1.000 |
| 198817008 | Failed attempted abortion NOS | L08z. | Failed attempted abortion NOS | SEMANTIC | EXACT | 1.000 |
| 198818003 | Complications following abortion and ectopic and molar pregnancies | L09.. | Complications following abortion/ectopic/molar pregnancies | DMWB | DMWB_CROSSMAP | 1.000 |
| 198823003 | Salpingitis following abortive pregnancy | L0903 | Salpingitis following abortive pregnancy | SEMANTIC | EXACT | 1.000 |
| 198824009 | Salpingo-oophoritis following abortive pregnancy | L0904 | Salpingo-oophoritis following abortive pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 198825005 | Sepsis NOS following abortion and ectopic and molar pregnancy | L090y | Sepsis NOS following abortion/ectopic/molar pregnancy | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198837007 | Periurethral tissue damage following abortive pregnancy | L0924 | Periurethral tissue damage following abortive pregnancy | SEMANTIC | EXACT | 1.000 |
| 609472002 | Induced termination of pregnancy complicated by acute renal failure with oliguria | L0930 | Oliguria following abortive pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 198848000 | Metabolic disorder following abortive pregnancy | L094. | Metabolic disorder following abortive pregnancy | SEMANTIC | EXACT | 1.000 |
| 198854004 | Fat embolism following abortive pregnancy | L0963 | Fat embolism following abortive pregnancy | SEMANTIC | EXACT | 1.000 |
| 198860004 | Readmission (NHS codes): [abortive pregnancy] or [RPOC] | L097. | Readmission for abortive pregnancy (NHS codes) | SEMANTIC | TOKEN_OVERLAP | .833 |
| 198862007 | Readmission for retained products of conception, legal termination of pregnancy | L0971 | Readmission for retained produc of concept, legal abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 198863002 | Readmission for retained products of conception, illegal termination of pregnancy | L0972 | Readmission for retained produc of concept, illegal abortion | DMWB | DMWB_CROSSMAP | 1.000 |
| 198872005 | Complication NOS following abortion and ectopic and molar pregnancy | L09z. | Complication NOS following abortion/ectopic/molar pregnancy | SEMANTIC | TOKEN_OVERLAP | 1.000 |
| 198873000 | Failed attempted abortion | L0A.. | Failed attempted abortion | SEMANTIC | EXACT | 1.000 |
| 198878009 | Failed medical termination of pregnancy, without complication | L0A4. | Failed medical abortion, without complication | DMWB | DMWB_CROSSMAP | 1.000 |
| 200483009 | [X]Other abortion | Lyu02 | [X]Other abortion | SEMANTIC | EXACT | 1.000 |
| 200488000 | [X]Other and unspecified failed induced abortion, complicated by embolism | Lyu06 | [X]Other+unspcf failed induced abortion,complicated/embolism | SEMANTIC | TOKEN_OVERLAP | .833 |
| 609492009 | Termination of pregnancy without complication | Lyu08 | [X]Other+unspcf failed induced abortion,without complication | DMWB | DMWB_CROSSMAP | 1.000 |
| 67313008 | Fetal death due to termination of pregnancy | Q486. | Fetal death due to termination of pregnancy | DMWB | DMWB_CROSSMAP | 1.000 |
| 315910004 | [V]Pregnancy with history of abortion | ZV232 | [V]Pregnancy with history of abortion | SEMANTIC | EXACT | 1.000 |
| 439741000000107 | [V]Admission for administration of abortifacient | ZV25B | [V]Admission for administration of abortifacient | DMWB | DMWB_CROSSMAP | 1.000 |
