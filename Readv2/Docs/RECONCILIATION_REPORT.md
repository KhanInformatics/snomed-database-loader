# RCGP Sensitive Code list vs Albasoft Sensitive Code Reconciliation Report

## 1. Background

Three independent code lists govern Read V2 sensitive code suppression in Scottish GP systems:

| List | Source | Scope | Key Table |
|---|---|---|---|
| **RCGP Data Sharing Exclusions** | Royal College of GPs via NHS Digital SNOMED CT refsets, mapped to Read V2 through DMWB crossmap + semantic matching | National (England-origin, applicable UK-wide) | `RCGPSNOMEDtoREADv2` |
| **Albasoft Sensitive Code List** | Albasoft Ltd, curated for Scottish GP system suppliers | Scotland-specific | `AlbasoftSensitiveCodeList` |
| **LRPCD (Legally Restricted Patient Confidential Data)** | NHS England via TRUD (Technology Reference data Update Distribution), v4.8, last updated September 2022 | National (England) - covers STD and Assisted Fertilisation categories only | `LRPCD_STD`, `LRPCD_IVF` |

All three lists exist in the `[READv2]` database and resolve terms from the same Read V2 dictionary. They serve the same purpose - preventing sensitive clinical data from being shared - but were compiled independently using different methodologies.

The LRPCD reference data from TRUD represents the official NHS England list of legally restricted Read V2 codes. It was last updated in September 2022 and covers two of the four sensitivity categories: Sexually Transmitted Disease (752 codes) and Assisted Fertilisation (52 codes). It does not include codes for Gender Related Issues or Termination of Pregnancy.

---

## 2. Current State

### Table Profiles

| Property | RCGPSNOMEDtoREADv2 | AlbasoftSensitiveCodeList | LRPCD_STD | LRPCD_IVF |
|---|---|---|---|---|
| Total rows | 819 | 487 | 752 | 52 |
| Unique Read V2 codes | 819 (deduplicated) | 487 | 752 | 52 |
| Derivation | SNOMED CT refsets → DMWB crossmap + semantic matching | Directly curated Read V2 codes | NHS England TRUD reference data | NHS England TRUD reference data |
| SNOMED linkage | Yes (ConceptID, FSN, Preferred Term) | No | No (Read V2 codes only) | No (Read V2 codes only) |
| Provenance tracking | Yes (MappingSource, MatchLevel, MatchScore) | No | TRUD v4.8, September 2022 | TRUD v4.8, September 2022 |
| Categories | 4 exclusion categories (STD, ToP, Gender, Assisted Fertilisation) | Not categorised | Sexually Transmitted Disease | Assisted Fertilisation |
| Term source | Readv2Lookup / DMWB | Readv2Lookup | TRUD (terms match Readv2Lookup; differences are 60-char truncation only) | TRUD (terms match Readv2Lookup; differences are 60-char truncation only) |

### Overlap Analysis

The `AnalyseRCGPvsAlbasoft.sql` script produces a Venn-style breakdown of the original RCGP vs Albasoft comparison. With the LRPCD integration, the combined table now includes codes from all three sources:

### Source Breakdown (SensitiveCodeListCombined)

| CodeSource | Count | Sources |
|---:|---:|---|
| RCGP+LRPCD | 329 | In RCGP and LRPCD, not Albasoft |
| ALL_THREE | 248 | In RCGP, Albasoft, and LRPCD |
| LRPCD_ONLY | 194 | In LRPCD only |
| RCGP_ONLY | 162 | In RCGP only |
| ALBASOFT_ONLY | 128 | In Albasoft only |
| RCGP+ALBASOFT | 80 | In RCGP and Albasoft, not LRPCD |
| ALBASOFT+LRPCD | 33 | In Albasoft and LRPCD, not RCGP |
| **Total** | **1,174** | |

Of the 804 LRPCD codes (752 STD + 52 IVF), 610 (76%) were already present in the RCGP and/or Albasoft lists. The remaining 194 codes (24%) are unique to the LRPCD reference data and were added as new entries.

### LRPCD Overlap with Existing Sources

| LRPCD Source | In Both | RCGP Only | Albasoft Only | LRPCD Only | Total |
|---|---:|---:|---:|---:|---:|
| STD | 230 | 303 | 30 | 189 | 752 |
| IVF | 18 | 26 | 3 | 5 | 52 |
| **Total** | **248** | **329** | **33** | **194** | **804** |

### Breakdown by Exclusion Category

| Exclusion Category | Total | ALL_THREE | RCGP+ALBASOFT | RCGP+LRPCD | ALBASOFT+LRPCD | RCGP_ONLY | ALBASOFT_ONLY | LRPCD_ONLY |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Sexually Transmitted Disease | 768 | 230 | 5 | 303 | 0 | 41 | 0 | 189 |
| Termination of Pregnancy | 163 | 0 | 72 | 0 | 0 | 91 | 0 | 0 |
| Uncategorised (Albasoft-only) | 161 | 0 | 0 | 0 | 33 | 0 | 128 | 0 |
| Assisted Fertilisation | 52 | 18 | 3 | 26 | 0 | 0 | 0 | 5 |
| Gender Related Issues | 30 | 0 | 0 | 0 | 0 | 30 | 0 | 0 |
| **Combined Total** | **1,174** | **248** | **80** | **329** | **33** | **162** | **128** | **194** |

### Mapping Source Breakdown

| MappingSource | Count | Description |
|---|---:|---|
| LRPCD | 804 | Codes validated against TRUD LRPCD reference data |
| DMWB | 125 | Mapped via DMWB official crossmap |
| SEMANTIC | 117 | Matched via semantic matching engine |
| _(not set)_ | 128 | Albasoft-only codes with no SNOMED mapping |
| **Total** | **1,174** | |

### Key Findings

- **LRPCD Integration**: 804 of the 1,174 codes (68%) are validated by the official NHS England LRPCD reference data from TRUD. Of these, 610 were already present from RCGP/Albasoft sources; 194 are unique to LRPCD and represent previously unidentified sensitive codes.
- **LRPCD Coverage Gaps**: The LRPCD reference data covers only STD (752 codes) and Assisted Fertilisation (52 codes). It does **not** include Gender Related Issues (30 codes) or Termination of Pregnancy (163 codes) - these categories remain covered only by the RCGP refsets.
- **Gender Related Issues**: Zero overlap with both Albasoft and LRPCD - none of the 30 RCGP gender codes appear in either list. This is the most significant coverage gap.
- **Sexually Transmitted Disease**: Largest category with 768 codes. 189 are LRPCD_ONLY. 533 codes (69%) appear in LRPCD (ALL_THREE 230 + RCGP+LRPCD 303).
- **Termination of Pregnancy**: 163 codes, 91 RCGP_ONLY (56%). Not covered by LRPCD at all.
- **Assisted Fertilisation**: 52 codes, 5 LRPCD_ONLY. 44 of 52 (85%) appear in LRPCD.
- **128 Albasoft-only codes** have no RCGP or LRPCD equivalent and are uncategorised. A further 33 Albasoft codes are also validated by LRPCD (ALBASOFT+LRPCD).

| Segment | Description |
|---|---|
| **ALL_THREE** | Codes present in RCGP, Albasoft, and LRPCD - highest-confidence consensus codes |
| **RCGP+ALBASOFT** | Codes in both RCGP and Albasoft but not LRPCD |
| **RCGP+LRPCD** | Codes in both RCGP and LRPCD but not Albasoft |
| **ALBASOFT+LRPCD** | Codes in both Albasoft and LRPCD but not RCGP |
| **RCGP_ONLY** | Codes derived from SNOMED refsets only - not in Albasoft or LRPCD |
| **ALBASOFT_ONLY** | Codes curated by Albasoft only - may represent Scotland-specific coding practices |
| **LRPCD_ONLY** | Codes from NHS England LRPCD (TRUD v4.8) only - previously unidentified sensitive codes |



## 3. Key Observations

### 3.1 Different Origins, Same Goal

The RCGP list is **top-down**: start from SNOMED CT clinical concepts, then find their Read V2 equivalents. The Albasoft list is **bottom-up**: directly curated Read V2 codes known to be sensitive from GP system usage. The LRPCD list is **regulatory**: the official NHS England list of legally restricted codes maintained via TRUD. This means:

- RCGP captures concepts that *should* be sensitive based on clinical ontology
- Albasoft captures codes that *are* sensitive based on real-world GP coding practice
- LRPCD captures codes that are *legally restricted* under NHS England data sharing regulations

### 3.2 LRPCD as Authoritative Validation

The LRPCD reference data from TRUD (v4.8, September 2022) provides an independent, authoritative baseline for validating the combined code list. Key findings:

- **75% overlap**: 606 of 804 LRPCD codes were already present in the RCGP and/or Albasoft lists, confirming that the existing reconciliation process captured the majority of legally restricted codes
- **198 new codes**: 25% of LRPCD codes were not in either RCGP or Albasoft - these have been added with `CodeSource = 'LRPCD_ONLY'` and `ReviewStatus = 'PENDING'`
- **Scope limitation**: LRPCD covers only STD and Assisted Fertilisation. Gender Related Issues and Termination of Pregnancy are not included in the TRUD reference data, which means 196 codes (30 Gender + 166 ToP) have no LRPCD validation
- **Term consistency**: All LRPCD terms match the Readv2Lookup dictionary; any differences are due to the 60-character truncation limit in Readv2Lookup
- **33 Albasoft-only codes** also appear in LRPCD, providing independent confirmation that these codes are genuinely sensitive despite lacking an RCGP SNOMED refset mapping

### 3.3 The Unmapped Gap

The RCGP SNOMED refsets contain 2,834 concepts, but only 820 could be mapped to Read V2 (29%). The remaining 2,014 concepts either:
- Have no Read V2 equivalent (SNOMED-only concepts)
- Exist at a different granularity than Read V2 supports
- Were removed during QA as false matches

Some of these unmapped SNOMED concepts may correspond to Albasoft codes that weren't caught by the mapping algorithm.

### 3.4 RCGP Codes Not in Albasoft

These represent the most important findings - potential **gaps in the Albasoft suppression list**. If a code is clinically sensitive enough to be in the RCGP national exclusion refset but isn't in the Albasoft list, it could be leaking sensitive data in Scottish systems.

Priority assessment depends on:
- **MappingSource**: DMWB-mapped codes (official crossmap) are higher confidence than SEMANTIC matches
- **MatchLevel**: EXACT and DMWB_CROSSMAP are reliable; TOKEN_OVERLAP at lower scores should be reviewed
- **Exclusion Category**: STD and Gender codes may carry higher patient sensitivity risk

### 3.5 Albasoft Codes Not in RCGP

These are codes Albasoft considers sensitive but which don't appear in any RCGP SNOMED exclusion refset. Possible reasons:
- The SNOMED refsets don't cover the concept (gap in the national refset)
- The code maps to a SNOMED concept that's in the refset but our mapping didn't pick it up
- Albasoft applies a broader definition of sensitivity

---

## 4. Reconciliation Strategy

### Phase 1: Validate the Overlap

**Objective**: Confirm that overlapping codes have consistent treatment.

1. Run `AnalyseRCGPvsAlbasoft.sql` sections 1–5 to get exact counts
2. Verify the "In Both" codes are genuine matches (not dot-padding artefacts)
3. Record the baseline numbers as the reconciliation starting point

### Phase 2: Triage RCGP-Only Codes

**Objective**: Determine which RCGP-only codes should be added to the Albasoft list.

| Priority | Criteria | Action |
|---|---|---|
| **High** | DMWB_CROSSMAP source, active concept, STD/Gender category | Strong candidate for Albasoft addition - official crossmap, high sensitivity |
| **Medium** | SEMANTIC EXACT match, active concept | Review the Read V2 term; if clearly sensitive, add to Albasoft |
| **Low** | SEMANTIC TOKEN_OVERLAP, MatchScore < 0.8 | Clinical review required before adding - lower mapping confidence |
| **Exclude** | Inactive concept (`ConceptIsActive = 0`) | Do not add - concept is retired in SNOMED |

**Process**:
1. Export RCGP-only codes from section 3 of the analysis script
2. Sort by priority tier
3. Clinical review of High and Medium tiers
4. Submit additions to Albasoft for inclusion

### Phase 3: Investigate Albasoft-Only Codes

**Objective**: Determine whether Albasoft-only codes represent RCGP refset gaps or legitimate divergence.

1. Export Albasoft-only codes from section 4 of the analysis script
2. For each code, check whether a SNOMED equivalent exists:
   - Query `DMWB_NHS_READ_RCT` for a reverse crossmap (Read V2 → SNOMED CT)
   - If a SNOMED concept is found, check whether it's in any of the 4 exclusion refsets
3. Categorise results:

| Finding | Interpretation | Action |
|---|---|---|
| SNOMED concept exists and is in a refset | Our mapping missed it (mapping gap) | Fix the mapping - add to `RCGPSNOMEDtoREADv2` |
| SNOMED concept exists but not in any refset | RCGP refset gap | Report to NHS Digital / RCGP for potential refset update |
| No SNOMED equivalent | Read V2-only concept | Retain in Albasoft; note as Scotland-specific |

### Phase 4: Build a Unified Codelist

**Objective**: Create a single authoritative `SensitiveCodeListCombined` table.

```sql
CREATE TABLE dbo.SensitiveCodeListCombined (
    ReadV2Code           VARCHAR(10)    NOT NULL,
    ReadV2Term           NVARCHAR(200)  NULL,
    Exclusion_Category   NVARCHAR(60)   NULL,
    SNOMED_ConceptID     VARCHAR(20)    NULL,
    SNOMED_PreferredTerm NVARCHAR(500)  NULL,
    CodeSource           VARCHAR(20)    NOT NULL,  -- BOTH, RCGP_ONLY, ALBASOFT_ONLY, LRPCD_ONLY
    MappingSource        VARCHAR(20)    NULL,       -- DMWB, SEMANTIC, LRPCD
    MatchLevel           VARCHAR(20)    NULL,
    MatchScore           DECIMAL(4,3)   NULL,
    ReviewStatus         VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    ReviewNotes          NVARCHAR(500)  NULL,
    LRPCD_Source         VARCHAR(10)    NULL,       -- STD, IVF, or NULL if not in LRPCD
    PRIMARY KEY (ReadV2Code)
);
```

Section 8 of the analysis script already produces the RCGP/Albasoft union. The LRPCD codes were integrated subsequently by:
1. Adding all LRPCD codes not already present as `CodeSource = 'LRPCD_ONLY'`
2. Adding the `LRPCD_Source` column to track whether each code originates from LRPCD_STD, LRPCD_IVF, or neither
3. Setting `MappingSource = 'LRPCD'` for all 804 codes present in the LRPCD reference data
4. Annotating `ReviewNotes` on the 606 pre-existing codes to record their LRPCD validation


## 5. Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| Sensitive codes missing from suppression list | Patient data shared inappropriately | Reconcile RCGP-only codes into Albasoft (Phase 2) |
| Over-suppression (false positives) | Legitimate clinical data withheld | Clinical review before adding codes; reject TOKEN_OVERLAP matches with low scores |
| SEMANTIC mapping errors remain | Wrong codes in the unified list | Provenance columns allow filtering; only DMWB and EXACT go through without review |
| Albasoft-only codes with no SNOMED link | Cannot track sensitivity rationale long-term | Reverse-map via DMWB where possible (Phase 3) |
| List drift over time | Lists diverge again after reconciliation | Automated quarterly reconciliation (Phase 5) |

---

## 6. Recommended Immediate Actions


1. **~~Create the combined table~~** - ✅ Done. `SensitiveCodeListCombined` created with 1,174 rows from RCGP, Albasoft, and LRPCD sources
2. **~~Integrate LRPCD reference data~~** - ✅ Done. All 804 LRPCD codes (752 STD + 52 IVF) integrated from TRUD v4.8 (September 2022)
3. **Schedule clinical review** - High and Medium priority RCGP-only codes need sign-off before being added to production suppression
4. **Review LRPCD-only codes** - 198 codes unique to LRPCD need clinical review to assign appropriate SNOMED mappings
5. **Address Gender/ToP gap** - 196 codes across Gender Related Issues (30) and Termination of Pregnancy (166) have no LRPCD validation - consider whether additional authoritative sources exist

---

## 7. Scripts Reference

| Script | Purpose |
|---|---|
| `Queries/AnalyseRCGPvsAlbasoft.sql` | Full analysis: overlap, differences, breakdowns, combined union |
| `Queries/CreateSensitiveCodeListCombined.sql` | Creates and populates `SensitiveCodeListCombined` table |
| `Queries/RCGPExclusion.sql` | Creates and populates `RCGPSNOMEDtoREADv2` table |
| `Readv2/Scripts/Import-AlbasoftToSqlServer.py` | Imports Albasoft list into `AlbasoftSensitiveCodeList` |
| `Readv2/Scripts/_import_exclusions.py` | Imports DataSharingExclusions.xlsx into SQL mapping table |
| `Readv2/Scripts/_match_unmapped.py` | Three-tier semantic matching engine |
| `Readv2/Scripts/_update_mapping_source.py` | Adds provenance columns (MappingSource, MatchLevel, MatchScore) |
| `Readv2/Docs/MAPPING_STRATEGY.md` | Full mapping methodology and QA history |

### LRPCD Reference Data

| File | Purpose |
|---|---|
| `Legally Restricted Codes/LRPCD_STD_v4.8_ClusterMembers_RCT_20160412143944.txt` | LRPCD STD cluster - 752 Read V2 codes for Sexually Transmitted Disease |
| `Legally Restricted Codes/LRPCD_IVF_v4.8_ClusterMembers_RCT_20160406165024.txt` | LRPCD IVF cluster - 52 Read V2 codes for Assisted Fertilisation |
| `Legally Restricted Codes/LRPCD 4.8.1 Release Notes 20220801.txt` | LRPCD v4.8.1 release notes (September 2022 update) |

---

## Appendix: Final Combined Sensitive Code List

**1,174 unique Read V2 codes** from SensitiveCodeListCombined, grouped by Exclusion Category.

### (Uncategorised) (161 codes)

