# RCGP Sensitive Code list vs Albasoft Sensitive Code Reconciliation Report

## 1. Background

Two independent code lists could govern Read V2 sensitive code suppression from Scottish GP systems :

| List | Source | Scope | Key Table |
|---|---|---|---|
| **RCGP Data Sharing Exclusions** | Royal College of GPs via NHS Digital SNOMED CT refsets, mapped to Read V2 through DMWB crossmap + semantic matching | National (England-origin, applicable UK-wide) | `RCGPSNOMEDtoREADv2` |
| **Albasoft Sensitive Code List** | Albasoft Ltd, curated for Scottish GP system suppliers | Scotland-specific | `AlbasoftSensitiveCodeList` |

Both lists exist in the `[READv2]` database and both resolve terms from the same Read V2 dictionary. They serve the same purpose — preventing sensitive clinical data from being shared — but were compiled independently using different methodologies.

---

## 2. Current State

### Table Profiles

| Property | RCGPSNOMEDtoREADv2 | AlbasoftSensitiveCodeList |
|---|---|---|
| Total rows | 822 | 487 |
| Unique Read V2 codes | 822 (deduplicated) | 487 |
| Derivation | SNOMED CT refsets → DMWB crossmap + semantic matching | Directly curated Read V2 codes |
| SNOMED linkage | Yes (ConceptID, FSN, Preferred Term) | No |
| Provenance tracking | Yes (MappingSource, MatchLevel, MatchScore) | No |
| Categories | 4 exclusion categories (STD, ToP, Gender, Assisted Fertilisation) | Not categorised |
| Term source | Readv2Lookup / DMWB | Readv2Lookup |

### Overlap Analysis

The `AnalyseRCGPvsAlbasoft.sql` script produces a Venn-style breakdown:

### Venn Summary

| InBoth | OnlyInRCGP | OnlyInAlbasoft |
|---:|---:|---:|
| 327 | 495 | 160 |

Of 822 RCGP codes, 327 (40%) overlap with Albasoft. Of 487 Albasoft codes, 327 (67%) overlap with RCGP. There are 160 Albasoft codes with no RCGP equivalent.

### Breakdown by Exclusion Category

| Exclusion Category | RCGP Total | Also In Albasoft | Only In RCGP |
|---|---:|---:|---:|
| Assisted Fertilisation | 47 | 21 | 26 |
| Gender Related Issues | 30 | 0 | 30 |
| Sexually Transmitted Disease | 579 | 235 | 344 |
| Termination of Pregnancy | 166 | 71 | 95 |
| **RCGP Total** | **822** | **327** | **495** |
| *Albasoft-only (uncategorised)* | — | — | — |
| **Combined Total: 982 unique codes** | 822 RCGP | 327 overlap | 160 Albasoft-only |

### Key Findings

- **Gender Related Issues**: Zero overlap — none of the 30 RCGP gender codes appear in the Albasoft list. This is the most significant coverage gap.
- **Sexually Transmitted Disease**: Largest category with 344 codes only in RCGP — substantial potential gap in Albasoft suppression.
- **Termination of Pregnancy**: 95 codes (57%) only in RCGP — moderate gap.
- **Assisted Fertilisation**: 26 codes (55%) only in RCGP — moderate gap.
- **160 Albasoft-only codes** have no RCGP equivalent — these may represent Scotland-specific coding practices or indicate gaps in the RCGP SNOMED refsets.

| Segment | Description |
|---|---|
| **In Both** | Codes present in both RCGP and Albasoft — consensus codes already protected by both lists |
| **Only in RCGP** | Codes derived from SNOMED refsets but absent from Albasoft — potential gaps in Albasoft coverage |
| **Only in Albasoft** | Codes curated by Albasoft but not mapped from any SNOMED exclusion refset — may represent Scotland-specific clinical coding practices or codes for which no SNOMED equivalent exists in the exclusion refsets |



## 3. Key Observations

### 3.1 Different Origins, Same Goal

The RCGP list is **top-down**: start from SNOMED CT clinical concepts, then find their Read V2 equivalents. The Albasoft list is **bottom-up**: directly curated Read V2 codes known to be sensitive from GP system usage. This means:

- RCGP captures concepts that *should* be sensitive based on clinical ontology
- Albasoft captures codes that *are* sensitive based on real-world GP coding practice

### 3.2 The Unmapped Gap

The RCGP SNOMED refsets contain 2,834 concepts, but only 820 could be mapped to Read V2 (29%). The remaining 2,014 concepts either:
- Have no Read V2 equivalent (SNOMED-only concepts)
- Exist at a different granularity than Read V2 supports
- Were removed during QA as false matches

Some of these unmapped SNOMED concepts may correspond to Albasoft codes that weren't caught by the mapping algorithm.

### 3.3 RCGP Codes Not in Albasoft

These represent the most important findings — potential **gaps in the Albasoft suppression list**. If a code is clinically sensitive enough to be in the RCGP national exclusion refset but isn't in the Albasoft list, it could be leaking sensitive data in Scottish systems.

Priority assessment depends on:
- **MappingSource**: DMWB-mapped codes (official crossmap) are higher confidence than SEMANTIC matches
- **MatchLevel**: EXACT and DMWB_CROSSMAP are reliable; TOKEN_OVERLAP at lower scores should be reviewed
- **Exclusion Category**: STD and Gender codes may carry higher patient sensitivity risk

### 3.4 Albasoft Codes Not in RCGP

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
| **High** | DMWB_CROSSMAP source, active concept, STD/Gender category | Strong candidate for Albasoft addition — official crossmap, high sensitivity |
| **Medium** | SEMANTIC EXACT match, active concept | Review the Read V2 term; if clearly sensitive, add to Albasoft |
| **Low** | SEMANTIC TOKEN_OVERLAP, MatchScore < 0.8 | Clinical review required before adding — lower mapping confidence |
| **Exclude** | Inactive concept (`ConceptIsActive = 0`) | Do not add — concept is retired in SNOMED |

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
| SNOMED concept exists and is in a refset | Our mapping missed it (mapping gap) | Fix the mapping — add to `RCGPSNOMEDtoREADv2` |
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
    CodeSource           VARCHAR(20)    NOT NULL,  -- BOTH, RCGP_ONLY, ALBASOFT_ONLY
    MappingSource        VARCHAR(20)    NULL,
    MatchLevel           VARCHAR(20)    NULL,
    MatchScore           DECIMAL(4,3)   NULL,
    ReviewStatus         VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    ReviewNotes          NVARCHAR(500)  NULL,
    PRIMARY KEY (ReadV2Code)
);
```

Section 8 of the analysis script already produces this union. Materialising it as a table adds:
- `ReviewStatus` (`PENDING`, `APPROVED`, `REJECTED`, `UNDER_REVIEW`) for tracking clinical review progress
- `ReviewNotes` for documenting review decisions


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


1. **Create the combined table** — Materialise the union from section 8 as `SensitiveCodeListCombined` with review tracking columns
2. **Schedule clinical review** — High and Medium priority RCGP-only codes need sign-off before being added to production suppression

---

## 7. Scripts Reference

| Script | Purpose |
|---|---|
| `Queries/AnalyseRCGPvsAlbasoft.sql` | Full analysis: overlap, differences, breakdowns, combined union |
| `Queries/RCGPExclusion.sql` | Creates and populates `RCGPSNOMEDtoREADv2` table |
| `Readv2/Import-AlbasoftToSqlServer.py` | Imports Albasoft list into `AlbasoftSensitiveCodeList` |
| `Readv2/MAPPING_STRATEGY.md` | Full mapping methodology and QA history |