| ReadV2Code | ReadV2 Term | SNOMED ConceptID | CodeSource | MappingSource | LRPCD |
|---|---|---|---|---|---|
| 133.. | Personal status |  | ALBASOFT_ONLY |  |  |
| 1331 | Single |  | ALBASOFT_ONLY |  |  |
| 1332 | Married |  | ALBASOFT_ONLY |  |  |
| 1333 | Separated |  | ALBASOFT_ONLY |  |  |
| 1334 | Divorced |  | ALBASOFT_ONLY |  |  |
| 1335 | Widowed |  | ALBASOFT_ONLY |  |  |
| 1336 | Cohabiting |  | ALBASOFT_ONLY |  |  |
| 1337 | Adopted |  | ALBASOFT_ONLY |  |  |
| 1338 | Fostered |  | ALBASOFT_ONLY |  |  |
| 1339 | School-child |  | ALBASOFT_ONLY |  |  |
| 133a. | Age spread of children in family |  | ALBASOFT_ONLY |  |  |
| 133A. | Student |  | ALBASOFT_ONLY |  |  |
| 133A0 | International student |  | ALBASOFT_ONLY |  |  |
| 133b. | Partner in relationship |  | ALBASOFT_ONLY |  |  |
| 133B. | Orphan |  | ALBASOFT_ONLY |  |  |
| 133c. | Hospital at home patient |  | ALBASOFT_ONLY |  |  |
| 133C. | Widower |  | ALBASOFT_ONLY |  |  |
| 133d. | Child no longer cause for concern |  | ALBASOFT_ONLY |  |  |
| 133D. | Child of |  | ALBASOFT_ONLY |  |  |
| 133D1 | Has stepmother |  | ALBASOFT_ONLY |  |  |
| 133D2 | Has stepfather |  | ALBASOFT_ONLY |  |  |
| 133D3 | Is a stepchild |  | ALBASOFT_ONLY |  |  |
| 133e. | Common law partnership |  | ALBASOFT_ONLY |  |  |
| 133E. | Parent of |  | ALBASOFT_ONLY |  |  |
| 133f. | Teenage parent |  | ALBASOFT_ONLY |  |  |
| 133F. | Marital state unknown |  | ALBASOFT_ONLY |  |  |
| 133g. | Family concern about patient |  | ALBASOFT_ONLY |  |  |
| 133G. | Common-law husband |  | ALBASOFT_ONLY |  |  |
| 133h. | Friend concern about patient |  | ALBASOFT_ONLY |  |  |
| 133H. | Common-law wife |  | ALBASOFT_ONLY |  |  |
| 133i. | Carer concern about patient |  | ALBASOFT_ONLY |  |  |
| 133I. | Abandoned child |  | ALBASOFT_ONLY |  |  |
| 133J. | Youngest sibling |  | ALBASOFT_ONLY |  |  |
| 133K. | Oldest sibling |  | ALBASOFT_ONLY |  |  |
| 133L. | Immigrant |  | ALBASOFT_ONLY |  |  |
| 133M. | Is an only child |  | ALBASOFT_ONLY |  |  |
| 133N. | Approved foster parent |  | ALBASOFT_ONLY |  |  |
| 133P. | Vulnerable adult |  | ALBASOFT_ONLY |  |  |
| 133Q. | Family reunion immigrant |  | ALBASOFT_ONLY |  |  |
| 133R. | Vulnerable elderly person |  | ALBASOFT_ONLY |  |  |
| 133S. | Married/civil partner |  | ALBASOFT_ONLY |  |  |
| 133T. | Divorced/person whose civil partnership has been dissolved |  | ALBASOFT_ONLY |  |  |
| 133V. | Widowed/surviving civil partner |  | ALBASOFT_ONLY |  |  |
| 133W. | Marital/civil state not disclosed |  | ALBASOFT_ONLY |  |  |
| 133X. | Details of own children |  | ALBASOFT_ONLY |  |  |
| 133Y. | Number of offspring |  | ALBASOFT_ONLY |  |  |
| 133Z. | Personal status NOS |  | ALBASOFT_ONLY |  |  |
| 13H9. | Imprisonment record |  | ALBASOFT_ONLY |  |  |
| 13HQ. | In prison |  | ALBASOFT_ONLY |  |  |
| 13I71 | Husband in prison |  | ALBASOFT_ONLY |  |  |
| 14X.. | History of abuse |  | ALBASOFT_ONLY |  |  |
| 15431 | No history of abortion |  | ALBASOFT_ONLY |  |  |
| 1J3.. | Suspected child abuse |  | ALBASOFT_ONLY |  |  |
| 43U5. | Chlamydia PCR negative |  | ALBASOFT+LRPCD | LRPCD | STD |
| 43U6. | Chlamydia test negative |  | ALBASOFT+LRPCD | LRPCD | STD |
| 62b.. | Antenatal HIV screening |  | ALBASOFT_ONLY |  |  |
| 67I2. | Advice about HIV prevention |  | ALBASOFT+LRPCD | LRPCD | STD |
| 6992 | Prison medical examination |  | ALBASOFT_ONLY |  |  |
| 7E06D |  |  | ALBASOFT_ONLY |  |  |
| 7E071 | Curettage of products of conception from uterus NEC |  | ALBASOFT_ONLY |  |  |
| 7E0Ay | Other specified introduction of gamete into uterine cavity |  | ALBASOFT+LRPCD | LRPCD | IVF |
| 7E0Az | Introduction of gamete into uterine cavity NOS |  | ALBASOFT+LRPCD | LRPCD | IVF |
| 8C8Z. | Treatment for infertility NOS |  | ALBASOFT+LRPCD | LRPCD | IVF |
| 9Ea1. | To prevent grave permnt inj physic/mental health preg woman |  | ALBASOFT_ONLY |  |  |
| 9Ea2. | Less 24 wk involv risk injury physic/mentl health preg woman |  | ALBASOFT_ONLY |  |  |
| 9Ea3. | Lss 24 wk inv risk inj phys/men hlth ext child preg wom fmly |  | ALBASOFT_ONLY |  |  |
| 9Ea4. | Unborn child at risk physi/ment abnormal serious handicap |  | ALBASOFT_ONLY |  |  |
| 9U... | Complaints about care |  | ALBASOFT_ONLY |  |  |
| 9U0.. | Formal complaint about medical care |  | ALBASOFT_ONLY |  |  |
| 9U1.. | Formal complaint about GP |  | ALBASOFT_ONLY |  |  |
| 9U2.. | Formal complaint about GP RE: self |  | ALBASOFT_ONLY |  |  |
| 9U3.. | Formal complaint about GP RE: relative |  | ALBASOFT_ONLY |  |  |
| 9U4.. | Formal complaint about hospital care |  | ALBASOFT_ONLY |  |  |
| 9U5.. | Formal complaint about hospital care RE: self |  | ALBASOFT_ONLY |  |  |
| 9U6.. | Formal complaint about hospital care RE: relative |  | ALBASOFT_ONLY |  |  |
| 9U7.. | Formal complaint about private specialist |  | ALBASOFT_ONLY |  |  |
| 9U8.. | Formal complaint about private specialist RE: self |  | ALBASOFT_ONLY |  |  |
| 9U9.. | Formal complaint about private specialist RE: relative |  | ALBASOFT_ONLY |  |  |
| A780. | Molluscum contagiosum |  | ALBASOFT_ONLY |  |  |
| A788W | HIV disease resulting in unspecified malignant neoplasm |  | ALBASOFT+LRPCD | LRPCD | STD |
| A788X | HIV disease resulting/unspcf infectious+parasitic disease |  | ALBASOFT+LRPCD | LRPCD | STD |
| A7891 | HIV disease resulting in cytomegaloviral disease |  | ALBASOFT+LRPCD | LRPCD | STD |
| A7892 | HIV disease resulting in candidiasis |  | ALBASOFT+LRPCD | LRPCD | STD |
| A7894 | HIV disease resulting in multiple infections |  | ALBASOFT+LRPCD | LRPCD | STD |
| A789X | HIV dis reslt/oth mal neopl/lymph,h'matopoetc+reltd tissu |  | ALBASOFT+LRPCD | LRPCD | STD |
| A78AW | Chlamydial infection, unspecified |  | ALBASOFT+LRPCD | LRPCD | STD |
| A78AX | Chlamydial infection of genitourinary tract, unspecified |  | ALBASOFT+LRPCD | LRPCD | STD |
| A9040 | Unspecified juvenile neurosyphilis |  | ALBASOFT+LRPCD | LRPCD | STD |
| A904z | Juvenile neurosyphilis NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A91X. | Early syphilis, unspecified |  | ALBASOFT+LRPCD | LRPCD | STD |
| A94yz | Other specified neurosyphilis NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A9841 | Gonococcal iridocyclitis |  | ALBASOFT+LRPCD | LRPCD | STD |
| A984z | Gonococcal eye infection NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A9850 | Gonococcal arthritis |  | ALBASOFT+LRPCD | LRPCD | STD |
| A985z | Gonococcal joint infection NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A9871 | Gonococcal rectal infection |  | ALBASOFT+LRPCD | LRPCD | STD |
| A987z | Gonococcal proctitis NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A98y. | Gonococcal infection of other specified sites |  | ALBASOFT+LRPCD | LRPCD | STD |
| A98yy | Other gonococcal infection of other specified site |  | ALBASOFT+LRPCD | LRPCD | STD |
| A98yz | Gonococcal infection of other site NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A98z. | Gonococcal infections NOS |  | ALBASOFT+LRPCD | LRPCD | STD |
| A9-KC |  |  | ALBASOFT_ONLY |  |  |
| L051. | Legal abortion incomplete |  | ALBASOFT_ONLY |  |  |
| L0511 | Incomplete legal abortion + delayed or excessive haemorrhage |  | ALBASOFT_ONLY |  |  |
| L0513 | Incomplete legal abortion with renal failure |  | ALBASOFT_ONLY |  |  |
| L0514 | Incomplete legal abortion with metabolic disorder |  | ALBASOFT_ONLY |  |  |
| L0515 | Incomplete legal abortion with shock |  | ALBASOFT_ONLY |  |  |
| L0516 | Incomplete legal abortion with embolism |  | ALBASOFT_ONLY |  |  |
| L0523 | Complete legal abortion with renal failure |  | ALBASOFT_ONLY |  |  |
| L0524 | Complete legal abortion with metabolic disorder |  | ALBASOFT_ONLY |  |  |
| L0525 | Complete legal abortion with shock |  | ALBASOFT_ONLY |  |  |
| L0526 | Complete legal abortion with embolism |  | ALBASOFT_ONLY |  |  |
| L0601 | Unspec illegal abortion + delayed or excessive haemorrhage |  | ALBASOFT_ONLY |  |  |
| L0602 | Unspecified illegal abortion + pelvic organ/tissue damage |  | ALBASOFT_ONLY |  |  |
| L060x | Unspecified illegal abortion with complication NOS |  | ALBASOFT_ONLY |  |  |
| L061. | Illegal abortion incomplete |  | ALBASOFT_ONLY |  |  |
| L0610 | Incomplete illegal abortion + genital tract/pelvic infection |  | ALBASOFT_ONLY |  |  |
| L0612 | Incomplete illegal abortion + pelvic organ/tissue damage |  | ALBASOFT_ONLY |  |  |
| L0613 | Incomplete illegal abortion with renal failure |  | ALBASOFT_ONLY |  |  |
| L0614 | Incomplete illegal abortion with metabolic disorder |  | ALBASOFT_ONLY |  |  |
| L0615 | Incomplete illegal abortion with shock |  | ALBASOFT_ONLY |  |  |
| L0616 | Incomplete illegal abortion with embolism |  | ALBASOFT_ONLY |  |  |
| L0620 | Complete illegal abortion + genital tract/pelvic infection |  | ALBASOFT_ONLY |  |  |
| L0621 | Complete illegal abortion + delayed or excessive haemorrhage |  | ALBASOFT_ONLY |  |  |
| L0622 | Complete illegal abortion + pelvic organ/tissue damage |  | ALBASOFT_ONLY |  |  |
| L0623 | Complete illegal abortion with renal failure |  | ALBASOFT_ONLY |  |  |
| L0624 | Complete illegal abortion with metabolic disorder |  | ALBASOFT_ONLY |  |  |
| L0625 | Complete illegal abortion with shock |  | ALBASOFT_ONLY |  |  |
| L0626 | Complete illegal abortion with embolism |  | ALBASOFT_ONLY |  |  |
| L1721 | Other maternal venereal disease during pregnancy- baby deliv |  | ALBASOFT+LRPCD | LRPCD | STD |
| L1723 | Other maternal venereal dis. in pregnancy-baby not delivered |  | ALBASOFT+LRPCD | LRPCD | STD |
| L1724 | Other mat. venereal dis. in puerperium-baby previously deliv |  | ALBASOFT+LRPCD | LRPCD | STD |
| SN55. | Child maltreatment syndrome |  | ALBASOFT_ONLY |  |  |
| SN571 | Sexual abuse |  | ALBASOFT_ONLY |  |  |
| T776. | Place of occurrence of accident or poisoning, prison |  | ALBASOFT_ONLY |  |  |
| TL7.. | Child battering and other maltreatment |  | ALBASOFT_ONLY |  |  |
| TLx4. | Assault by criminal neglect |  | ALBASOFT_ONLY |  |  |
| ZV018 | [V]Human immunodeficiency virus - negative |  | ALBASOFT+LRPCD | LRPCD | STD |
| ZV19C | [V]Family history of physical abuse to sibling |  | ALBASOFT_ONLY |  |  |
| ZV19D | [V]FH physical abuse to sibling by family member |  | ALBASOFT_ONLY |  |  |
| ZV19E | [V]Family history of sexual abuse to sibling |  | ALBASOFT_ONLY |  |  |
| ZV19F | [V]FH of sexual abuse to sibling by family member |  | ALBASOFT_ONLY |  |  |
| ZV19G | [V]Family history of mental abuse to sibling |  | ALBASOFT_ONLY |  |  |
| ZV19H | [V]FH of mental abuse to sibling by family member |  | ALBASOFT_ONLY |  |  |
| ZV19J | [V]Family history of sibling abuse NOS |  | ALBASOFT_ONLY |  |  |
| ZV19K | [V]Family history of sibling abuse by family member NOS |  | ALBASOFT_ONLY |  |  |
| ZV26. | [V]Infertility management |  | ALBASOFT_ONLY |  |  |
| ZV260 | [V]Post-sterilisation vasoplasty or tuboplasty |  | ALBASOFT_ONLY |  |  |
| ZV262 | [V]Infertility investigation and testing |  | ALBASOFT_ONLY |  |  |
| ZV263 | [V]Genetic counselling |  | ALBASOFT_ONLY |  |  |
| ZV264 | [V]Infertility general advice and counselling |  | ALBASOFT_ONLY |  |  |
| ZV26y | [V]Other specified infertility management |  | ALBASOFT_ONLY |  |  |
| ZV26z | [V]Unspecified infertility management |  | ALBASOFT_ONLY |  |  |
| ZV4F9 | [V]Probs rel alleg sex abuse child by pers out prim sup grp |  | ALBASOFT_ONLY |  |  |
| ZV4G4 | [V]Problem relatd/alleg sex abuse cld by person prim sup grp |  | ALBASOFT_ONLY |  |  |
| ZV4G5 | [V]Problems related to alleged physical abuse of child |  | ALBASOFT_ONLY |  |  |
| ZV4J4 | [V]Convict in civil+criminal proceeds without imprisonment |  | ALBASOFT_ONLY |  |  |
| ZV4J5 | [V]Problems related to release from prison |  | ALBASOFT_ONLY |  |  |
| ZV612 | [V]Child abuse |  | ALBASOFT_ONLY |  |  |
| ZV625 | [V]Legal problems |  | ALBASOFT_ONLY |  |  |
| ZV737 | [V]Special screening exam for human immunodefiency virus |  | ALBASOFT+LRPCD | LRPCD | STD |

### Assisted Fertilisation (52 codes)

| ReadV2Code | ReadV2 Term | SNOMED ConceptID | CodeSource | MappingSource | LRPCD |
|---|---|---|---|---|---|
| 14e.. | History of in-vitro fertilisation | 765291000000105 | RCGP+LRPCD | LRPCD | IVF |
| 7C263 | Percutaneous epididymal sperm aspiration | 312645003 | RCGP+LRPCD | LRPCD | IVF |
| 7C264 | Micro-epididymal sperm aspiration | 236364009 | RCGP+LRPCD | LRPCD | IVF |
| 7C265 | Testicular sperm extraction | 229971000000102 | RCGP+LRPCD | LRPCD | IVF |
| 7E0A. | Introduction of gamete into uterine cavity | 176843009 | ALL_THREE | LRPCD | IVF |
| 7E0A0 | Implantation of fertilised egg into uterus | 75456002 | ALL_THREE | LRPCD | IVF |
| 7E0A1 | Intracervical artificial insemination | 176844003 | ALL_THREE | LRPCD | IVF |
| 7E0A2 | Intrauterine artificial insemination | 265064001 | ALL_THREE | LRPCD | IVF |
| 7E0A3 | Intrauterine insemination superovulation partner sperm | 426968007 | ALL_THREE | LRPCD | IVF |
| 7E0A4 | Intrauterine insemination superovulation using donor sperm | 425644009 | ALL_THREE | LRPCD | IVF |
| 7E0A5 | Intrauterine insemination without superovulat partner sperm | 426389008 | ALL_THREE | LRPCD | IVF |
| 7E0A6 | Intrauterine insemination without superovulation donor sperm | 426250000 | ALL_THREE | LRPCD | IVF |
| 7E0A7 | Transfer of embryo to uterus | 233111000000108 | ALL_THREE | LRPCD | IVF |
| 7E0J. | Other introduction of gamete into uterine cavity |  | LRPCD_ONLY | LRPCD | IVF |
| 7E0J0 | Transmyometrial transfer of embryo to uterus | 448543003 | RCGP+LRPCD | LRPCD | IVF |
| 7E1F2 | Endoscopic intrafallopian transfer of gamete | 176996001 | ALL_THREE | LRPCD | IVF |
| 7E24. | Oocyte recovery | 177037000 | RCGP+LRPCD | LRPCD | IVF |
| 7E240 | Endoscopic transurethral ultrasound directed oocyte recovery | 177038005 | RCGP+LRPCD | LRPCD | IVF |
| 7E241 | Endoscopic transvesical oocyte recovery | 177039002 | RCGP+LRPCD | LRPCD | IVF |
| 7E242 | Laparoscopic oocyte recovery | 265082003 | RCGP+LRPCD | LRPCD | IVF |
| 7E243 | Transvaginal oocyte recovery | 177042008 | RCGP+LRPCD | LRPCD | IVF |
| 7E24y | Other specified oocyte recovery |  | LRPCD_ONLY | LRPCD | IVF |
| 7E24z | Oocyte recovery NOS |  | LRPCD_ONLY | LRPCD | IVF |
| 7M0h. | In vitro fertilisation (IVF) | 52637005 | RCGP+LRPCD | LRPCD | IVF |
| 7M0h0 | IVF with donor sperm | 427664000 | RCGP+LRPCD | LRPCD | IVF |
| 7M0h1 | IVF with donor eggs | 425866000 | RCGP+LRPCD | LRPCD | IVF |
| 7M0h2 | IVF with intracytoplasmic sperm injection (ICSI) | 425901007 | RCGP+LRPCD | LRPCD | IVF |
| 7M0h3 | IVF intracytoplasmic sperm injection (ICSI) and donor egg | 426914002 | RCGP+LRPCD | LRPCD | IVF |
| 7M0h4 | IVF with pre-implantation for genetic diagnosis | 426417003 | RCGP+LRPCD | LRPCD | IVF |
| 7M0h5 | IVF with surrogacy | 711544002 | RCGP+LRPCD | LRPCD | IVF |
| 7M0hy | Other specified in vitro fertilisation (IVF) | 268771000000104 | RCGP+LRPCD | LRPCD | IVF |
| 7M0hz | In vitro fertilisation (IVF) NOS | 268781000000102 | RCGP+LRPCD | LRPCD | IVF |
| 8C8.. | Treatment for infertility | 65046005 | RCGP+ALBASOFT | DMWB |  |
| 8C81. | Artificial insemination | 58533008 | ALL_THREE | LRPCD | IVF |
| 8C82. | Female infertility therapy | 183036001 | RCGP+ALBASOFT | DMWB |  |
| 8C83. | Male infertility therapy | 183037005 | RCGP+ALBASOFT | DMWB |  |
| 8C84. | In vitro fertilisation procedure | 268701000000107 | ALL_THREE | LRPCD | IVF |
| 8C85. | Gamete intrafallopian transfer | 236912008 | ALL_THREE | LRPCD | IVF |
| Kyu9H | [X]Other complicatns associated wth artificial fertilization | 213199004 | RCGP+LRPCD | LRPCD | IVF |
| Kyu9P | [X]Complication associated with artificial fertilization, unspecified |  | LRPCD_ONLY | LRPCD | IVF |
| SP0D. | Complications associated with artificial fertilization | 198598005 | RCGP+LRPCD | LRPCD | IVF |
| SP0D0 | Infection associated with artificial insemination | 213200001 | RCGP+LRPCD | LRPCD | IVF |
| SP0D1 | Hyperstimulation of ovaries | 213201002 | RCGP+LRPCD | LRPCD | IVF |
| SP0D2 | Compltns of attemptd intro fertil ovum follow in vitro fert | 213202009 | RCGP+LRPCD | LRPCD | IVF |
| SP0D3 | Complctns/attemptd introduction of embryo in embryo transfer | 213203004 | RCGP+LRPCD | LRPCD | IVF |
| SP0DX | Complication associated with artificial fertilization, unspecified |  | LRPCD_ONLY | LRPCD | IVF |
| ZV261 | [V]Artificial insemination NOS | 427961000000100 | ALL_THREE | LRPCD | IVF |
| ZV265 | [V]Artificial insemination from husband | 236895005 | ALL_THREE | LRPCD | IVF |
| ZV266 | [V]Artificial insemination from donor | 236896006 | ALL_THREE | LRPCD | IVF |
| ZV267 | [V]In vitro fertilization | 440691000000100 | ALL_THREE | LRPCD | IVF |
| ZV268 | [V]Other assisted fertilization methods | 411101000000103 | ALL_THREE | LRPCD | IVF |
| ZVu21 | [X]Other assisted fertilization methods | 391241000000101 | RCGP+LRPCD | LRPCD | IVF |

### Gender Related Issues (30 codes)

| ReadV2Code | ReadV2 Term | SNOMED ConceptID | CodeSource | MappingSource | LRPCD |
|---|---|---|---|---|---|
| 1K4.. | Gender reassignment patient | 282272009 | RCGP_ONLY | DMWB |  |
| 7C220 | Construction of penis | 176532008 | RCGP_ONLY | DMWB |  |
| 7D16. | Plastic operations on vagina | 176687003 | RCGP_ONLY | DMWB |  |
| 7D160 | Construction of vagina | 265619004 | RCGP_ONLY | DMWB |  |
| 7D163 | Reconstruction of vagina with skin graft | 176691008 | RCGP_ONLY | DMWB |  |
| 7L0B. | Operations for sexual transformation | 719670005 | RCGP_ONLY | DMWB |  |
| 7L0B0 | Combined operations for transformation from male to female | 51427007 | RCGP_ONLY | DMWB |  |
| 7L0B1 | Combined operations for transformation from female to male | 42775008 | RCGP_ONLY | DMWB |  |
| 7L0B3 | Construction of scrotum | 441524006 | RCGP_ONLY | DMWB |  |
| 7L0By | Other specified operation for sexual transformation | 24878005 | RCGP_ONLY | DMWB |  |
| 7L0Bz | Operation for sexual transformation NOS | 149785007 | RCGP_ONLY | SEMANTIC |  |
| E223. | Transvestism | 472948001 | RCGP_ONLY | DMWB |  |
| E225. | Trans-sexualism | 407374003 | RCGP_ONLY | DMWB |  |
| E2251 | Trans-sexuality with asexual history | 472945003 | RCGP_ONLY | DMWB |  |
| E2252 | Trans-sexuality with homosexual history | 472947006 | RCGP_ONLY | DMWB |  |
| E2253 | Trans-sexuality with heterosexual history | 472946002 | RCGP_ONLY | DMWB |  |
| E226. | Psychosexual identity disorder | 191787001 | RCGP_ONLY | DMWB |  |
| E226z | Psychosexual identity disorder NOS | 191790007 | RCGP_ONLY | SEMANTIC |  |
| E22y4 | Gender role disorder of adolescent or adult | 191798000 | RCGP_ONLY | DMWB |  |
| Eu64. | [X]Gender identity disorders | 87991007 | RCGP_ONLY | DMWB |  |
| Eu640 | [X]Transsexualism | 192508005 | RCGP_ONLY | SEMANTIC |  |
| Eu641 | [X]Dual-role transvestism | 472989003 | RCGP_ONLY | DMWB |  |
| Eu642 | [X]Gender identity disorder of childhood | 5095008 | RCGP_ONLY | DMWB |  |
| Eu64y | [X]Other gender identity disorders | 192507000 | RCGP_ONLY | SEMANTIC |  |
| Eu64z | [X]Gender identity disorder, unspecified | 412321000000104 | RCGP_ONLY | SEMANTIC |  |
| Eu651 | [X]Fetishistic transvestism | 472981000 | RCGP_ONLY | DMWB |  |
| PC7.. | Indeterminate sex and pseudohermaphroditism | 268229003 | RCGP_ONLY | DMWB |  |
| PC71. | Male pseudohermaphroditism | 111332007 | RCGP_ONLY | DMWB |  |
| PC72. | Female pseudohermaphroditism | 8800006 | RCGP_ONLY | DMWB |  |
| ZV62A | [V] Gender dysphoria | 93461009 | RCGP_ONLY | DMWB |  |

### Sexually Transmitted Disease (768 codes)

| ReadV2Code | ReadV2 Term | SNOMED ConceptID | CodeSource | MappingSource | LRPCD |
|---|---|---|---|---|---|
| 1232 | FH: Syphilis | 160281003 | RCGP_ONLY | DMWB |  |
| 1232. | FH: Syphilis | 137684006 | RCGP_ONLY | SEMANTIC |  |
| 1233 | FH: Gonorrhoea | 160282005 | RCGP_ONLY | DMWB |  |
| 1233. | FH: Gonorrhoea | 137685007 | RCGP_ONLY | SEMANTIC |  |
| 12K5. | Mother hepatitis B positive |  | LRPCD_ONLY | LRPCD | STD |
| 13N5. | HIV risk lifestyle | 266974005 | ALL_THREE | LRPCD | STD |
| 13N9. | Sexual contact with high risk partner | 200631000000105 | RCGP+LRPCD | LRPCD | STD |
| 1415 | H/O: venereal disease | 275881005 | RCGP+ALBASOFT | DMWB |  |
| 1415. | H/O: venereal disease | 138691006 | ALL_THREE | LRPCD | STD |
| 14150 | H/O: chlamydia infection | 472954000 | RCGP+LRPCD | LRPCD | STD |
| 14151 | H/O: gonorrhoea | 764281000000109 | RCGP+LRPCD | LRPCD | STD |
| 14152 | H/O: genital warts | 872251000000104 | RCGP+LRPCD | LRPCD | STD |
| 14153 | H/O: genital herpes | 872271000000108 | RCGP+LRPCD | LRPCD | STD |
| 141E. | History of hepatitis B |  | LRPCD_ONLY | LRPCD | STD |
| 14i.. | H/O hepatitis C antiviral drug therapy | 829691000000100 | RCGP+LRPCD | LRPCD | STD |
| 14OP. | At risk of sexually transmitted infection | 407560009 | RCGP+LRPCD | LRPCD | STD |
| 14OP0 | At high risk of sexually transmitted infection | 702479006 | RCGP+LRPCD | LRPCD | STD |
| 14OP1 | At low risk of sexually transmitted infection | 702480009 | RCGP+LRPCD | LRPCD | STD |
| 2BG3. | O/E - Argyll Robertson pupils | 164029004 | RCGP+LRPCD | LRPCD | STD |
| 2J12. | Hepatitis C non immune |  | LRPCD_ONLY | LRPCD | STD |
| 3183 | Special female test normal | 164811005 | RCGP_ONLY | DMWB |  |
| 3194 | Special male test abnormal | 164826007 | RCGP_ONLY | DMWB |  |
| 438.. | Syphilis infectious titre test | 1015571000000106 | RCGP+LRPCD | LRPCD | STD |
| 4381 | Syphilis titre test negative | 165780000 | RCGP_ONLY | DMWB |  |
| 4381. | Syphilis titre test negative |  | LRPCD_ONLY | LRPCD | STD |
| 4382 | Syphilis titre test positive | 165781001 | RCGP_ONLY | DMWB |  |
| 4382. | Syphilis titre test positive | 143187000 | RCGP+LRPCD | LRPCD | STD |
| 4383 | Wassermann's test (W.R.) | 1028721000000102 | RCGP_ONLY | DMWB |  |
| 4383. | Wassermann's test (W.R.) | 165782008 | RCGP+LRPCD | LRPCD | STD |
| 4384 | V.D.R.L. test | 1015581000000108 | RCGP_ONLY | DMWB |  |
| 4384. | V.D.R.L. test |  | LRPCD_ONLY | LRPCD | STD |
| 4385 | T.P.I test | 252407006 | RCGP_ONLY | DMWB |  |
| 4385. | T.P.I test |  | LRPCD_ONLY | LRPCD | STD |
| 4386 | Fluorescent treponemal antibody test | 1015591000000105 | RCGP_ONLY | DMWB |  |
| 4386. | Fluorescent treponemal antibody test | 9232009 | RCGP+LRPCD | LRPCD | STD |
| 4387 | Treponema pallidum haemaglutination test | 1015601000000104 | RCGP_ONLY | DMWB |  |
| 4387. | Treponema pallidum haemaglutination test |  | LRPCD_ONLY | LRPCD | STD |
| 4388 | Treponema pallidum particle inhibition test | 991941000000103 | RCGP_ONLY | DMWB |  |
| 4388. | Treponema pallidum particle inhibition test | 401262008 | RCGP+LRPCD | LRPCD | STD |
| 4389 | Syphilis serology | 991951000000100 | RCGP_ONLY | DMWB |  |
| 4389. | Syphilis serology | 165787002 | RCGP+LRPCD | LRPCD | STD |
| 438A. | Treponema pallidum ELISA negative | 390879000 | RCGP+LRPCD | LRPCD | STD |
| 438B. | Treponema pallidum ELISA positive | 390880002 | RCGP+LRPCD | LRPCD | STD |
| 438C. | Treponema pallidum particle agglutination test | 992931000000104 | RCGP+LRPCD | LRPCD | STD |
| 438D. | Treponema pallidum gelatin agglutination test | 1005361000000109 | RCGP+LRPCD | LRPCD | STD |
| 438E. | Total treponema antibody level | 1018861000000106 | RCGP+LRPCD | LRPCD | STD |
| 438F. | Treponema pallidum total antibodies measurement | 1002021000000108 | RCGP+LRPCD | LRPCD | STD |
| 438Z. | Syphilis titre test NOS | 269828009 | RCGP+LRPCD | LRPCD | STD |
| 43B.. | SH-antigen (hepatitis B) test |  | LRPCD_ONLY | LRPCD | STD |
| 43B1. | Blood sent: SH-antigen test | 165803005 | RCGP+LRPCD | LRPCD | STD |
| 43B2. | Hepatitis B immune |  | LRPCD_ONLY | LRPCD | STD |
| 43B3. | SH-antigen negative |  | LRPCD_ONLY | LRPCD | STD |
| 43B4. | Hepatitis B surface antig +ve |  | LRPCD_ONLY | LRPCD | STD |
| 43B5. | Hepatitis e antigen present |  | LRPCD_ONLY | LRPCD | STD |
| 43B6. | Hepatitis B non immune |  | LRPCD_ONLY | LRPCD | STD |
| 43B7. | Hepatitis C non-immune |  | LRPCD_ONLY | LRPCD | STD |
| 43B8. | Hepatitis B core antigen test |  | LRPCD_ONLY | LRPCD | STD |
| 43B9. | Hepatitis B e antigen test |  | LRPCD_ONLY | LRPCD | STD |
| 43BA. | Hepatitis B surface antigen negative |  | LRPCD_ONLY | LRPCD | STD |
| 43bS. | Serologic test for herpes simplex | 46898007 | RCGP+LRPCD | LRPCD | STD |
| 43BZ. | SH-antigen test NOS |  | LRPCD_ONLY | LRPCD | STD |
| 43C.. | HTLV-3 antibody test | 1027831000000105 | ALL_THREE | LRPCD | STD |
| 43C1. | Blood sent for HTLV-3 serology | 165814008 | ALL_THREE | LRPCD | STD |
| 43C2. | HTLV-3 antibody negative | 165815009 | ALL_THREE | LRPCD | STD |
| 43C3. | HTLV-3 antibody positive | 165816005 | ALL_THREE | LRPCD | STD |
| 43C4. | Human immunodeficiency virus test equivocal | 248981000000107 | ALL_THREE | LRPCD | STD |
| 43CZ. | HTLV-3 antibody NOS | 250514000 | ALL_THREE | LRPCD | STD |
| 43d5. | HIV antibody/antigen (Duo) | 1014171000000103 | ALL_THREE | LRPCD | STD |
| 43d6. | HTLV 1 antibody level | 1014181000000101 | RCGP+LRPCD | LRPCD | STD |
| 43d8. | Hepatitis B surface antibody level |  | LRPCD_ONLY | LRPCD | STD |
| 43d9. | Hepatitis B surface antigen level |  | LRPCD_ONLY | LRPCD | STD |
| 43dA. | Hepatitis B core IgM level |  | LRPCD_ONLY | LRPCD | STD |
| 43dB. | Hepatitis B core antibody level |  | LRPCD_ONLY | LRPCD | STD |
| 43dc. | HTLV 2 antibody level | 998861000000101 | RCGP+LRPCD | LRPCD | STD |
| 43dC. | Hepatitis B e antibody level |  | LRPCD_ONLY | LRPCD | STD |
| 43dD. | Hepatitis C recombinant immunoblot assay |  | LRPCD_ONLY | LRPCD | STD |
| 43de. | Herpes simplex IgM level | 1005081000000102 | RCGP+LRPCD | LRPCD | STD |
| 43dE. | Herpes simplex antibody level | 1014251000000101 | RCGP+LRPCD | LRPCD | STD |
| 43dm. | Herpes simplex IgG level | 1013481000000106 | RCGP+LRPCD | LRPCD | STD |
| 43E6. | Gonorrhoea infect. titre test | 992041000000109 | RCGP+LRPCD | LRPCD | STD |
| 43eC. | Chlamydia trachomatis L2 antibody level | 1023351000000100 | RCGP+LRPCD | LRPCD | STD |
| 43eE. | Chlamydia antibody level | 1023371000000109 | RCGP+LRPCD | LRPCD | STD |
| 43ef. | Syphilis IgG level | 1029021000000105 | RCGP+LRPCD | LRPCD | STD |
| 43eF. | Chlamydia group complement fixation test | 1031371000000108 | RCGP+LRPCD | LRPCD | STD |
| 43eh. | Treponema pallidum IgG level | 992711000000105 | RCGP+LRPCD | LRPCD | STD |
| 43ei. | Treponema pallidum IgM level | 992721000000104 | RCGP+LRPCD | LRPCD | STD |
| 43ej. | VDRL titre | 995221000000102 | RCGP+LRPCD | LRPCD | STD |
| 43eJ. | Chlamydia trachomatis IgG level | 1023411000000108 | RCGP+LRPCD | LRPCD | STD |
| 43eO. | Fluorescent treponemal antibody absorption IgG level | 1028971000000100 | RCGP+LRPCD | LRPCD | STD |
| 43eP. | Fluorescent treponemal antibody absorption IgM level | 1028981000000103 | RCGP+LRPCD | LRPCD | STD |
| 43ez. | Chlamydia trachomatis IgM level | 999001000000101 | RCGP+LRPCD | LRPCD | STD |
| 43h0. | Chlamydia trachomatis polymerase chain reaction | 1026621000000109 | RCGP+LRPCD | LRPCD | STD |
| 43h2. | HIV 1 PCR | 1026641000000102 | ALL_THREE | LRPCD | STD |
| 43h3. | Hepatitis C PCR |  | LRPCD_ONLY | LRPCD | STD |
| 43h4. | Herpes simplex polymerase chain reaction | 1026651000000104 | RCGP+LRPCD | LRPCD | STD |
| 43h6. | Neisseria gonorrhoeae polymerase chain reaction | 1026661000000101 | RCGP+LRPCD | LRPCD | STD |
| 43h9. | HIV proviral deoxyribonucleic acid polymerase chain reaction | 1030231000000108 | RCGP+LRPCD | LRPCD | STD |
| 43j1. | Chlamydia trachomatis nucleic acid detection | 998611000000102 | RCGP+LRPCD | LRPCD | STD |
| 43j10 | Chlamydia trachomatis (LGV serovar) DNA detection | 1000261000000105 | RCGP+LRPCD | LRPCD | STD |
| 43j11 | Chlamydia trachomatis detection by NAAT | 817771000000106 | RCGP+LRPCD | LRPCD | STD |
| 43j12 | Chlamydia trachomatis nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43j5. | Hepatitis C nucleic acid detection |  | LRPCD_ONLY | LRPCD | STD |
| 43j50 | Hepatitis C nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43j6. | Herpes simplex nucleic acid detection | 1030521000000108 | RCGP+LRPCD | LRPCD | STD |
| 43j60 | Herpes simplex nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43j61 | Herpes simplex deoxyribonucleic acid detection assay | 1008421000000104 | RCGP+LRPCD | LRPCD | STD |
| 43j7. | HIV 1 nucleic acid detection | 1008351000000102 | RCGP+LRPCD | LRPCD | STD |
| 43j70 | HIV 1 nucleic acid detection assay | 907191000000100 | RCGP+LRPCD | LRPCD | STD |
| 43j71 | HIV 1 provirus deoxyribonucleic acid detection assay | 1008361000000104 | RCGP+LRPCD | LRPCD | STD |
| 43j72 | HIV 1 ribonucleic acid detection assay | 934551000000101 | RCGP+LRPCD | LRPCD | STD |
| 43j8. | HTLV 1 nucleic acid detection | 1008331000000109 | RCGP+LRPCD | LRPCD | STD |
| 43j80 | HTLV 1 nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43j81 | HTLV 1 provirus deoxyribonucleic acid detection assay | 1008341000000100 | RCGP+LRPCD | LRPCD | STD |
| 43j82 | HTLV 1 ribonucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43J9. | Anti HBc IgG level |  | LRPCD_ONLY | LRPCD | STD |
| 43jA. | Neisseria gonorrhoeae nucleic acid detection | 998651000000103 | RCGP+LRPCD | LRPCD | STD |
| 43JA. | Anti HBc IgM level |  | LRPCD_ONLY | LRPCD | STD |
| 43jA0 | Neisseria gonorrhoeae nucleic acid detection assay | 907521000000109 | RCGP+LRPCD | LRPCD | STD |
| 43jE. | HTLV 2 nucleic acid detection | 1008311000000101 | RCGP+LRPCD | LRPCD | STD |
| 43jE0 | HTLV 2 nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jE1 | HTLV 2 provirus deoxyribonucleic acid detection assay | 1008321000000107 | RCGP+LRPCD | LRPCD | STD |
| 43jE2 | HTLV 2 ribonucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jG. | Hepatitis B nucleic acid detection |  | LRPCD_ONLY | LRPCD | STD |
| 43jG0 | Hepatitis B nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jG1 | Hepatitis B deoxyribonucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jJ. | Hepatitis D nucleic acid detection |  | LRPCD_ONLY | LRPCD | STD |
| 43jJ0 | Hepatitis D nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jK. | Chlamydia deoxyribonucleic acid detection | 1002681000000104 | RCGP+LRPCD | LRPCD | STD |
| 43JK. | Hepatitis C IgG level |  | LRPCD_ONLY | LRPCD | STD |
| 43jr. | Human T-lymphotropic virus nucleic acid detection | 1008291000000102 | RCGP+LRPCD | LRPCD | STD |
| 43jr0 | HTLV nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jr1 | HTLV provirus deoxyribonucleic acid detection assay | 1008301000000103 | RCGP+LRPCD | LRPCD | STD |
| 43jr2 | HTLV ribonucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jt. | Human herpes virus 6 nucleic acid detection | 1029701000000104 | RCGP_ONLY | DMWB |  |
| 43jt1 | Human herpesvirus 6 deoxyribonucleic acid detection assay | 1008391000000105 | RCGP_ONLY | DMWB |  |
| 43ju. | Human herpes virus 7 nucleic acid detection | 1029711000000102 | RCGP_ONLY | DMWB |  |
| 43ju1 | Human herpesvirus 7 deoxyribonucleic acid detection assay | 1008381000000108 | RCGP_ONLY | DMWB |  |
| 43jv. | Human herpes virus 8 nucleic acid detection | 1029721000000108 | RCGP+LRPCD | LRPCD | STD |
| 43jv0 | Human herpes virus 8 nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jv1 | Human herpesvirus 8 deoxyribonucleic acid detection assay | 1008371000000106 | RCGP+LRPCD | LRPCD | STD |
| 43jY. | Human papilloma virus nucleic acid detection | 1029511000000109 | RCGP+LRPCD | LRPCD | STD |
| 43jY0 | Human papilloma virus nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43jY1 | Human papilloma virus deoxyribonucleic acid detection assay | 1008271000000101 | RCGP+LRPCD | LRPCD | STD |
| 43k0. | Hepatitis B e antigen level |  | LRPCD_ONLY | LRPCD | STD |
| 43k1. | Hepatitis C antigen level |  | LRPCD_ONLY | LRPCD | STD |
| 43n9. | Chlamydia trachomatis IgA level | 1011651000000101 | RCGP+LRPCD | LRPCD | STD |
| 43q.. | Hepatitis C virus RNA assay |  | LRPCD_ONLY | LRPCD | STD |
| 43U.. | Chlamydia antigen test | 1031431000000104 | ALL_THREE | LRPCD | STD |
| 43U0. | Chlamydia antigen by ELISA | 310862001 | ALL_THREE | LRPCD | STD |
| 43U1. | Chlamydia antigen ELISA positive | 314527009 | ALL_THREE | LRPCD | STD |
| 43U2. | Chlamydia antigen ELISA negative | 314526000 | ALL_THREE | LRPCD | STD |
| 43U3. | Chlamydia trachomatis antigen test | 1005381000000100 | ALL_THREE | LRPCD | STD |
| 43U4. | Chlamydia PCR positive | 413079006 | ALL_THREE | LRPCD | STD |
| 43U7. | Chlamydia test equivocal | 247371000000107 | ALL_THREE | LRPCD | STD |
| 43U8. | Chlamydia test positive | 201441000000107 | ALL_THREE | LRPCD | STD |
| 43U9. | Chlamydia trachomatis NAAT inhibitory | 448374002 | ALL_THREE | LRPCD | STD |
| 43w3. | Human immunodeficiency virus RNA/DNA ratio | 996081000000100 | RCGP+LRPCD | LRPCD | STD |
| 43w4. | Herpes simplex virus type 1 nucleic acid detection | 1029781000000109 | RCGP+LRPCD | LRPCD | STD |
| 43w40 | Herpes simplex virus type 1 nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43w41 | Herpes simplex type 1 deoxyribonucleic acid detection assay | 1008411000000105 | RCGP+LRPCD | LRPCD | STD |
| 43w5. | Herpes simplex virus type 2 nucleic acid detection | 1003991000000103 | RCGP+LRPCD | LRPCD | STD |
| 43W5. | HBeAg antibody level |  | LRPCD_ONLY | LRPCD | STD |
| 43w50 | Herpes simplex virus type 2 nucleic acid detection assay |  | LRPCD_ONLY | LRPCD | STD |
| 43w51 | Herpes simplex type 2 deoxyribonucleic acid detection assay | 1008401000000108 | RCGP+LRPCD | LRPCD | STD |
| 43W6. | HBsAg antibody level |  | LRPCD_ONLY | LRPCD | STD |
| 43W7. | HIV1 antibody level | 1008801000000105 | ALL_THREE | LRPCD | STD |
| 43W8. | HIV2 antibody level | 1008811000000107 | ALL_THREE | LRPCD | STD |
| 43wA. | Treponema pallidum detection by NAAT | 818821000000104 | RCGP+LRPCD | LRPCD | STD |
| 43wB. | Treponema pallidum deoxyribonucleic acid detection | 1004141000000107 | RCGP+LRPCD | LRPCD | STD |
| 43WK. | Human immunodeficiency virus antibody level | 1014121000000102 | ALL_THREE | LRPCD | STD |
| 43WL. | Treponema pallidum reagin antibody level | 998731000000100 | RCGP+LRPCD | LRPCD | STD |
| 43WM. | Chlamydia group antibody level | 998741000000109 | RCGP+LRPCD | LRPCD | STD |
| 43X.. | Hepatitis antibody test |  | LRPCD_ONLY | LRPCD | STD |
| 43X2. | Hepatitis C antibody test |  | LRPCD_ONLY | LRPCD | STD |
| 43X3. | Hepatitis C antibody test positive |  | LRPCD_ONLY | LRPCD | STD |
| 43X4. | Hepatitis C antibody test negative |  | LRPCD_ONLY | LRPCD | STD |
| 43X6. | Hepatitis C antibody level |  | LRPCD_ONLY | LRPCD | STD |
| 43XA. | Hepatitis B core antibody positive |  | LRPCD_ONLY | LRPCD | STD |
| 46H6. | Urine chlamydia trachomatis test positive | 415798001 | RCGP+LRPCD | LRPCD | STD |
| 46H7. | Urine chlamydia trachomatis test negative | 415797006 | RCGP+LRPCD | LRPCD | STD |
| 4J2D. | Neisseria gonorrhoeae culture | 1011071000000104 | RCGP_ONLY | DMWB |  |
| 4J34. | HIV viral load | 998701000000106 | ALL_THREE | LRPCD | STD |
| 4J35. | HIV p24 antigen level | 998711000000108 | RCGP+LRPCD | LRPCD | STD |
| 4J36. | Herpes simplex antigen (EIA) | 998721000000102 | RCGP+LRPCD | LRPCD | STD |
| 4J3B. | Hepatitis C viral load |  | LRPCD_ONLY | LRPCD | STD |
| 4J3C. | Herpes simplex virus isolation | 1021331000000108 | RCGP+LRPCD | LRPCD | STD |
| 4J3D. | Hepatitis B viral load |  | LRPCD_ONLY | LRPCD | STD |
| 4J3F. | Human immunodeficiency virus viral load by log rank | 998171000000102 | RCGP+LRPCD | LRPCD | STD |
| 4J3N. | Human immunodeficiency virus drug resistance test | 1010871000000101 | RCGP+LRPCD | LRPCD | STD |
| 4J3P. | Human immunodeficiency virus type 1 subtype identification | 1007761000000101 | RCGP+LRPCD | LRPCD | STD |
| 4J3Q. | Human immunodeficiency virus IgG avidity | 1007841000000109 | RCGP+LRPCD | LRPCD | STD |
| 4J54. | Trichomonas seen | 200731000000100 | RCGP+LRPCD | LRPCD | STD |
| 4J55. | Trichomonas not seen | 200741000000109 | RCGP+LRPCD | LRPCD | STD |
| 4JDc. | Human T-lymphotropic virus (1&2) serology | 996221000000106 | RCGP+LRPCD | LRPCD | STD |
| 4JDJ. | Hepatitis G serology |  | LRPCD_ONLY | LRPCD | STD |
| 4JDM. | Chlamydia serology | 1009781000000101 | RCGP+LRPCD | LRPCD | STD |
| 4JDN. | Human herpes virus serology | 1009791000000104 | RCGP+LRPCD | LRPCD | STD |
| 4JDT. | HIV serology | 1020841000000100 | RCGP+LRPCD | LRPCD | STD |
| 4JDT0 | Rapid human immunodeficiency virus antibody test | 754591000000103 | RCGP+LRPCD | LRPCD | STD |
| 4JDY. | Hepatitis D serology |  | LRPCD_ONLY | LRPCD | STD |
| 4JF42 | Throat swab for chlamydia | 707982002 | RCGP+LRPCD | LRPCD | STD |
| 4JF43 | Throat swab for gonorrhoea | 707983007 | RCGP+LRPCD | LRPCD | STD |
| 4JH61 | Anal swab culture negative | 168326009 | RCGP+LRPCD | LRPCD | STD |
| 4JH63 | Anal swab for chlamydia | 472859009 | RCGP+LRPCD | LRPCD | STD |
| 4JH64 | Anal swab for gonorrhoea | 472860004 | RCGP+LRPCD | LRPCD | STD |
| 4JK10 | Urethral swab culture positive | 168343007 | RCGP+LRPCD | LRPCD | STD |
| 4JK22 | HVS culture - trichomonas vaginalis | 168348003 | RCGP+LRPCD | LRPCD | STD |
| 4JK8. | Penile swab taken | 168359007 | RCGP+LRPCD | LRPCD | STD |
| 4JK80 | Penile swab culture positive | 168361003 | RCGP+LRPCD | LRPCD | STD |
| 4JK9. | Endocervical chlamydia swab | 390784004 | RCGP+LRPCD | LRPCD | STD |
| 4JKA. | Urethral chlamydia swab | 390785003 | RCGP+LRPCD | LRPCD | STD |
| 4JKB. | Gonococcal cervical swab | 400993006 | RCGP+LRPCD | LRPCD | STD |
| 4JKC. | Gonococcal urethral swab | 401002001 | RCGP+LRPCD | LRPCD | STD |
| 4JKD. | Low vaginal swab for chlamydia taken by patient | 200761000000105 | RCGP+LRPCD | LRPCD | STD |
| 4JLA. | Gonococcal swab | 400994000 | RCGP+LRPCD | LRPCD | STD |
| 4JLC. | Chlamydia swab | 285586000 | RCGP+LRPCD | LRPCD | STD |
| 4JQ3. | Hepatitis C virus genotype |  | LRPCD_ONLY | LRPCD | STD |
| 4JQ8. | Gonorrhoea test negative |  | LRPCD_ONLY | LRPCD | STD |
| 4JQ9. | Gonorrhoea test equivocal | 247401000000109 | RCGP+LRPCD | LRPCD | STD |
| 4JQA. | Gonorrhoea test positive | 247411000000106 | RCGP+LRPCD | LRPCD | STD |
| 4JQC. | Hepatitis C viral ribonucleic acid polymerase chain reaction negative |  | LRPCD_ONLY | LRPCD | STD |
| 4JQD. | Hepatitis C viral ribonucleic acid polymerase chain reaction positive |  | LRPCD_ONLY | LRPCD | STD |
| 4JQE. | Hepatitis C antigen negative |  | LRPCD_ONLY | LRPCD | STD |
| 4JQF. | Hepatitis C antigen positive |  | LRPCD_ONLY | LRPCD | STD |
| 4JR1. | Hepatitis B screening test |  | LRPCD_ONLY | LRPCD | STD |
| 4JR4. | Treponema screening test | 993791000000109 | RCGP+LRPCD | LRPCD | STD |
| 4JR7. | HIV screening test | 992781000000103 | RCGP+LRPCD | LRPCD | STD |
| 4JR9. | Trichomonas screening test |  | LRPCD_ONLY | LRPCD | STD |
| 4JRF. | Viral hepatitis screening test | 1024481000000104 | RCGP+LRPCD | LRPCD | STD |
| 4JSD. | Treponema pallidum microscopy | 1046211000000102 | RCGP+LRPCD | LRPCD | STD |
| 4JSE. | Neisseria gonorrhoeae microscopy | 1046231000000105 | RCGP+LRPCD | LRPCD | STD |
| 4K2R. | Cervical smear - human papillomavirus positive | 888111000000103 | RCGP_ONLY | DMWB |  |
| 4K33. | Cervical smear - trichomonas | 168417005 | RCGP+LRPCD | LRPCD | STD |
| 4K35. | Cerv.smear - viral infl.unsp. | 269963000 | RCGP+LRPCD | LRPCD | STD |
| 4K36. | Cervical smear - wart virus | 269964006 | RCGP+LRPCD | LRPCD | STD |
| 4K37. | Cervical smear - herpes | 168421003 | RCGP+LRPCD | LRPCD | STD |
| 4K3A. | Cervical smear: koilocytosis | 168424006 | RCGP+LRPCD | LRPCD | STD |
| 4K3D. | HPV - Human papillomavirus test positive |  | LRPCD_ONLY | LRPCD | STD |
| 4K3E. | HPV - Human papillomavirus test negative |  | LRPCD_ONLY | LRPCD | STD |
| 65P7. | Venereal disease contact | 444451006 | ALL_THREE | LRPCD | STD |
| 65P8. | AIDS contact | 444356002 | ALL_THREE | LRPCD | STD |
| 65PJ. | Chlamydia trachomatis contact | 444418002 | RCGP+LRPCD | LRPCD | STD |
| 65PK. | Gonorrhoea contact | 444376008 | RCGP+LRPCD | LRPCD | STD |
| 65PL. | Hepatitis B contact |  | LRPCD_ONLY | LRPCD | STD |
| 65PM. | Hepatitis C contact |  | LRPCD_ONLY | LRPCD | STD |
| 65PN. | Syphilis contact | 444380003 | RCGP+LRPCD | LRPCD | STD |
| 65PP. | Trichomonas vaginalis contact | 200401000000102 | RCGP+LRPCD | LRPCD | STD |
| 65PQ. | Genital herpes simplex contact | 444487004 | RCGP+LRPCD | LRPCD | STD |
| 65PR. | Human immunodeficiency virus contact | 200681000000109 | RCGP+LRPCD | LRPCD | STD |
| 65PS. | Sexually transmitted infection contact | 281635007 | RCGP+LRPCD | LRPCD | STD |
| 65Q7. | Viral hepatitis carrier |  | LRPCD_ONLY | LRPCD | STD |
| 65Q8. | Gonorrhoea carrier | 170490008 | RCGP+LRPCD | LRPCD | STD |
| 65Q9. | Venereal disease carrier NOS | 1094401000000104 | ALL_THREE | LRPCD | STD |
| 65QA. | AIDS carrier | 699433000 | ALL_THREE | LRPCD | STD |
| 65VE. | Notification of AIDS | 170530008 | ALL_THREE | LRPCD | STD |
| 66j.. | Human immunodeficiency virus monitoring | 504871000000109 | RCGP+LRPCD | LRPCD | STD |
| 66j0. | Human immunodeficiency virus annual review | 504901000000109 | RCGP+LRPCD | LRPCD | STD |
| 677L. | Chlamydia screening counselling | 200641000000101 | RCGP+LRPCD | LRPCD | STD |
| 677M. | Gonorrhoea screening counselling | 200801000000100 | RCGP+LRPCD | LRPCD | STD |
| 677N. | HIV screening counselling | 200901000000108 | RCGP+LRPCD | LRPCD | STD |
| 677P. | Syphilis screening counselling | 204661000000108 | RCGP+LRPCD | LRPCD | STD |
| 677Q. | Hepatitis C screening counselling | 204671000000101 | RCGP+LRPCD | LRPCD | STD |
| 677R. | Hepatitis B screening counselling | 204681000000104 | RCGP+LRPCD | LRPCD | STD |
| 679K9 | Education about prevention of sexually transmitted disease | 439057000 | RCGP+LRPCD | LRPCD | STD |
| 6826. | Trachoma screening |  | LRPCD_ONLY | LRPCD | STD |
| 6827 | AIDS (HTLV-III) screening | 171121004 | RCGP+ALBASOFT | DMWB |  |
| 6827. | AIDS (HTLV-III) screening |  | LRPCD_ONLY | LRPCD | STD |
| 6828. | Hepatitis B screening |  | LRPCD_ONLY | LRPCD | STD |
| 68280 | Hepatitis B screening required |  | LRPCD_ONLY | LRPCD | STD |
| 6829. | Hepatitis C screening |  | LRPCD_ONLY | LRPCD | STD |
| 682A. | Hepatitis C screening not offered |  | LRPCD_ONLY | LRPCD | STD |
| 6832 | Venereal disease screening | 171128005 | RCGP+ALBASOFT | DMWB |  |
| 6832. | Venereal disease screening |  | LRPCD_ONLY | LRPCD | STD |
| 683C. | Chlamydia trachomatis screening | 442487003 | RCGP+LRPCD | LRPCD | STD |
| 685N. | HPV - Human papillomavirus test consent given | 391144006 | RCGP+LRPCD | LRPCD | STD |
| 685O. | HPV - Human papillomavirus test declined |  | LRPCD_ONLY | LRPCD | STD |
| 685P. | HPV - Human papillomavirus test positive |  | LRPCD_ONLY | LRPCD | STD |
| 685Q. | HPV - Human papillomavirus test negative |  | LRPCD_ONLY | LRPCD | STD |
| 68K7. | Urine screen for chlamydia | 412761009 | RCGP+LRPCD | LRPCD | STD |
| 77323 | Cauterisation of perianal warts NEC | 449013002 | RCGP+LRPCD | LRPCD | STD |
| 77324 | Cryotherapy to perianal warts | 174342008 | RCGP+LRPCD | LRPCD | STD |
| 77325 | Painting of perianal warts | 174343003 | RCGP+LRPCD | LRPCD | STD |
| 7D033 | Cauterisation of lesion of vulva |  | LRPCD_ONLY | LRPCD | STD |
| 7D035 | Painting of vulval warts | 176610008 | RCGP+LRPCD | LRPCD | STD |
| 7P1A0 | Human immunodeficiency virus blood test | 230091000000109 | RCGP+LRPCD | LRPCD | STD |
| 7Q052 | Hepatitis B treatment drugs Band 1 |  | LRPCD_ONLY | LRPCD | STD |
| 7Q053 | Respiratory syncytial virus treatment and Hepatitis C treatment drugs Band 1 |  | LRPCD_ONLY | LRPCD | STD |
| 8B6e. | Post exposure prophylaxis after sexual exposure | 768841000000107 | RCGP+LRPCD | LRPCD | STD |
| 8BB5. | 12 week virologic response to hepatitis C treatment | 829241000000108 | RCGP+LRPCD | LRPCD | STD |
| 8CAd. | Pt ad notify sexual partners of sexual transmitted infection | 198781000000103 | RCGP+LRPCD | LRPCD | STD |
| 8CAE. | Patient advised about the risks of HIV | 183083004 | ALL_THREE | LRPCD | STD |
| 8CP9. | Discussion about HIV post exposure prophylaxis | 835401000000109 | RCGP+LRPCD | LRPCD | STD |
| 8HBQ0 | Sexually transmitted infection in-house follow-up | 864511000000102 | RCGP+LRPCD | LRPCD | STD |
| 8Hle. | Referral to community HIV nurse specialist | 817381000000107 | RCGP+LRPCD | LRPCD | STD |
| 8HTa. | Referral to genitourinary clinic | 415272006 | RCGP_ONLY | DMWB |  |
| 8HTR. | Referral to sexually transmitted infections clinic | 412712007 | RCGP+LRPCD | LRPCD | STD |
| 8HVP. | Private referral to venereologist | 183905006 | RCGP+LRPCD | LRPCD | STD |
| 8I3o. | Gonorrhoea screening declined | 200651000000103 | RCGP+LRPCD | LRPCD | STD |
| 8I3p. | HIV screening declined |  | LRPCD_ONLY | LRPCD | STD |
| 8I3t. | Syphilis screening declined | 202261000000101 | RCGP_ONLY | DMWB |  |
| 8I3T. | Chlamydia screening declined | 412718006 | RCGP_ONLY | DMWB |  |
| 8I3u. | Hepatitis B screening declined |  | LRPCD_ONLY | LRPCD | STD |
| 8I3v. | Hepatitis C screening declined |  | LRPCD_ONLY | LRPCD | STD |
| 9ka.. | Urine neisseria gonorrhoeae test positive - enhan serv admin | 355251000000105 | RCGP+LRPCD | LRPCD | STD |
| 9kb.. | Urine neisseria gonorrhoeae test negative - enhan serv admin | 355281000000104 | RCGP+LRPCD | LRPCD | STD |
| 9kF.. | Specialised sexual health - enhanced services administration | 166401000000102 | RCGP+LRPCD | LRPCD | STD |
| 9kF0. | Specialised sexual health - enhanced service completed | 166491000000109 | RCGP+LRPCD | LRPCD | STD |
| 9kF1. | Patient reviewed following treatment for STD - enh ser admin | 355161000000101 | RCGP+LRPCD | LRPCD | STD |
| 9kF2. | Urine screen for gonorrhoea - enhanced services administratn | 362881000000103 | RCGP+LRPCD | LRPCD | STD |
| 9kF3. | Counselling for genital herpes screening - enhanc serv admin | 363091000000104 | RCGP+LRPCD | LRPCD | STD |
| 9kF4. | Syphilis screen 3 month post treatment - enhanced serv admin | 355221000000100 | RCGP+LRPCD | LRPCD | STD |
| 9kF5. | Syphilis screen 6 month post treatment - enhanced serv admin | 355651000000107 | RCGP+LRPCD | LRPCD | STD |
| 9kF6. | Syphilis screen 1 year post treatment - enhanced serv admin | 355681000000101 | RCGP+LRPCD | LRPCD | STD |
| 9kF8. | Treatment of recurrent genital herpes - enhanced services ad | 364771000000102 | RCGP+LRPCD | LRPCD | STD |
| 9kl.. | HIV pos gen health check serv declind - enhanc service admin | 504931000000103 | RCGP+LRPCD | LRPCD | STD |
| 9kR.. | Chronic hepatitis annual review - enhanced services administration |  | LRPCD_ONLY | LRPCD | STD |
| 9kT.. | Hepatitis C screening negative - enhanced services administration |  | LRPCD_ONLY | LRPCD | STD |
| 9kV.. | Hepatitis C screening positive - enhanced services administration |  | LRPCD_ONLY | LRPCD | STD |
| 9kW.. | Hepatitis B screening negative - enhanced services administration |  | LRPCD_ONLY | LRPCD | STD |
| 9kX.. | Hepatitis status 6 months post treatment - enhanced services administration |  | LRPCD_ONLY | LRPCD | STD |
| 9kZ.. | Hepatitis B screening positive - enhanced services administration |  | LRPCD_ONLY | LRPCD | STD |
| 9mN.. | Human immunodeficiency virus infection monitoring invitation | 894621000000106 | RCGP+LRPCD | LRPCD | STD |
| 9mN0. | HIV infection monitoring telephone invitation | 894641000000104 | RCGP+LRPCD | LRPCD | STD |
| 9mN00 | HIV infection monitoring first telephone invitation | 894661000000103 | RCGP+LRPCD | LRPCD | STD |
| 9mN01 | HIV infection monitoring second telephone invitation | 894781000000104 | RCGP+LRPCD | LRPCD | STD |
| 9mN02 | HIV infection monitoring third telephone invitation | 894801000000103 | RCGP+LRPCD | LRPCD | STD |
| 9N0L. | Seen in GU medicine clinic | 185180001 | RCGP_ONLY | DMWB |  |
| 9Na4. | Consultation for complex sexual health need | 839551000000107 | RCGP+LRPCD | LRPCD | STD |
| 9NgR. | On hepatitis C treatment plan |  | LRPCD_ONLY | LRPCD | STD |
| 9NiP. | Did not attend genitourinary medicine clinic | 503241000000102 | RCGP_ONLY | DMWB |  |
| 9NJu. | In-house genitourinary medicine | 786221000000101 | RCGP+LRPCD | LRPCD | STD |
| 9NJu0 | In-house genitourinary medicine first appointment | 786251000000106 | RCGP+LRPCD | LRPCD | STD |
| 9NJu1 | In-house genitourinary medicine follow-up appointment | 787781000000107 | RCGP+LRPCD | LRPCD | STD |
| 9NJu2 | In-house genitourinary medicine discharge | 787801000000108 | RCGP+LRPCD | LRPCD | STD |
| 9Nt10 | Seen by community HIV (human immunodeficiency virus) nurse | 862191000000107 | RCGP+LRPCD | LRPCD | STD |
| 9Op0. | HIV screening offered | 1103711000000100 | RCGP+LRPCD | LRPCD | STD |
| 9Op1. | Hepatitis C screening offered |  | LRPCD_ONLY | LRPCD | STD |
| 9Op2. | Hepatitis B screening offered |  | LRPCD_ONLY | LRPCD | STD |
| 9Oq0. | Chlamydia test offered | 200591000000105 | RCGP+LRPCD | LRPCD | STD |
| 9Oq1. | Syphilis screening offered | 202241000000102 | RCGP+LRPCD | LRPCD | STD |
| 9Oq4. | Chlamydia screening programme test kit issued | 504751000000108 | RCGP+LRPCD | LRPCD | STD |
| 9OqB. | Sexually transmitted infection screening offered | 835261000000109 | RCGP+LRPCD | LRPCD | STD |
| A063. | Intestinal trichomoniasis | 67915005 | RCGP+LRPCD | LRPCD | STD |
| A541. | Genital herpes simplex | 33839006 | RCGP+LRPCD | LRPCD | STD |
| A5410 | Genital herpes unspecified | 10754701000119100 | RCGP+LRPCD | LRPCD | STD |
| A5411 | Herpetic vulvovaginitis | 27420004 | RCGP+LRPCD | LRPCD | STD |
| A5412 | Herpetic ulceration of vulva | 59819007 | RCGP+LRPCD | LRPCD | STD |
| A5413 | Herpetic infection of penis | 10227000 | RCGP+LRPCD | LRPCD | STD |
| A5414 | Herpesviral infection of perianal skin and rectum | 186537009 | RCGP+LRPCD | LRPCD | STD |
| A5415 | Anogenital herpesviral infection | 186538004 | RCGP+LRPCD | LRPCD | STD |
| A5416 | Genital herpes simplex type 1 | 440714005 | RCGP+LRPCD | LRPCD | STD |
| A5417 | Genital herpes simplex type 2 | 423391007 | RCGP+LRPCD | LRPCD | STD |
| A5418 | Recurrent genital herpes simplex type 1 | 439912007 | RCGP+LRPCD | LRPCD | STD |
| A5419 | Recurrent genital herpes simplex type 2 | 439913002 | RCGP+LRPCD | LRPCD | STD |
| A541z | Genital herpes simplex NOS | 402894005 | RCGP+LRPCD | LRPCD | STD |
| A54x1 | Herpes simplex meningitis |  | LRPCD_ONLY | LRPCD | STD |
| A57y5 | Monkeypox | 359814004 | RCGP_ONLY | DMWB |  |
| A7... | Other viral and chlamydial diseases | 543791000000108 | RCGP+LRPCD | LRPCD | STD |
| A702. | Viral hepatitis B with coma |  | LRPCD_ONLY | LRPCD | STD |
| A7020 | Acute hepatitis B with delta agent (coinfection) with hepatic coma |  | LRPCD_ONLY | LRPCD | STD |
| A703. | Viral (serum) hepatitis B |  | LRPCD_ONLY | LRPCD | STD |
| A7030 | Acute hepatitis B with delta-agent (coinfection) without hepatic coma |  | LRPCD_ONLY | LRPCD | STD |
| A704. | Other specified viral hepatitis with coma |  | LRPCD_ONLY | LRPCD | STD |
| A7040 | Viral hepatitis C with coma |  | LRPCD_ONLY | LRPCD | STD |
| A704z | Other specified viral hepatitis with hepatic coma NOS |  | LRPCD_ONLY | LRPCD | STD |
| A705. | Other specified viral hepatitis without coma |  | LRPCD_ONLY | LRPCD | STD |
| A7050 | Viral hepatitis C without mention of hepatic coma |  | LRPCD_ONLY | LRPCD | STD |
| A7051 | Acute delta-(super)infection of hepatitis B carrier |  | LRPCD_ONLY | LRPCD | STD |
| A7054 | Hepatitis non A non B |  | LRPCD_ONLY | LRPCD | STD |
| A705z | Other specified viral hepatitis without mention of hepatic coma NOS |  | LRPCD_ONLY | LRPCD | STD |
| A706. | Unspecified viral hepatitis with coma |  | LRPCD_ONLY | LRPCD | STD |
| A707. | Chronic viral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| A7070 | Chronic viral hepatitis B with delta-agent |  | LRPCD_ONLY | LRPCD | STD |
| A7071 | Chronic viral hepatitis B without delta-agent |  | LRPCD_ONLY | LRPCD | STD |
| A7072 | Chronic viral hepatitis C |  | LRPCD_ONLY | LRPCD | STD |
| A7073 | Chronic viral hepatitis B |  | LRPCD_ONLY | LRPCD | STD |
| A707X | Chronic viral hepatitis, unspecified |  | LRPCD_ONLY | LRPCD | STD |
| A708. | Viral hepatitis with hepatic coma |  | LRPCD_ONLY | LRPCD | STD |
| A709. | Viral hepatitis without hepatic coma |  | LRPCD_ONLY | LRPCD | STD |
| A70A. | Hepatitis C genotype 1 |  | LRPCD_ONLY | LRPCD | STD |
| A70B. | Hepatitis C genotype 2 |  | LRPCD_ONLY | LRPCD | STD |
| A70C. | Hepatitis C genotype 3 |  | LRPCD_ONLY | LRPCD | STD |
| A70D. | Hepatitis C genotype 4 |  | LRPCD_ONLY | LRPCD | STD |
| A70E. | Hepatitis C genotype 5 |  | LRPCD_ONLY | LRPCD | STD |
| A70F. | Hepatitis C genotype 6 |  | LRPCD_ONLY | LRPCD | STD |
| A70G. | Acute hepatitis C |  | LRPCD_ONLY | LRPCD | STD |
| A70z. | Unspecified viral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| A70z0 | Hepatitis C |  | LRPCD_ONLY | LRPCD | STD |
| A70z1 | Acute viral hepatitis NOS |  | LRPCD_ONLY | LRPCD | STD |
| A781. | Viral warts | 57019003 | RCGP_ONLY | DMWB |  |
| A7812 | Genital warts | 266113007 | ALL_THREE | LRPCD | STD |
| A7813 | Perianal warts | 266114001 | RCGP+LRPCD | LRPCD | STD |
| A7817 | Recurrent genital warts | 868341000000102 | RCGP+LRPCD | LRPCD | STD |
| A7852 | Cytomegaloviral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| A788. | Acquired immune deficiency syndrome | 62479008 | ALL_THREE | LRPCD | STD |
| A7880 | Acute human immunodeficiency virus infection | 111880001 | ALL_THREE | LRPCD | STD |
| A7881 | Asymptomatic human immunodeficiency virus infection | 91947003 | ALL_THREE | LRPCD | STD |
| A7882 | HIV infection with persistent generalised lymphadenopathy | 95892003 | ALL_THREE | LRPCD | STD |
| A7883 | Human immunodeficiency virus with constitutional disease | 186706006 | ALL_THREE | LRPCD | STD |
| A7884 | Human immunodeficiency virus with neurological disease | 186707002 | ALL_THREE | LRPCD | STD |
| A7885 | Human immunodeficiency virus with secondary infection | 186708007 | ALL_THREE | LRPCD | STD |
| A7886 | Human immunodeficiency virus with secondary cancers | 713572001 | ALL_THREE | LRPCD | STD |
| A788U | HIV disease result/haematological+immunologic abnorms,NEC | 943041000000105 | ALL_THREE | LRPCD | STD |
| A788V | HIV disease resulting in multiple diseases CE | 86406008 | ALL_THREE | LRPCD | STD |
| A788y | Human immunodeficiency virus with other clinical findings | 664701000000103 | ALL_THREE | LRPCD | STD |
| A788z | Acquired human immunodeficiency virus infection syndrome NOS | 577001000000106 | ALL_THREE | LRPCD | STD |
| A789. | Human immunodef virus resulting in other disease | 81000119104 | ALL_THREE | LRPCD | STD |
| A7890 | HIV disease resulting in mycobacterial infection | 420818005 | ALL_THREE | LRPCD | STD |
| A7893 | HIV disease resulting in Pneumocystis carinii pneumonia | 420403001 | ALL_THREE | LRPCD | STD |
| A7895 | HIV disease resulting in Kaposi's sarcoma | 420524008 | ALL_THREE | LRPCD | STD |
| A7896 | HIV disease resulting in Burkitt's lymphoma | 713897006 | ALL_THREE | LRPCD | STD |
| A7897 | HIV dis resulting oth types of non-Hodgkin's lymphoma | 442537007 | ALL_THREE | LRPCD | STD |
| A7898 | HIV disease resulting in multiple malignant neoplasms | 186725009 | ALL_THREE | LRPCD | STD |
| A7899 | HIV disease resulting in lymphoid interstitial pneumonitis | 421671002 | ALL_THREE | LRPCD | STD |
| A789A | HIV disease resulting in wasting syndrome | 422003001 | ALL_THREE | LRPCD | STD |
| A78A. | Chlamydial infection | 105629000 | ALL_THREE | LRPCD | STD |
| A78A0 | Chlamydial infection of lower genitourinary tract | 186729003 | RCGP+LRPCD | LRPCD | STD |
| A78A1 | Chlamydial infection of pharynx | 232403001 | RCGP+LRPCD | LRPCD | STD |
| A78A2 | Chlamydial infection of anus and rectum | 186731007 | RCGP+LRPCD | LRPCD | STD |
| A78A3 | Chlamydial inf of pelviperitoneum oth genitourinary organs | 312099009 | ALL_THREE | LRPCD | STD |
| A78A4 | Chlamydial conjunctivitis | 231861005 | RCGP_ONLY | DMWB |  |
| A78A5 | Chlamydial infection of genital organs NEC |  | LRPCD_ONLY | LRPCD | STD |
| A798. | Retrovirus infection | 105635000 | RCGP+LRPCD | LRPCD | STD |
| A79B. | Human papilloma virus infection | 240532009 | RCGP+LRPCD | LRPCD | STD |
| A7y.. | Other specified viral or chlamydial diseases |  | LRPCD_ONLY | LRPCD | STD |
| A7y01 | Retrovirus as the cause of diseases classified to other chapters |  | LRPCD_ONLY | LRPCD | STD |
| A7y05 | Papillomavirus as the cause of diseases classified to other chapters |  | LRPCD_ONLY | LRPCD | STD |
| A7z.. | Other viral or chlamydial disease NOS |  | LRPCD_ONLY | LRPCD | STD |
| A9... | Syphilis and other venereal diseases | 8098009 | ALL_THREE | LRPCD | STD |
| A90.. | Congenital syphilis | 35742006 | ALL_THREE | LRPCD | STD |
| A900. | Early congenital syphilis with symptoms | 266125005 | ALL_THREE | LRPCD | STD |
| A901. | Early latent congenital syphilis | 186833000 | ALL_THREE | LRPCD | STD |
| A902. | Early congenital syphilis NOS | 4359001 | ALL_THREE | LRPCD | STD |
| A903. | Syphilitic interstitial keratitis | 44568006 | ALL_THREE | LRPCD | STD |
| A904. | Juvenile neurosyphilis | 266126006 | ALL_THREE | LRPCD | STD |
| A9041 | Congenital syphilitic encephalitis | 32735002 | ALL_THREE | LRPCD | STD |
| A9042 | Congenital syphilitic meningitis | 6267005 | ALL_THREE | LRPCD | STD |
| A905. | Other late congenital syphilis | 82323002 | ALL_THREE | LRPCD | STD |
| A9050 | Congenital syphilitic gumma | 87318008 | ALL_THREE | LRPCD | STD |
| A9051 | Hutchinson's teeth | 86443005 | ALL_THREE | LRPCD | STD |
| A9052 | Syphilitic saddle nose | 77782006 | ALL_THREE | LRPCD | STD |
| A9053 | Late congenital syphilitic oculopathy | 186842007 | ALL_THREE | LRPCD | STD |
| A905z | Other late congenital syphilis NOS | 186843002 | ALL_THREE | LRPCD | STD |
| A906. | Latent late congenital syphilis | 827006 | ALL_THREE | LRPCD | STD |
| A907. | Unspecified late congenital syphilis | 608551000000101 | ALL_THREE | LRPCD | STD |
| A90z. | Congenital syphilis NOS | 186845009 | ALL_THREE | LRPCD | STD |
| A91.. | Early symptomatic syphilis | 186846005 | ALL_THREE | LRPCD | STD |
| A910. | Primary genital syphilis | 186847001 | ALL_THREE | LRPCD | STD |
| A911. | Primary anal syphilis | 31015008 | ALL_THREE | LRPCD | STD |
| A912. | Other primary syphilis | 266127002 | ALL_THREE | LRPCD | STD |
| A9120 | Primary breast syphilis | 27460003 | ALL_THREE | LRPCD | STD |
| A9121 | Primary finger syphilis | 54274001 | ALL_THREE | LRPCD | STD |
| A9122 | Primary lip syphilis | 28198007 | ALL_THREE | LRPCD | STD |
| A9123 | Primary tonsil syphilis | 10345003 | ALL_THREE | LRPCD | STD |
| A912z | Other primary syphilis NOS | 154381009 | ALL_THREE | LRPCD | STD |
| A913. | Secondary syphilis of skin or mucus membranes | 186850003 | ALL_THREE | LRPCD | STD |
| A9130 | Secondary syphilis of anus | 77028001 | ALL_THREE | LRPCD | STD |
| A9131 | Secondary syphilis of mouth | 60528006 | ALL_THREE | LRPCD | STD |
| A9132 | Secondary syphilis of pharynx | 51960003 | ALL_THREE | LRPCD | STD |
| A9133 | Secondary syphilis of skin | 59233003 | ALL_THREE | LRPCD | STD |
| A9134 | Secondary syphilis of tonsils | 81339006 | ALL_THREE | LRPCD | STD |
| A9135 | Secondary syphilis of vulva | 52414005 | ALL_THREE | LRPCD | STD |
| A913z | Secondary syphilis of skin or mucus membranes NOS | 186852006 | ALL_THREE | LRPCD | STD |
| A914. | Adenopathy due to secondary syphilis | 59934002 | ALL_THREE | LRPCD | STD |
| A915. | Uveitis due to secondary syphilis | 186854007 | ALL_THREE | LRPCD | STD |
| A9150 | Syphilitic uveitis unspecified | 410478005 | ALL_THREE | LRPCD | STD |
| A9151 | Secondary syphilitic chorioretinitis | 66281009 | ALL_THREE | LRPCD | STD |
| A9152 | Secondary syphilitic iridocyclitis | 30080002 | ALL_THREE | LRPCD | STD |
| A915z | Secondary syphilitic uveitis NOS | 186857000 | ALL_THREE | LRPCD | STD |
| A916. | Secondary syphilis of viscera or bone | 266129004 | ALL_THREE | LRPCD | STD |
| A9160 | Secondary syphilitic periostitis | 69595007 | ALL_THREE | LRPCD | STD |
| A9161 | Secondary syphilitic hepatitis | 80770009 | ALL_THREE | LRPCD | STD |
| A916z | Secondary syphilis of viscera and bone NOS | 58227000 | ALL_THREE | LRPCD | STD |
| A917. | Secondary syphilis relapse | 186861006 | ALL_THREE | LRPCD | STD |
| A918. | Other forms of secondary syphilis | 240557004 | ALL_THREE | LRPCD | STD |
| A9180 | Acute secondary syphilitic meningitis | 186863009 | ALL_THREE | LRPCD | STD |
| A9181 | Syphilitic alopecia | 59307008 | ALL_THREE | LRPCD | STD |
| A918z | Other secondary syphilis NOS | 154382002 | ALL_THREE | LRPCD | STD |
| A919. | Unspecified secondary syphilis | 186865002 | ALL_THREE | LRPCD | STD |
| A92.. | Latent early syphilis | 186867005 | ALL_THREE | LRPCD | STD |
| A920. | Serological relapse after treatment of latent early syphilis | 186868000 | ALL_THREE | LRPCD | STD |
| A92z. | Latent early syphilis NOS | 266130009 | ALL_THREE | LRPCD | STD |
| A93.. | Cardiovascular syphilis | 83883001 | ALL_THREE | LRPCD | STD |
| A930. | Syphilitic aortic aneurysm | 12232008 | ALL_THREE | LRPCD | STD |
| A931. | Syphilitic aortitis | 20735004 | ALL_THREE | LRPCD | STD |
| A932. | Syphilitic endocarditis | 67391006 | ALL_THREE | LRPCD | STD |
| A9320 | Syphilitic endocarditis of unspecified valve | 186874000 | ALL_THREE | LRPCD | STD |
| A9321 | Syphilitic endocarditis of mitral valve | 186875004 | ALL_THREE | LRPCD | STD |
| A9322 | Syphilitic endocarditis of aortic valve | 278480000 | ALL_THREE | LRPCD | STD |
| A9323 | Syphilitic endocarditis of tricuspid valve | 186877007 | ALL_THREE | LRPCD | STD |
| A9324 | Syphilitic endocarditis of pulmonary valve | 186878002 | ALL_THREE | LRPCD | STD |
| A932z | Syphilitic endocarditis of heart valve NOS | 186879005 | ALL_THREE | LRPCD | STD |
| A93y. | Other specified cardiovascular system syphilis | 577011000000108 | ALL_THREE | LRPCD | STD |
| A93y0 | Syphilitic pericarditis | 3589003 | ALL_THREE | LRPCD | STD |
| A93y1 | Syphilitic myocarditis | 4082005 | ALL_THREE | LRPCD | STD |
| A93yz | Other specified cardiovascular system syphilis NOS | 186882000 | ALL_THREE | LRPCD | STD |
| A93z. | Cardiovascular syphilis NOS | 186883005 | ALL_THREE | LRPCD | STD |
| A94.. | Neurosyphilis | 26039008 | ALL_THREE | LRPCD | STD |
| A940. | Tabes dorsalis - neurosyphilis | 316841006 | ALL_THREE | LRPCD | STD |
| A941. | General paresis - neurosyphilis | 51928006 | ALL_THREE | LRPCD | STD |
| A942. | Syphilitic meningitis | 301086002 | ALL_THREE | LRPCD | STD |
| A943. | Asymptomatic neurosyphilis | 37754005 | ALL_THREE | LRPCD | STD |
| A94y. | Other specified neurosyphilis | 266133006 | ALL_THREE | LRPCD | STD |
| A94y0 | Syphilitic encephalitis | 26135000 | ALL_THREE | LRPCD | STD |
| A94y1 | Syphilitic parkinsonism | 38523005 | ALL_THREE | LRPCD | STD |
| A94y2 | Syphilitic disseminated retinochoroiditis | 77939001 | ALL_THREE | LRPCD | STD |
| A94y3 | Syphilitic optic atrophy | 22386003 | ALL_THREE | LRPCD | STD |
| A94y4 | Syphilitic retrobulbar neuritis | 36276008 | ALL_THREE | LRPCD | STD |
| A94y5 | Syphilitic acoustic neuritis | 19206003 | ALL_THREE | LRPCD | STD |
| A94y6 | Rupture of syphilitic cerebral aneurysm | 186893003 | ALL_THREE | LRPCD | STD |
| A94z. | Neurosyphilis NOS | 186884004 | ALL_THREE | LRPCD | STD |
| A95.. | Other forms of late syphilis with symptoms | 72083004 | ALL_THREE | LRPCD | STD |
| A950. | Syphilitic episcleritis | 11338007 | ALL_THREE | LRPCD | STD |
| A951. | Syphilis of lung | 8555001 | ALL_THREE | LRPCD | STD |
| A952. | Syphilitic peritonitis | 34964002 | ALL_THREE | LRPCD | STD |
| A953. | Syphilis of liver | 86028001 | ALL_THREE | LRPCD | STD |
| A954. | Syphilis of kidney | 59530001 | ALL_THREE | LRPCD | STD |
| A955. | Syphilis of bone | 50528008 | ALL_THREE | LRPCD | STD |
| A956. | Syphilis of muscle | 88943008 | ALL_THREE | LRPCD | STD |
| A957. | Syphilis of synovium, tendon or bursa | 186899004 | ALL_THREE | LRPCD | STD |
| A9570 | Syphilis of synovium | 37430004 | ALL_THREE | LRPCD | STD |
| A9571 | Syphilis of tendon | 49923008 | ALL_THREE | LRPCD | STD |
| A9572 | Syphilis of bursa | 23550005 | ALL_THREE | LRPCD | STD |
| A957z | Syphilis of synovium, tendon or bursa NOS | 186900009 | ALL_THREE | LRPCD | STD |
| A95y. | Other specified late syphilis | 562111000000104 | ALL_THREE | LRPCD | STD |
| A95z. | Late symptomatic syphilis NOS | 577061000000105 | ALL_THREE | LRPCD | STD |
| A96.. | Late latent syphilis | 186903006 | ALL_THREE | LRPCD | STD |
| A97.. | Other and unspecified syphilis | 76272004 | ALL_THREE | LRPCD | STD |
| A970. | Late syphilis unspecified | 186905004 | ALL_THREE | LRPCD | STD |
| A971. | Latent syphilis unspecified | 567541000000109 | ALL_THREE | LRPCD | STD |
| A97z. | Syphilis NOS | 186907007 | ALL_THREE | LRPCD | STD |
| A98.. | Gonococcal infections | 15628003 | ALL_THREE | LRPCD | STD |
| A980. | Acute gonorrhoea of lower genitourinary tract | 54825009 | ALL_THREE | LRPCD | STD |
| A9800 | Acute gonococcal Bartholinitis | 80604007 | ALL_THREE | LRPCD | STD |
| A9801 | Acute gonococcal urethritis | 29864006 | ALL_THREE | LRPCD | STD |
| A9802 | Acute gonococcal vulvovaginitis | 2390000 | ALL_THREE | LRPCD | STD |
| A980z | Acute gonorrhoea of lower genitourinary tract NOS | 577091000000104 | ALL_THREE | LRPCD | STD |
| A981. | Acute gonorrhoea of upper genitourinary tract | 50970007 | ALL_THREE | LRPCD | STD |
| A9810 | Acute unspecified gonorrhoea of upper genitourinary tract | 186911001 | ALL_THREE | LRPCD | STD |
| A9811 | Acute gonococcal cystitis | 24868007 | ALL_THREE | LRPCD | STD |
| A9812 | Acute gonococcal prostatitis | 111806005 | ALL_THREE | LRPCD | STD |
| A9813 | Acute gonococcal epididymo-orchitis | 30168008 | ALL_THREE | LRPCD | STD |
| A9814 | Acute gonococcal seminal vesiculitis | 65049003 | ALL_THREE | LRPCD | STD |
| A9815 | Acute gonococcal cervicitis | 20943002 | ALL_THREE | LRPCD | STD |
| A9816 | Acute gonococcal endometritis | 65295003 | ALL_THREE | LRPCD | STD |
| A9817 | Acute gonococcal salpingitis | 45377007 | ALL_THREE | LRPCD | STD |
| A981z | Acute gonorrhoea upper genitourinary tract NOS | 577111000000109 | ALL_THREE | LRPCD | STD |
| A982. | Chronic gonorrhoea lower genitourinary tract | 186915005 | ALL_THREE | LRPCD | STD |
| A9820 | Chronic gonococcal bartholinitis | 12373006 | ALL_THREE | LRPCD | STD |
| A9821 | Chronic gonococcal urethritis | 44412000 | ALL_THREE | LRPCD | STD |
| A9822 | Chronic gonococcal vulvovaginitis | 11906007 | ALL_THREE | LRPCD | STD |
| A982z | Chronic gonorrhoea of lower genitourinary tract NOS | 186916006 | ALL_THREE | LRPCD | STD |
| A983. | Chronic gonorrhoea of upper genitourinary tract | 80388004 | ALL_THREE | LRPCD | STD |
| A9830 | Chronic unspecified gonorrhoea of upper genitourinary tract | 186918007 | ALL_THREE | LRPCD | STD |
| A9831 | Chronic gonococcal cystitis | 88813005 | ALL_THREE | LRPCD | STD |
| A9832 | Chronic gonococcal prostatitis | 60893000 | ALL_THREE | LRPCD | STD |
| A9833 | Chronic gonococcal epididymo-orchitis | 35526001 | ALL_THREE | LRPCD | STD |
| A9834 | Chronic gonococcal seminal vesiculitis | 23975003 | ALL_THREE | LRPCD | STD |
| A9835 | Chronic gonococcal cervicitis | 76802005 | ALL_THREE | LRPCD | STD |
| A9836 | Chronic gonococcal endometritis | 31999004 | ALL_THREE | LRPCD | STD |
| A9837 | Chronic gonococcal salpingitis | 53529004 | ALL_THREE | LRPCD | STD |
| A983z | Chronic gonorrhoea of upper genitourinary tract NOS | 547711000000106 | ALL_THREE | LRPCD | STD |
| A984. | Gonococcal eye infection | 35876006 | ALL_THREE | LRPCD | STD |
| A9840 | Neonatal gonococcal conjunctivits | 28438004 | ALL_THREE | LRPCD | STD |
| A9842 | Gonococcal endophthalmia | 111807001 | ALL_THREE | LRPCD | STD |
| A9843 | Gonococcal keratitis | 40149008 | ALL_THREE | LRPCD | STD |
| A985. | Gonococcal joint infection | 44743006 | ALL_THREE | LRPCD | STD |
| A9851 | Gonococcal synovitis or tenosynovitis | 266138002 | ALL_THREE | LRPCD | STD |
| A9852 | Gonococcal bursitis | 46699001 | ALL_THREE | LRPCD | STD |
| A9853 | Gonococcal spondylitis | 53664003 | ALL_THREE | LRPCD | STD |
| A986. | Gonococcal pharynx infection | 74372003 | ALL_THREE | LRPCD | STD |
| A987. | Gonococcal proctitis | 42746002 | ALL_THREE | LRPCD | STD |
| A9870 | Gonococcal anal infection | 186931002 | ALL_THREE | LRPCD | STD |
| A98y0 | Gonococcal keratosis | 60335002 | ALL_THREE | LRPCD | STD |
| A98y1 | Gonococcal meningitis | 151004 | ALL_THREE | LRPCD | STD |
| A98y2 | Gonococcal pericarditis | 90428001 | ALL_THREE | LRPCD | STD |
| A98y3 | Gonococcal endocarditis | 61048000 | ALL_THREE | LRPCD | STD |
| A98y4 | Other gonococcal heart disease | 9241004 | ALL_THREE | LRPCD | STD |
| A98y5 | Gonococcal peritonitis | 186939000 | ALL_THREE | LRPCD | STD |
| A98y6 | Fitzhugh Curtis syndrome | 237041005 | ALL_THREE | LRPCD | STD |
| A99.. | Other venereal diseases | 634361000000106 | ALL_THREE | LRPCD | STD |
| A990. | Chancroid | 266143009 | ALL_THREE | LRPCD | STD |
| A991. | Lymphogranuloma venereum | 186946009 | ALL_THREE | LRPCD | STD |
| A9910 | Pharyngeal lymphogranuloma venereum | 446594000 | ALL_THREE | LRPCD | STD |
| A9911 | Rectal lymphogranuloma venereum | 447372001 | ALL_THREE | LRPCD | STD |
| A992. | Granuloma inguinale | 28867007 | ALL_THREE | LRPCD | STD |
| A993. | Reiter's disease / syndrome | 67224007 | ALL_THREE | LRPCD | STD |
| A994. | Nonspecific urethritis | 84619001 | ALL_THREE | LRPCD | STD |
| A995. | Nonspecific genital infection | 444458000 | RCGP+ALBASOFT | SEMANTIC |  |
| A99y. | Other specified venereal diseases | 634371000000104 | ALL_THREE | LRPCD | STD |
| A99z. | Venereal disease NOS | 611051000000101 | ALL_THREE | LRPCD | STD |
| A9y.. | Other specified syphilis or other venereal diseases | 186950002 | ALL_THREE | LRPCD | STD |
| A9z.. | Syphilis or venereal disease NOS | 607321000000101 | ALL_THREE | LRPCD | STD |
| AA... | Other spirochaetal diseases | 41116009 | RCGP_ONLY | DMWB |  |
| AD1.. | Trichomoniasis - trichomonas | 56335008 | RCGP+LRPCD | LRPCD | STD |
| AD10. | Urogenital trichomonas | 35089004 | RCGP+LRPCD | LRPCD | STD |
| AD100 | Unspecified urogenital trichomonas |  | LRPCD_ONLY | LRPCD | STD |
| AD101 | Trichomonal vulvovaginitis | 81598001 | RCGP+LRPCD | LRPCD | STD |
| AD102 | Trichomonal urethritis | 30116001 | RCGP+LRPCD | LRPCD | STD |
| AD103 | Trichomonal prostatitis | 71590000 | RCGP+LRPCD | LRPCD | STD |
| AD10z | Urogenital trichomonas NOS |  | LRPCD_ONLY | LRPCD | STD |
| AD1y. | Other specified site trichomonas |  | LRPCD_ONLY | LRPCD | STD |
| AD1z. | Trichomonas NOS |  | LRPCD_ONLY | LRPCD | STD |
| AD22. | Phthirus pubis - pubic lice | 71011005 | RCGP+LRPCD | LRPCD | STD |
| Ayu4. | [X]Infections with a predominantly sexual mode of transmiss | 187348005 | RCGP+LRPCD | LRPCD | STD |
| Ayu40 | [X]Early congenital syphilis, unspecified | 413891000000100 | RCGP+LRPCD | LRPCD | STD |
| Ayu41 | [X]Other late congenital syphilis, symptomatic | 187350002 | RCGP+LRPCD | LRPCD | STD |
| Ayu42 | [X]Late congenital syphilis, unspecified | 427851000000108 | RCGP+LRPCD | LRPCD | STD |
| Ayu43 | [X]Congenital syphilis, unspecified | 187352005 | RCGP+LRPCD | LRPCD | STD |
| Ayu44 | [X]Primary syphilis of other sites | 187353000 | RCGP+LRPCD | LRPCD | STD |
| Ayu45 | [X]Other secondary syphilis | 399271000000106 | RCGP+LRPCD | LRPCD | STD |
| Ayu46 | [X]Early syphilis, unspecified | 187355007 | RCGP+LRPCD | LRPCD | STD |
| Ayu47 | [X]Neurosyphilis, unspecified | 396281000000100 | RCGP+LRPCD | LRPCD | STD |
| Ayu48 | [X]Other symptomatic late syphilis | 278481001 | RCGP+LRPCD | LRPCD | STD |
| Ayu49 | [X]Late syphilis, unspecified | 187358009 | RCGP+LRPCD | LRPCD | STD |
| Ayu4A | [X]Syphilis, unspecified | 187359001 | RCGP+LRPCD | LRPCD | STD |
| Ayu4B | [X]Other gonococcal infections | 438971000000108 | RCGP+LRPCD | LRPCD | STD |
| Ayu4C | [X]Gonococcal infection, unspecified | 390531000000100 | RCGP+LRPCD | LRPCD | STD |
| Ayu4D | [X]Sexually transmitted chlamydial infection of other sites | 478751000000103 | RCGP+LRPCD | LRPCD | STD |
| Ayu4E | [X]Trichomoniasis of other sites |  | LRPCD_ONLY | LRPCD | STD |
| Ayu4F | [X]Trichomoniasis, unspecified |  | LRPCD_ONLY | LRPCD | STD |
| Ayu4G | [X]Anogenital herpes viral infection, unspecified |  | LRPCD_ONLY | LRPCD | STD |
| Ayu4H | [X]Other specifd predominantly sexually transmitted diseases | 187366000 | RCGP+LRPCD | LRPCD | STD |
| Ayu4J | [X]Unspecified sexually transmitted disease | 187367009 | RCGP+LRPCD | LRPCD | STD |
| Ayu4K | [X]Chlamydial infection of genitourinary tract, unspecified | 402081000000102 | RCGP+LRPCD | LRPCD | STD |
| Ayu4L | [X]Vulval warts | 237109002 | RCGP+LRPCD | LRPCD | STD |
| Ayu4M | [X]Perineal warts | 298128008 | RCGP+LRPCD | LRPCD | STD |
| Ayu4N | [X]Sexually transmitted infectious disease |  | LRPCD_ONLY | LRPCD | STD |
| Ayu6. | [X]Other diseases caused by chlamydiae | 471481000000108 | RCGP+LRPCD | LRPCD | STD |
| Ayu61 | [X]Other chlamydial diseases |  | LRPCD_ONLY | LRPCD | STD |
| Ayu62 | [X]Chlamydial infection, unspecified | 240590004 | RCGP+LRPCD | LRPCD | STD |
| AyuB1 | [X]Other chronic viral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| AyuB2 | [X]Chronic viral hepatitis, unspecified |  | LRPCD_ONLY | LRPCD | STD |
| AyuB3 | [X]Unspecified viral hepatitis with coma |  | LRPCD_ONLY | LRPCD | STD |
| AyuB4 | [X]Unspecified viral hepatitis without coma |  | LRPCD_ONLY | LRPCD | STD |
| AyuC. | [X]Human immunodeficiency virus disease | 468931000000102 | RCGP+LRPCD | LRPCD | STD |
| AyuC0 | [X]HIV disease resulting in other bacterial infections | 411831000000102 | RCGP+LRPCD | LRPCD | STD |
| AyuC1 | [X]HIV disease resulting in other viral infections | 441561000000104 | RCGP+LRPCD | LRPCD | STD |
| AyuC2 | [X]HIV disease resulting in other mycoses | 413621000000104 | RCGP+LRPCD | LRPCD | STD |
| AyuC3 | [X]HIV disease resulting in multiple infections | 186721000 | RCGP+LRPCD | LRPCD | STD |
| AyuC4 | [X]HIV disease resulting/other infectious+parasitic diseases | 418661000000104 | ALL_THREE | LRPCD | STD |
| AyuC5 | [X]HIV disease resulting/unspcf infectious+parasitic disease | 466811000000104 | RCGP+LRPCD | LRPCD | STD |
| AyuC6 | [X]HIV disease resulting in other non-Hodgkin's lymphoma | 442351000000104 | RCGP+LRPCD | LRPCD | STD |
| AyuC7 | [X]Hiv disease resulting in other malignant neoplasms of lymphoid, haematopoietic and related tissue |  | LRPCD_ONLY | LRPCD | STD |
| AyuC8 | [X]HIV disease resulting in other malignant neoplasms | 455571000000106 | RCGP+LRPCD | LRPCD | STD |
| AyuC9 | [X]HIV disease resulting in unspecified malignant neoplasm | 186712001 | RCGP+LRPCD | LRPCD | STD |
| AyuCA | [X]HIV disease resulting in multiple diseases CE | 187450003 | RCGP+LRPCD | LRPCD | STD |
| AyuCB | [X]Hiv disease resulting in haematological and immunological abnormalities, not elsewhere classified |  | LRPCD_ONLY | LRPCD | STD |
| AyuCC | [X]HIV disease resulting in other specified conditions | 428061000000103 | RCGP+LRPCD | LRPCD | STD |
| AyuCD | [X]Unspecified human immunodeficiency virus [HIV] disease | 439901000000106 | RCGP+LRPCD | LRPCD | STD |
| AyuD8 | [X]Retrovirus infections, not elsewhere classified |  | LRPCD_ONLY | LRPCD | STD |
| AyuKM | [X]Retrovirus as the cause of diseases classified to other chapters |  | LRPCD_ONLY | LRPCD | STD |
| B829. | Bowenoid papulosis | 402913004 | RCGP+LRPCD | LRPCD | STD |
| Eu024 | [X]Dementia in human immunodef virus [HIV] disease | 421529006 | ALL_THREE | LRPCD | STD |
| F0070 | Meningitis due to gonococcus |  | LRPCD_ONLY | LRPCD | STD |
| F0072 | Meningitis due to neurosyphilis |  | LRPCD_ONLY | LRPCD | STD |
| F0074 | Meningitis due to congenital syphilis |  | LRPCD_ONLY | LRPCD | STD |
| F0075 | Meningitis due to secondary syphilis | 192647003 | RCGP+LRPCD | LRPCD | STD |
| F0113 | Meningitis due to herpes simplex virus |  | LRPCD_ONLY | LRPCD | STD |
| F0304 | Encephalitis due to herpes simplex virus |  | LRPCD_ONLY | LRPCD | STD |
| F0331 | Encephalitis due to congenital syphilis | 192699001 | RCGP+LRPCD | LRPCD | STD |
| F0332 | Encephalitis due to syphilis unspecified | 192700000 | RCGP+LRPCD | LRPCD | STD |
| F4A54 | Keratitis due to syphilis | 193786000 | RCGP+LRPCD | LRPCD | STD |
| F4K44 | Argyll Robertson pupil | 4129001 | RCGP+LRPCD | LRPCD | STD |
| F4K46 | Adie's pupil syndrome | 24225004 | RCGP_ONLY | DMWB |  |
| G5002 | Acute pericarditis - syphilitic | 194907008 | RCGP+LRPCD | LRPCD | STD |
| G5005 | Acute pericarditis - gonococcal | 194910001 | RCGP+LRPCD | LRPCD | STD |
| G5112 | Endocarditis - gonococcal |  | LRPCD_ONLY | LRPCD | STD |
| G5204 | Acute myocarditis - syphilitic | 194947001 | RCGP+LRPCD | LRPCD | STD |
| G717. | Aortic aneurysm - syphilitic | 186871008 | RCGP+LRPCD | LRPCD | STD |
| G767. | Aortitis - syphilitic | 186872001 | RCGP+LRPCD | LRPCD | STD |
| Gy0.. | Cardiovascular syphilis | 154383007 | RCGP+LRPCD | LRPCD | STD |
| H233. | Chlamydial pneumonia | 233610007 | RCGP_ONLY | SEMANTIC |  |
| H57y5 | Lung disease with syphilis | 196139002 | RCGP+LRPCD | LRPCD | STD |
| J5500 | Peritonitis - gonococcal |  | LRPCD_ONLY | LRPCD | STD |
| J5501 | Peritonitis - syphilitic | 186898007 | RCGP+LRPCD | LRPCD | STD |
| J5504 | Chlamydial peritonitis | 197172005 | RCGP+LRPCD | LRPCD | STD |
| J615F | Syphilitic portal cirrhosis | 197305002 | RCGP+LRPCD | LRPCD | STD |
| J6321 | Hepatitis in late syphilis | 197347003 | RCGP+LRPCD | LRPCD | STD |
| J6322 | Hepatitis in secondary syphilis | 197348008 | RCGP+LRPCD | LRPCD | STD |
| K0y0. | Late syphilis of kidney | 197757004 | RCGP+LRPCD | LRPCD | STD |
| K1545 | Cystitis in gonorrhoea | 197848003 | RCGP+LRPCD | LRPCD | STD |
| K1547 | Cystitis in trichomoniasis | 197850006 | RCGP+LRPCD | LRPCD | STD |
| K17y. | Other urethritis | 31822004 | RCGP+LRPCD | LRPCD | STD |
| K17y0 | Urethritis unspecified |  | LRPCD_ONLY | LRPCD | STD |
| K17y1 | Urethral syndrome NOS |  | LRPCD_ONLY | LRPCD | STD |
| K17y2 | Skene's glands adenitis |  | LRPCD_ONLY | LRPCD | STD |
| K17y3 | Cowperitis |  | LRPCD_ONLY | LRPCD | STD |
| K17y4 | Urethral meatitis | 89656008 | RCGP+LRPCD | LRPCD | STD |
| K17y5 | Urethral meatal ulcer |  | LRPCD_ONLY | LRPCD | STD |
| K17y6 | Verumontanitis |  | LRPCD_ONLY | LRPCD | STD |
| K17y7 | Utriculus masculinus |  | LRPCD_ONLY | LRPCD | STD |
| K17yz | Other urethritis NOS |  | LRPCD_ONLY | LRPCD | STD |
| K2142 | Prostatitis in syphilis | 197966009 | RCGP+LRPCD | LRPCD | STD |
| K2144 | Prostatitis in gonorrhoea | 197967000 | RCGP+LRPCD | LRPCD | STD |
| K2146 | Prostatitis in trichomoniasis |  | LRPCD_ONLY | LRPCD | STD |
| K2416 | Chlamydial epididymitis | 236767000 | RCGP+LRPCD | LRPCD | STD |
| K4... | Female pelvic inflammatory diseases | 198130006 | RCGP_ONLY | DMWB |  |
| K4020 | Fallopian tube abscess | 398319002 | RCGP_ONLY | DMWB |  |
| K4026 | Salpingitis unspecified | 88157006 | RCGP_ONLY | DMWB |  |
| K403. | Acute parametritis and pelvic cellulitis | 237037006 | RCGP_ONLY | DMWB |  |
| K404z | Chronic pelvic inflammatory diseases NOS | 237044002 | RCGP_ONLY | DMWB |  |
| K409. | Acute pelvic inflammatory disease | 771412001 | RCGP_ONLY | SEMANTIC |  |
| K40y0 | Female syphilitic pelvic inflammatory disease | 198175009 | RCGP+LRPCD | LRPCD | STD |
| K40y1 | Female chlamydial pelvic inflammatory disease | 198176005 | RCGP+LRPCD | LRPCD | STD |
| K4209 | Chlamydia cervicitis | 237084006 | RCGP+LRPCD | LRPCD | STD |
| K44.. | Female gonococcal pelvic inflammatory disease | 198242009 | RCGP+LRPCD | LRPCD | STD |
| K4z.. | Female pelvic inflammatory disease NOS | 562441000000107 | RCGP_ONLY | SEMANTIC |  |
| L170. | Maternal syphilis in pregnancy/childbirth/puerperium | 199154009 | RCGP+LRPCD | LRPCD | STD |
| L1700 | Maternal syphilis, unspec whether in pregnancy or puerperium | 199155005 | RCGP+LRPCD | LRPCD | STD |
| L1701 | Maternal syphilis during pregnancy - baby delivered | 199156006 | RCGP+LRPCD | LRPCD | STD |
| L1702 | Maternal syphilis in puerperium - baby delivered | 199157002 | RCGP+LRPCD | LRPCD | STD |
| L1703 | Maternal syphilis during pregnancy - baby not yet delivered | 199158007 | RCGP+LRPCD | LRPCD | STD |
| L1704 | Maternal syphilis in puerperium - baby previously delivered | 199159004 | RCGP+LRPCD | LRPCD | STD |
| L170z | Maternal syphilis in pregnancy/childbirth/puerperium NOS | 199160009 | RCGP+LRPCD | LRPCD | STD |
| L171. | Maternal gonorrhoea during pregnancy/childbirth/puerperium | 199161008 | RCGP+LRPCD | LRPCD | STD |
| L1710 | Maternal gonorrhoea, unspec whether in pregnancy/puerperium | 593761000000107 | RCGP+LRPCD | LRPCD | STD |
| L1711 | Maternal gonorrhoea during pregnancy - baby delivered | 199163006 | RCGP+LRPCD | LRPCD | STD |
| L1712 | Maternal gonorrhoea in puerperium - baby delivered | 199164000 | RCGP+LRPCD | LRPCD | STD |
| L1713 | Maternal gonorrhoea in pregnancy - baby not yet delivered | 199165004 | RCGP+LRPCD | LRPCD | STD |
| L1714 | Maternal gonorrhoea in puerperium- baby previously delivered | 199166003 | RCGP+LRPCD | LRPCD | STD |
| L171z | Gonorrhoea during pregnancy, childbirth or the puerperium NOS |  | LRPCD_ONLY | LRPCD | STD |
| L172. | Other venereal diseases in pregnancy/childbirth/puerperium | 274118001 | ALL_THREE | LRPCD | STD |
| L1720 | Other maternal venereal disease, unspec pregnancy/puerperium | 199169005 | ALL_THREE | LRPCD | STD |
| L1722 | Other maternal venereal disease in puerperium-baby delivered | 199170006 | ALL_THREE | LRPCD | STD |
| L172z | Other mat. venereal dis. in pregnancy/childbirth/puerp. NOS | 27075004 | ALL_THREE | LRPCD | STD |
| L179. | Human immunodeficiency [HIV] disease complicating pregnancy, childbirth and the puerperium |  | LRPCD_ONLY | LRPCD | STD |
| Lyu70 | [X]Other infections with a predominantly sexual mode of transmission complicating pregnancy childbirth and the puerperium |  | LRPCD_ONLY | LRPCD | STD |
| N011. | Sexually acquired reactive arthropathy | 267883008 | RCGP+LRPCD | LRPCD | STD |
| N0110 | Sexually acquired reactive arthropathy of unspecified site |  | LRPCD_ONLY | LRPCD | STD |
| N0111 | Sexually acquired reactive arthropathy of shoulder region | 201474006 | RCGP+LRPCD | LRPCD | STD |
| N0112 | Sexually acquired reactive arthropathy of the upper arm |  | LRPCD_ONLY | LRPCD | STD |
| N0113 | Sexually acquired reactive arthropathy of the forearm |  | LRPCD_ONLY | LRPCD | STD |
| N0114 | Sexually acquired reactive arthropathy of the hand | 201477004 | RCGP+LRPCD | LRPCD | STD |
| N0115 | Sexually acquired reactive arthropathy of the pelvis/thigh | 201478009 | RCGP+LRPCD | LRPCD | STD |
| N0116 | Sexually acquired reactive arthropathy of the lower leg |  | LRPCD_ONLY | LRPCD | STD |
| N0117 | Sexually acquired reactive arthropathy of the ankle and foot | 201480003 | RCGP+LRPCD | LRPCD | STD |
| N011x | Sexually acquired reactive arthropathy of multiple sites | 201481004 | RCGP+LRPCD | LRPCD | STD |
| N011y | Sexually acquired reactive arthropathy of other specified site |  | LRPCD_ONLY | LRPCD | STD |
| N011z | Sexually acquired reactive arthropathy NOS |  | LRPCD_ONLY | LRPCD | STD |
| N0381 | Postinfective arthropathy in syphilis | 201738001 | RCGP+LRPCD | LRPCD | STD |
| N2227 | Syphilitic bursitis | 202933002 | RCGP+LRPCD | LRPCD | STD |
| PK03. | Congenital splenomegaly | 56118002 | RCGP_ONLY | SEMANTIC |  |
| Q3106 | Congenital pneumonia due to Chlamydia | 206289001 | RCGP+LRPCD | LRPCD | STD |
| Q4020 | Congenital herpes simplex | 91576008 | RCGP+LRPCD | LRPCD | STD |
| Q4067 | Neonatal dacryocystitis or conjunctivitis due to chlamydiae | 268842008 | RCGP+LRPCD | LRPCD | STD |
| Q409. | Congenital viral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| Q4091 | Congenital hepatitis B infection |  | LRPCD_ONLY | LRPCD | STD |
| Q409y | Other specified congenital viral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| Q409z | Congenital viral hepatitis NOS |  | LRPCD_ONLY | LRPCD | STD |
| R109. | [D]Laboratory evidence of human immunodeficiency virus [HIV] | 499821000000104 | ALL_THREE | LRPCD | STD |
| R156. | [D]False positive serological syphilis test | 274684006 | RCGP+LRPCD | LRPCD | STD |
| R1560 | [D]False positive Wasserman test | 442377003 | RCGP+LRPCD | LRPCD | STD |
| R156z | [D]False positive serological syphilis test NOS |  | LRPCD_ONLY | LRPCD | STD |
| ZV016 | [V]Contact with or exposure to venereal disease | 464851000000107 | ALL_THREE | LRPCD | STD |
| ZV019 | [V]Contact with+exposure to human immunodeficiency virus | 428541000000106 | ALL_THREE | LRPCD | STD |
| ZV01A | [V]Asymptomatic human immunodeficency virus infection status | 427921000000108 | ALL_THREE | LRPCD | STD |
| ZV01B | [V]Contact with and exposure to viral hepatitis |  | LRPCD_ONLY | LRPCD | STD |
| ZV026 | [V]Viral hepatitis carrier |  | LRPCD_ONLY | LRPCD | STD |
| ZV027 | [V]Gonorrhoea carrier | 428141000000103 | RCGP+LRPCD | LRPCD | STD |
| ZV028 | [V]Other venereal disease carrier | 315675000 | ALL_THREE | LRPCD | STD |
| ZV029 | [V]Carrier of human T-lymphotropic virus type-1 infect | 427251000000107 | RCGP+LRPCD | LRPCD | STD |
| ZV02B | [V]Hepatitis B carrier |  | LRPCD_ONLY | LRPCD | STD |
| ZV02C | [V]Hepatitis C carrier |  | LRPCD_ONLY | LRPCD | STD |
| ZV138 | [V]Personal history of pelvic inflammatory disease | 1090431000000102 | RCGP_ONLY | DMWB |  |
| ZV19B | [V]Family history of human immunodefiency virus disease | 438998000 | RCGP+ALBASOFT | DMWB |  |
| ZV6D4 | [V]Human immunodefiency virus counselling | 313077009 | ALL_THREE | LRPCD | STD |
| ZV745 | [V]Screening for venereal disease | 469321000000107 | ALL_THREE | LRPCD | STD |

### Termination of Pregnancy (163 codes)

| ReadV2Code | ReadV2 Term | SNOMED ConceptID | CodeSource | MappingSource | LRPCD |
|---|---|---|---|---|---|
| 1543 | H/O: abortion | 713651007 | RCGP+ALBASOFT | DMWB |  |
| 15432 | H/O: 1 abortion | 161756005 | RCGP+ALBASOFT | DMWB |  |
| 15433 | H/O: 2 abortions | 161757001 | RCGP+ALBASOFT | DMWB |  |
| 15434 | H/O: 3 abortions | 161758006 | RCGP+ALBASOFT | DMWB |  |
| 15435 | H/O: 4 abortions | 161759003 | RCGP+ALBASOFT | DMWB |  |
| 15436 | H/O: 5 abortions | 161760008 | RCGP+ALBASOFT | DMWB |  |
| 15437 | H/O: 6 abortions | 161761007 | RCGP+ALBASOFT | DMWB |  |
| 1543Z | H/O: abortion NOS | 161762000 | RCGP+ALBASOFT | DMWB |  |
| 1547 | H/O: medical termination of pregnancy | 412758008 | RCGP_ONLY | DMWB |  |
| 1547. | H/O: medical termination of pregnancy | 111461000000109 | RCGP_ONLY | SEMANTIC |  |
| 389B. | Assessment for termination of pregnancy | 707998009 | RCGP_ONLY | DMWB |  |
| 6776 | Preg. termination counselling | 10383002 | RCGP_ONLY | DMWB |  |
| 67760 | Post-termination counselling | 225326008 | RCGP_ONLY | DMWB |  |
| 67761 | Pre-termination counselling | 225327004 | RCGP_ONLY | DMWB |  |
| 7E066 | Hysterotomy and termination of pregnancy | 18302006 | RCGP_ONLY | DMWB |  |
| 7E070 | Dilation cervix uteri & curettage products conception uterus | 265062002 | RCGP+ALBASOFT | DMWB |  |
| 7E083 | Extraction of menses | 386641000 | RCGP_ONLY | DMWB |  |
| 7E084 | Suction termination of pregnancy | 391897002 | RCGP+ALBASOFT | DMWB |  |
| 7E085 | Dilation of cervix and extraction termination of pregnancy | 29682007 | RCGP+ALBASOFT | DMWB |  |
| 7E086 | Termination of pregnancy NEC | 386639001 | RCGP+ALBASOFT | DMWB |  |
| 7E0B. | Introduction of abortifacient into uterine cavity | 176849008 | RCGP_ONLY | DMWB |  |
| 7E0B0 | Intraamniotic injection of prostaglandin | 176850008 | RCGP_ONLY | DMWB |  |
| 7E0B1 | Intraamniotic injection of abortifacient NEC | 450678004 | RCGP_ONLY | SEMANTIC |  |
| 7E0B2 | Extraamniotic injection of prostaglandin | 176852000 | RCGP_ONLY | DMWB |  |
| 7E0B3 | Extraamniotic injection of abortifacient NEC | 450679007 | RCGP_ONLY | SEMANTIC |  |
| 7E0B4 | Insertion of prostaglandin abortifacient pessary | 176854004 | RCGP_ONLY | DMWB |  |
| 7E0B5 | Insertion of abortifacient pessary NEC | 285434006 | RCGP_ONLY | DMWB |  |
| 7E0Bz | Introduction of abortifacient into uterine cavity NOS | 176857006 | RCGP_ONLY | SEMANTIC |  |
| 7F02. | Selective destruction of fetus | 265633004 | RCGP_ONLY | DMWB |  |
| 7F020 | Early selective feticide | 177095006 | RCGP_ONLY | DMWB |  |
| 7F021 | Late selective feticide | 177096007 | RCGP_ONLY | DMWB |  |
| 7F02y | Other specified selective destruction of fetus | 562001000000102 | RCGP_ONLY | SEMANTIC |  |
| 7F02z | Selective destruction of fetus NOS | 177099000 | RCGP_ONLY | SEMANTIC |  |
| 7F09. | Destruction of fetus | 906211000000103 | RCGP_ONLY | DMWB |  |
| 7F09z | Unspecified destruction of fetus | 1287687008 | RCGP_ONLY | SEMANTIC |  |
| 8Cg.. | Pregnancy termination care | 386394001 | RCGP_ONLY | DMWB |  |
| 8H7W. | Refer to TOP counselling | 183606009 | RCGP+ALBASOFT | DMWB |  |
| 8Hh3. | Self referral to termination of pregnancy service | 769411000000104 | RCGP_ONLY | DMWB |  |
| 8HHV. | Referral for termination of pregnancy | 415262008 | RCGP_ONLY | DMWB |  |
| 8M6.. | Requests pregnancy termination | 184005004 | RCGP+ALBASOFT | DMWB |  |
| 956.. | Form A - therapeutic abortion | 9391000000101 | RCGP+ALBASOFT | DMWB |  |
| 9561 | Form A - eligible | 9401000000103 | RCGP+ALBASOFT | DMWB |  |
| 9562 | Form A - signed | 9411000000101 | RCGP+ALBASOFT | DMWB |  |
| 9563 | Form A - refused to sign | 9421000000107 | RCGP+ALBASOFT | DMWB |  |
| 9563. | Form A - refused to sign | 10671000000104 | RCGP+ALBASOFT | SEMANTIC |  |
| 956Z. | Form A - NOS | 13961000000108 | RCGP+ALBASOFT | DMWB |  |
| 9Ea.. | Reason for termination of pregnancy | 310506006 | RCGP+ALBASOFT | DMWB |  |
| 9Ea0. | Risk life pregnant woman greater than if pregnancy terminatd | 185020000 | RCGP+ALBASOFT | SEMANTIC |  |
| L0... | Pregnancy with abortive outcome | 363681007 | RCGP_ONLY | DMWB |  |
| L040. | Spontaneous abortion unspecified | 267294003 | RCGP_ONLY | SEMANTIC |  |
| L042. | Spontaneous abortion complete | 156071003 | RCGP_ONLY | SEMANTIC |  |
| L042x | Complete spontaneous abortion with complication NOS | 669831000000102 | RCGP_ONLY | SEMANTIC |  |
| L042z | Complete spontaneous abortion NOS | 672481000000104 | RCGP_ONLY | SEMANTIC |  |
| L0432 | Unspecified inevitable abortion complicated by embolism | 18119004 | RCGP_ONLY | SEMANTIC |  |
| L043z | Unspecified inevitable abortion without complication | 51830007 | RCGP_ONLY | SEMANTIC |  |
| L05.. | Legally induced abortion | 39406005 | RCGP+ALBASOFT | DMWB |  |
| L050. | Legal abortion unspecified | 198691008 | RCGP+ALBASOFT | SEMANTIC |  |
| L0500 | Unspecified legal abortion + genital tract/pelvic infection | 672511000000105 | RCGP+ALBASOFT | SEMANTIC |  |
| L0501 | Unspecified legal abortion + delayed/excessive haemorrhage | 58071009 | RCGP+ALBASOFT | DMWB |  |
| L0502 | Unspecified legal abortion + damage to pelvic organs/tissues | 626771000000105 | RCGP+ALBASOFT | SEMANTIC |  |
| L0503 | Unspecified legal abortion with renal failure | 198695004 | RCGP+ALBASOFT | SEMANTIC |  |
| L0504 | Unspecified legal abortion with metabolic disorder | 198696003 | RCGP+ALBASOFT | SEMANTIC |  |
| L0505 | Unspecified legal abortion with shock | 198697007 | RCGP+ALBASOFT | SEMANTIC |  |
| L0506 | Unspecified legal abortion with embolism | 198698002 | RCGP+ALBASOFT | SEMANTIC |  |
| L050w | Unspecified legal abortion with other specified complication | 19123002 | RCGP+ALBASOFT | SEMANTIC |  |
| L050x | Unspecified legal abortion with complication NOS | 198701005 | RCGP+ALBASOFT | SEMANTIC |  |
| L050y | Unspecified legal abortion with no mention of complication | 34500003 | RCGP+ALBASOFT | DMWB |  |
| L050z | Unspecified legal abortion NOS | 613991000000109 | RCGP+ALBASOFT | SEMANTIC |  |
| L0510 | Incomplete legal abortion + genital tract/pelvic infection | 198782001 | RCGP+ALBASOFT | SEMANTIC |  |
| L0512 | Incomplete legal abortion + damage to pelvic organs/tissues | 579571000000102 | RCGP+ALBASOFT | SEMANTIC |  |
| L0517 | Incomplete medical abortion | 749781000000109 | RCGP+ALBASOFT | DMWB |  |
| L051w | Incomplete legal abortion with other specified complication | 614001000000104 | RCGP+ALBASOFT | SEMANTIC |  |
| L051x | Incomplete legal abortion with complication NOS | 599091000000102 | RCGP+ALBASOFT | SEMANTIC |  |
| L051y | Incomplete legal abortion with no mention of complication | 198715007 | RCGP+ALBASOFT | SEMANTIC |  |
| L051z | Incomplete legal abortion NOS | 198716008 | RCGP+ALBASOFT | SEMANTIC |  |
| L052. | Legal abortion complete | 267194005 | RCGP+ALBASOFT | DMWB |  |
| L0520 | Complete legal abortion + genital tract or pelvic infection | 198794005 | RCGP+ALBASOFT | SEMANTIC |  |
| L0521 | Complete legal abortion with delayed/excessive haemorrhage | 198693006 | RCGP+ALBASOFT | SEMANTIC |  |
| L0522 | Complete legal abortion + damage to pelvic organs or tissues | 698441000000100 | RCGP+ALBASOFT | SEMANTIC |  |
| L052w | Complete legal abortion with other specified complication | 599111000000107 | RCGP+ALBASOFT | SEMANTIC |  |
| L052x | Complete legal abortion with complication NOS | 592131000000109 | RCGP+ALBASOFT | SEMANTIC |  |
| L052y | Complete legal abortion with no mention of complication | 198727005 | RCGP+ALBASOFT | SEMANTIC |  |
| L052z | Complete legal abortion NOS | 198728000 | RCGP+ALBASOFT | SEMANTIC |  |
| L05z. | Legally induced abortion NOS | 599131000000104 | RCGP+ALBASOFT | SEMANTIC |  |
| L06.. | Illegally induced abortion | 49632008 | RCGP+ALBASOFT | DMWB |  |
| L060. | Illegal abortion unspecified | 198731004 | RCGP+ALBASOFT | SEMANTIC |  |
| L0600 | Unspec illegal abortion + genital tract or pelvic infection | 599151000000106 | RCGP+ALBASOFT | SEMANTIC |  |
| L0603 | Unspecified illegal abortion with renal failure | 198735008 | RCGP+ALBASOFT | SEMANTIC |  |
| L0604 | Unspecified illegal abortion with metabolic disorder | 198736009 | RCGP+ALBASOFT | SEMANTIC |  |
| L0605 | Unspecified illegal abortion with shock | 198737000 | RCGP+ALBASOFT | SEMANTIC |  |
| L0606 | Unspecified illegal abortion with embolism | 198738005 | RCGP+ALBASOFT | SEMANTIC |  |
| L060w | Unspecified illegal abortion + other specified complication | 22442009 | RCGP+ALBASOFT | SEMANTIC |  |
| L060y | Unspecified illegal abortion with no mention of complication | 660151000000107 | RCGP+ALBASOFT | SEMANTIC |  |
| L060z | Unspecified illegal abortion NOS | 198742008 | RCGP+ALBASOFT | SEMANTIC |  |
| L0611 | Incomplete illegal abortion + delayed/excessive haemorrhage | 198783006 | RCGP+ALBASOFT | SEMANTIC |  |
| L061w | Incomplete illegal abortion + other specified complication | 599191000000103 | RCGP+ALBASOFT | SEMANTIC |  |
| L061x | Incomplete illegal abortion with complication NOS | 198752007 | RCGP+ALBASOFT | SEMANTIC |  |
| L061y | Incomplete illegal abortion with no mention of complication | 198753002 | RCGP+ALBASOFT | SEMANTIC |  |
| L061z | Incomplete illegal abortion NOS | 198754008 | RCGP+ALBASOFT | SEMANTIC |  |
| L062. | Illegal abortion complete | 198755009 | RCGP+ALBASOFT | DMWB |  |
| L062w | Complete illegal abortion with other specified complication | 198763005 | RCGP+ALBASOFT | SEMANTIC |  |
| L062x | Complete illegal abortion with complication NOS | 198764004 | RCGP+ALBASOFT | SEMANTIC |  |
| L062y | Complete illegal abortion with no mention of complication | 529611000000105 | RCGP+ALBASOFT | SEMANTIC |  |
| L062z | Complete illegal abortion NOS | 198766002 | RCGP+ALBASOFT | SEMANTIC |  |
| L06z. | Illegally induced abortion NOS | 198767006 | RCGP+ALBASOFT | SEMANTIC |  |
| L07.. | Unspecified abortion | 70317007 | RCGP_ONLY | DMWB |  |
| L070. | Unspecified abortion | 198768001 | RCGP_ONLY | SEMANTIC |  |
| L0700 | Unspecified abortion with genital tract or pelvic infection | 198770005 | RCGP_ONLY | SEMANTIC |  |
| L0701 | Unspecified abortion with delayed or excessive haemorrhage | 198771009 | RCGP_ONLY | SEMANTIC |  |
| L0702 | Unspecified abortion with damage to pelvic organs or tissues | 659001000000109 | RCGP_ONLY | SEMANTIC |  |
| L0703 | Unspecified abortion with renal failure | 587081000000108 | RCGP_ONLY | SEMANTIC |  |
| L0704 | Unspecified abortion with metabolic disorder | 587071000000106 | RCGP_ONLY | SEMANTIC |  |
| L0705 | Unspecified abortion with shock | 198775000 | RCGP_ONLY | SEMANTIC |  |
| L0706 | Unspecified abortion with embolism | 639891000000108 | RCGP_ONLY | SEMANTIC |  |
| L070w | Unspecified abortion with other specified complication | 2787008 | RCGP_ONLY | SEMANTIC |  |
| L070x | Unspecified abortion with complication NOS | 198778003 | RCGP_ONLY | SEMANTIC |  |
| L070y | Unspecified abortion with no mention of complication | 198779006 | RCGP_ONLY | SEMANTIC |  |
| L070z | Unspecified abortion NOS | 639931000000103 | RCGP_ONLY | SEMANTIC |  |
| L071. | Unspecified abortion incomplete | 639941000000107 | RCGP_ONLY | SEMANTIC |  |
| L0713 | Unspecified incomplete abortion with renal failure | 632901000000101 | RCGP_ONLY | SEMANTIC |  |
| L0714 | Unspecified incomplete abortion with metabolic disorder | 602701000000107 | RCGP_ONLY | SEMANTIC |  |
| L0715 | Unspecified incomplete abortion with shock | 198787007 | RCGP_ONLY | SEMANTIC |  |
| L0716 | Unspecified incomplete abortion with embolism | 602721000000103 | RCGP_ONLY | SEMANTIC |  |
| L071x | Unspecified incomplete abortion with complication NOS | 198790001 | RCGP_ONLY | SEMANTIC |  |
| L071y | Unspecified incomplete abortion + no mention of complication | 198791002 | RCGP_ONLY | SEMANTIC |  |
| L071z | Unspecified incomplete abortion NOS | 198792009 | RCGP_ONLY | SEMANTIC |  |
| L072. | Unspecified abortion complete | 644601000000100 | RCGP_ONLY | SEMANTIC |  |
| L0721 | Unspecified complete abortion +delayed/excessive haemorrhage | 198795006 | RCGP_ONLY | SEMANTIC |  |
| L0723 | Unspecified complete abortion with renal failure | 198797003 | RCGP_ONLY | SEMANTIC |  |
| L0724 | Unspecified complete abortion with metabolic disorder | 198798008 | RCGP_ONLY | SEMANTIC |  |
| L0725 | Unspecified complete abortion with shock | 626811000000105 | RCGP_ONLY | SEMANTIC |  |
| L0726 | Unspecified complete abortion with embolism | 198800001 | RCGP_ONLY | SEMANTIC |  |
| L072w | Unspecified complete abortion + other specified complication | 698451000000102 | RCGP_ONLY | SEMANTIC |  |
| L072x | Unspecified complete abortion with complication NOS | 198802009 | RCGP_ONLY | SEMANTIC |  |
| L072y | Unspecified complete abortion + no mention of complication | 700141000000102 | RCGP_ONLY | SEMANTIC |  |
| L072z | Unspecified complete abortion NOS | 592141000000100 | RCGP_ONLY | SEMANTIC |  |
| L08.. | Failed attempted abortion | 49416000 | RCGP_ONLY | DMWB |  |
| L080. | Failed attempted abortion + genital tract/pelvic infection | 390431000000101 | RCGP_ONLY | SEMANTIC |  |
| L081. | Failed attempted abortion + delayed or excessive haemorrhage | 409481000000104 | RCGP_ONLY | SEMANTIC |  |
| L086. | Failed attempted abortion with embolism | 42755004 | RCGP_ONLY | SEMANTIC |  |
| L08w. | Failed attempted abortion with other specified complication | 56083002 | RCGP_ONLY | SEMANTIC |  |
| L08y. | Failed attempted abortion with no mention of complication | 198816004 | RCGP_ONLY | SEMANTIC |  |
| L08z. | Failed attempted abortion NOS | 198817008 | RCGP_ONLY | SEMANTIC |  |
| L09.. | Complications following abortion/ectopic/molar pregnancies | 198818003 | RCGP_ONLY | DMWB |  |
| L0903 | Salpingitis following abortive pregnancy | 198823003 | RCGP_ONLY | SEMANTIC |  |
| L0904 | Salpingo-oophoritis following abortive pregnancy | 198824009 | RCGP_ONLY | DMWB |  |
| L090y | Sepsis NOS following abortion/ectopic/molar pregnancy | 198825005 | RCGP_ONLY | SEMANTIC |  |
| L0924 | Periurethral tissue damage following abortive pregnancy | 198837007 | RCGP_ONLY | SEMANTIC |  |
| L0930 | Oliguria following abortive pregnancy | 609472002 | RCGP_ONLY | DMWB |  |
| L094. | Metabolic disorder following abortive pregnancy | 198848000 | RCGP_ONLY | SEMANTIC |  |
| L0963 | Fat embolism following abortive pregnancy | 198854004 | RCGP_ONLY | SEMANTIC |  |
| L097. | Readmission for abortive pregnancy (NHS codes) | 198860004 | RCGP_ONLY | SEMANTIC |  |
| L0971 | Readmission for retained produc of concept, legal abortion | 198862007 | RCGP_ONLY | DMWB |  |
| L0972 | Readmission for retained produc of concept, illegal abortion | 198863002 | RCGP_ONLY | DMWB |  |
| L09z. | Complication NOS following abortion/ectopic/molar pregnancy | 198872005 | RCGP_ONLY | SEMANTIC |  |
| L0A.. | Failed attempted abortion | 198873000 | RCGP_ONLY | SEMANTIC |  |
| L0A4. | Failed medical abortion, without complication | 198878009 | RCGP_ONLY | DMWB |  |
| Lyu02 | [X]Other abortion | 200483009 | RCGP_ONLY | SEMANTIC |  |
| Lyu06 | [X]Other+unspcf failed induced abortion,complicated/embolism | 200488000 | RCGP_ONLY | SEMANTIC |  |
| Lyu08 | [X]Other+unspcf failed induced abortion,without complication | 609492009 | RCGP_ONLY | DMWB |  |
| Q486. | Fetal death due to termination of pregnancy | 67313008 | RCGP_ONLY | DMWB |  |
| ZV232 | [V]Pregnancy with history of abortion | 315910004 | RCGP_ONLY | SEMANTIC |  |
| ZV25B | [V]Admission for administration of abortifacient | 439741000000107 | RCGP_ONLY | DMWB |  |

