# DMWB SQL Server Database Schema

## Overview

This document describes the structure and purpose of all tables exported from the NHS Data Migration Workbench (DMWB) Access databases to SQL Server.

**Database Name:** `DMWB_Export`  
**Total Tables:** 46  
**Total Rows:** 69,105,879

> **Note:** The TRUD download contains 9 Access databases with 46 tables of terminology data. User workspace databases (EPR Data, User Data, User Cluster Enumerations) are not included in the TRUD distribution and must be created separately if needed.

### Important Notes

**Read Code Term Length Columns:** Read Code and CTV3 tables use `T30`, `T60`, and `T198` columns instead of a single `TERM` column. These represent:
- `T30`: 30-character abbreviated term
- `T60`: 60-character standard term
- `T198`: 198-character full description

**Unicode Encoding:** All text fields are properly encoded as Unicode (NVARCHAR) and are directly searchable. Base64 encoding is not used.

**Hierarchy Columns:** Hierarchy tables (SCTHIER, RCTHIER, CTV3HIER) use `CHILD`/`PARENT` column naming with additional `CTERM`/`PTERM` columns for readability, plus a `DNUM` (distance number) column.

---

## Table Organization

Tables are organized by source database and functional purpose:

1. **Data Migration Maps** (15 tables) - Code mapping tables
2. **Public Code Usage** (1 table) - Frequency/usage statistics
3. **READ Codes** (10 tables) - Read v2 and CTV3 terminology
4. **SNOMED History** (9 tables) - Historical SNOMED data
5. **SNOMED Lexicon** (3 tables) - Text search and tokenization
6. **SNOMED Query Table** (1 table) - Query optimization
7. **SNOMED Transitive Closure** (1 table) - Relationship closure
8. **SNOMED Core** (6 tables) - Current SNOMED CT data

> **Note:** User/Application Data tables (EPR Data, User Data, etc.) are not included in the TRUD distribution.

---

## 1. Data Migration Maps (15 tables)

### DMWB_NHS_Data_Migration_Maps_RCTSCTMAP
**Purpose:** Maps Read Codes (v2) to SNOMED CT concepts  
**Rows:** 102,057

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR(MAX) | Read Code (e.g., 'G802.') |
| `STUI` | NVARCHAR(2) | Read term ID (unused in most mappings) |
| `TCUI` | NVARCHAR(18) | Target SNOMED Concept ID |
| `TTUI` | NVARCHAR(18) | **Target SNOMED Description ID** (mapped term) |
| `MAPTYP` | NVARCHAR(1) | Map type ('1'=exact, '2'=broader, '3'=narrower) |
| `ASSURED` | BIT | Quality assured flag |

**Usage:**
```sql
-- Get mapped SNOMED description for Read code G802.
SELECT m.SCUI AS ReadCode, m.TCUI AS ConceptID, m.TTUI AS DescriptionID, s.TERM AS MappedTerm
FROM DMWB_NHS_Data_Migration_Maps_RCTSCTMAP m
INNER JOIN DMWB_NHS_SNOMED_SCT s ON m.TTUI = s.CUI
WHERE m.SCUI = 'G802.';
```

---

### DMWB_NHS_Data_Migration_Maps_RCTCTV3MAP
**Purpose:** Maps Read v2 codes to CTV3 (Read v3) codes  
**Rows:** 102,066

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR | Source Read v2 code |
| `STUI` | NVARCHAR | Source term ID |
| `TCUI` | NVARCHAR | Target CTV3 concept ID |
| `TTUI` | NVARCHAR | Target CTV3 term ID |
| `MAPTYP` | NVARCHAR | Map type code |

**Usage:** Migrate legacy Read v2 codes to CTV3.

---

### DMWB_NHS_Data_Migration_Maps_CTV3SCTMAP
**Purpose:** Maps CTV3 (Read v3) codes to SNOMED CT  
**Rows:** 445,473

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR | Source CTV3 code (5-character) |
| `STUI` | NVARCHAR | Source CTV3 term ID |
| `TCUI` | NVARCHAR | Target SNOMED Concept ID |
| `TTUI` | NVARCHAR | Target SNOMED Description ID |
| `MAPTYP` | NVARCHAR | Map type |
| `ASSURED` | BIT | Quality assured |

**Usage:** Primary map for CTV3 → SNOMED CT migration.

---

### DMWB_NHS_Data_Migration_Maps_CTV3RCTMAP
**Purpose:** Reverse map from CTV3 back to Read v2  
**Rows:** 445,473

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR | Source CTV3 code |
| `STUI` | NVARCHAR | Source term ID |
| `TCUI` | NVARCHAR | Target Read v2 code |
| `TTUI` | NVARCHAR | Target Read v2 term ID |
| `MAPTYP` | NVARCHAR | Map type |

---

### DMWB_NHS_Data_Migration_Maps_ICDSCTMAP
**Purpose:** Maps ICD-10 codes to SNOMED CT  
**Rows:** 37,729

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR | ICD-10 code (e.g., 'E10', 'E11.9') |
| `STUI` | NVARCHAR | ICD-10 term variant |
| `TCUI` | NVARCHAR | SNOMED Concept ID |
| `TTUI` | NVARCHAR | SNOMED Description ID |
| `MAPTYP` | NVARCHAR | Map type |

**Usage:** Convert diagnosis codes (ICD-10) to SNOMED CT.

---

### DMWB_NHS_Data_Migration_Maps_SCTICDMAP
**Purpose:** Reverse map from SNOMED CT to ICD-10  
**Rows:** 117,992

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR | SNOMED Concept ID |
| `STUI` | NVARCHAR | SNOMED Description ID |
| `TCUI` | NVARCHAR | ICD-10 code |
| `TTUI` | NVARCHAR | ICD-10 variant |
| `MAPTYP` | NVARCHAR | Map type |

---

### DMWB_NHS_Data_Migration_Maps_ICD
**Purpose:** ICD-10 term list  
**Rows:** 19,267

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | ICD-10 code |
| `TUI` | NVARCHAR | Term variant ID |
| `TERM` | NVARCHAR | ICD-10 description text |
| `TYP` | TINYINT | Term type |

---

### DMWB_NHS_Data_Migration_Maps_ICDHIER
**Purpose:** ICD-10 hierarchical relationships  
**Rows:** 19,267

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Child ICD-10 code |
| `PCUI` | NVARCHAR | Parent ICD-10 code |
| `LEV` | SMALLINT | Hierarchy level |

---

### DMWB_NHS_Data_Migration_Maps_ICDTC
**Purpose:** ICD-10 transitive closure (all ancestor relationships)  
**Rows:** 77,965

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Descendant ICD-10 code |
| `PCUI` | NVARCHAR | Ancestor ICD-10 code |
| `LEV` | SMALLINT | Distance in hierarchy |

---

### DMWB_NHS_Data_Migration_Maps_OPCSSCTMAP
**Purpose:** Maps OPCS-4 procedure codes to SNOMED CT  
**Rows:** 20,816

| Column | Type | Description |
|--------|------|-------------|
| `SCUI` | NVARCHAR | OPCS-4 code (e.g., 'W37.1') |
| `STUI` | NVARCHAR | OPCS term variant |
| `TCUI` | NVARCHAR | SNOMED Concept ID |
| `TTUI` | NVARCHAR | SNOMED Description ID |
| `MAPTYP` | NVARCHAR | Map type |

**Usage:** Convert procedure codes (OPCS-4) to SNOMED CT.

---

### DMWB_NHS_Data_Migration_Maps_SCTOPCSMAP
**Purpose:** Reverse map from SNOMED CT to OPCS-4  
**Rows:** 71,730

---

### DMWB_NHS_Data_Migration_Maps_OPCS
**Purpose:** OPCS-4 procedure term list  
**Rows:** 11,686

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | OPCS-4 code |
| `TUI` | NVARCHAR | Term variant ID |
| `TERM` | NVARCHAR | Procedure description |
| `TYP` | TINYINT | Term type |

---

### DMWB_NHS_Data_Migration_Maps_OPCSHIER
**Purpose:** OPCS-4 hierarchical relationships  
**Rows:** 11,686

---

### DMWB_NHS_Data_Migration_Maps_OPCSTC
**Purpose:** OPCS-4 transitive closure  
**Rows:** 44,789

---

### DMWB_NHS_Data_Migration_Maps_MAPVERSIONS
**Purpose:** Mapping file version metadata  
**Rows:** 10

| Column | Type | Description |
|--------|------|-------------|
| `MAPTYPE` | NVARCHAR | Map identifier (e.g., 'RCTSCT') |
| `VERSION` | NVARCHAR | Version string |
| `DATE` | DATETIME | Release date |

---

## 2. Public Code Usage (1 table)

### DMWB_NHS_Public_Code_Usage_SCTFREQ
**Purpose:** SNOMED concept usage frequency in NHS clinical systems  
**Rows:** 1,133,250

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | SNOMED Concept ID |
| `FREQ` | INT | Usage frequency count |
| `SOURCE` | NVARCHAR | Data source identifier |

**Usage:** Identify commonly-used vs. rarely-used SNOMED concepts for UI optimization.

---

## 3. READ Codes (10 tables)

### DMWB_NHS_READ_RCT
**Purpose:** Read Code v2 term list  
**Rows:** 175,017

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Read Code (e.g., 'G30..') |
| `TUI` | NVARCHAR | Term ID (00=preferred) |
| `T30` | NVARCHAR | 30-character term (abbreviated) |
| `T60` | NVARCHAR | 60-character term |
| `T198` | NVARCHAR | 198-character term (full description) |
| `FREQ` | TINYINT | Frequency category |
| `RDATE` | NVARCHAR | Release date |

**Usage:** Look up Read Code descriptions.

```sql
-- Find Read Code term
SELECT CUI, TUI, T30, T60, T198 FROM DMWB_NHS_READ_RCT WHERE CUI = 'G802.' AND TUI = '00';
```

---

### DMWB_NHS_READ_RCTHIER
**Purpose:** Read v2 hierarchical relationships (parent-child)  
**Rows:** 157,280

| Column | Type | Description |
|--------|------|-------------|
| `PARENT` | NVARCHAR | Parent Read Code |
| `CHILD` | NVARCHAR | Child Read Code |
| `PTERM` | NVARCHAR | Parent term (for readability) |
| `CTERM` | NVARCHAR | Child term (for readability) |
| `DNUM` | INT | Distance/depth number |

```sql
-- Find direct parents of a Read Code
SELECT PARENT, PTERM FROM DMWB_NHS_READ_RCTHIER WHERE CHILD = 'G30..';
```

---

### DMWB_NHS_READ_RCTTC
**Purpose:** Read v2 transitive closure (all ancestors)  
**Rows:** 664,554

| Column | Type | Description |
|--------|------|-------------|
| `SUBTYPEID` | NVARCHAR | Descendant Read Code |
| `SUPERTYPEID` | NVARCHAR | Ancestor Read Code |

**Usage:** Query all codes under a chapter/heading.

```sql
-- Find all descendants of G (Circulatory system)
SELECT SUBTYPEID FROM DMWB_NHS_READ_RCTTC WHERE SUPERTYPEID = 'G....';
```

```sql
-- Find all diabetes codes (descendants of 'C10')
SELECT DISTINCT tc.CUI, r.TERM
FROM DMWB_NHS_READ_RCTTC tc
INNER JOIN DMWB_NHS_READ_RCT r ON tc.CUI = r.CUI AND r.TUI = '00'
WHERE tc.PCUI = 'C10';
```

---

### DMWB_NHS_READ_RCTEQV
**Purpose:** Read v2 term equivalencies (synonyms/variants)  
**Rows:** 336,712

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Concept code |
| `TUI` | NVARCHAR | Term variant 1 |
| `TUI2` | NVARCHAR | Term variant 2 (equivalent) |

---

### DMWB_NHS_READ_CTV3
**Purpose:** CTV3 (Read v3) term list  
**Rows:** 395,650

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR(5) | CTV3 5-character code |
| `STAT` | TINYINT | Status (0=current, 1=retired) |
| `TUI` | NVARCHAR | Term ID |
| `TYP` | TINYINT | Term type |
| `T30` | NVARCHAR | 30-character term (abbreviated) |
| `T60` | NVARCHAR | 60-character term |
| `T198` | NVARCHAR | 198-character term (full description) |
| `FREQ` | TINYINT | Frequency category |
| `RDATE` | NVARCHAR | Release date |

**Note:** Like RCT, CTV3 uses T30/T60/T198 columns for different term lengths instead of a single TERM column.

```sql
-- Find CTV3 code with terms
SELECT CUI, TUI, T30, T60, T198 FROM DMWB_NHS_READ_CTV3 WHERE CUI = 'X30Mx';
```

---

### DMWB_NHS_READ_CTV3HIER
**Purpose:** CTV3 hierarchical relationships  
**Rows:** 287,969

| Column | Type | Description |
|--------|------|-------------|
| `CHILD` | NVARCHAR | Child CTV3 code |
| `PARENT` | NVARCHAR | Parent CTV3 code |
| `ORD` | NVARCHAR | Ordering information |
| `PTERM` | NVARCHAR | Parent term (for readability) |
| `CTERM` | NVARCHAR | Child term (for readability) |
| `DNUM` | INT | Distance/depth number |

```sql
-- Find direct parents of a CTV3 code
SELECT PARENT, PTERM FROM DMWB_NHS_READ_CTV3HIER WHERE CHILD = 'X30Mx';
```

---

### DMWB_NHS_READ_CTV3TC
**Purpose:** CTV3 transitive closure (all ancestor relationships)  
**Rows:** 2,241,382

| Column | Type | Description |
|--------|------|-------------|
| `SupertypeID` | NVARCHAR | Ancestor CTV3 code |
| `SubtypeID` | NVARCHAR | Descendant CTV3 code |

```sql
-- Find all descendants of a CTV3 code
SELECT SubtypeID FROM DMWB_NHS_READ_CTV3TC WHERE SupertypeID = 'X....';
```

---

### DMWB_NHS_READ_CTV3EQV
**Purpose:** CTV3 term equivalencies  
**Rows:** 803,372

---

### DMWB_NHS_READ_ctv3_term
**Purpose:** Additional CTV3 term variants  
**Rows:** 351,470

| Column | Type | Description |
|--------|------|-------------|
| `TERMID` | NVARCHAR | Term identifier |
| `TERM` | NVARCHAR | Term text |
| `STATUS` | NVARCHAR | Current/retired status |

---

### DMWB_NHS_READ_ctv3_rmf
**Purpose:** CTV3 read-only metadata framework  
**Rows:** 55,272

---

## 4. SNOMED History (9 tables)

### DMWB_NHS_SNOMED_History_SCTMETA
**Purpose:** Historical SNOMED concept metadata (retired/replaced concepts)  
**Rows:** 1,141,797

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | SNOMED Concept/Description ID |
| `EFFDATE` | NVARCHAR | Effective date (YYYYMMDD) |
| `ACTIVE` | BIT | Active (0=retired, 1=current) |
| `MODULEID` | NVARCHAR | Module/namespace |
| `REFSETID` | NVARCHAR | Reference set ID |

**Usage:** Track when concepts were retired or replaced.

---

### DMWB_NHS_SNOMED_History_SCTHIST
**Purpose:** SNOMED concept change history  
**Rows:** 352,610

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Concept ID |
| `EFFDATE` | NVARCHAR | Effective date |
| `STATUS` | NVARCHAR | Status change |
| `REASON` | NVARCHAR | Reason for change |

---

### DMWB_NHS_SNOMED_History_SCTHREL
**Purpose:** Historical relationship changes  
**Rows:** 348,238

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Source concept |
| `RCUI` | NVARCHAR | Destination concept |
| `RTYP` | NVARCHAR | Relationship type |
| `EFFDATE` | NVARCHAR | Effective date |
| `ACTIVE` | BIT | Currently active |

---

### DMWB_NHS_SNOMED_History_SCTEQV
**Purpose:** Historical equivalencies (concept merges/splits)  
**Rows:** 112,217

---

### DMWB_NHS_SNOMED_History_SCTCHIST
**Purpose:** Component history (empty - reserved for future use)  
**Rows:** 0

---

### DMWB_NHS_SNOMED_History_SCTSUBST
**Purpose:** Substitution rules (empty - reserved)  
**Rows:** 0

---

### DMWB_NHS_SNOMED_History_SUBSETLIST
**Purpose:** Reference set/subset catalog  
**Rows:** 1,507

| Column | Type | Description |
|--------|------|-------------|
| `SUBSETID` | NVARCHAR | Subset identifier |
| `NAME` | NVARCHAR | Subset name |
| `DESCRIPTION` | NVARCHAR | Purpose/description |

---

### DMWB_NHS_SNOMED_History_SUBSETS
**Purpose:** Subset membership (which concepts are in which subsets)  
**Rows:** 461,419

| Column | Type | Description |
|--------|------|-------------|
| `SUBSETID` | NVARCHAR | Subset identifier |
| `CUI` | NVARCHAR | SNOMED Concept ID |
| `ACTIVE` | BIT | Active in subset |

---

### DMWB_NHS_SNOMED_History_SUBSETS_RD
**Purpose:** Read Code subset memberships  
**Rows:** 2,652,514

| Column | Type | Description |
|--------|------|-------------|
| `SUBSETID` | NVARCHAR | Subset identifier |
| `READCODE` | NVARCHAR | Read Code |

**Usage:** Find Read Codes in specific clinical subsets (e.g., diabetes, asthma).

---

## 5. SNOMED Lexicon (3 tables)

### DMWB_NHS_SNOMED_Lexicon_TOKENINDEX
**Purpose:** Inverted text index for fast term searching  
**Rows:** 12,951,424

| Column | Type | Description |
|--------|------|-------------|
| `TOKENID` | INT | Token (word) identifier |
| `CUI` | NVARCHAR | SNOMED Description ID containing this word |
| `POSITION` | SMALLINT | Word position in term |

**Usage:** Enables fast full-text searching without SQL Server Full-Text Search.

```sql
-- Find all descriptions containing word 'diabetes'
SELECT DISTINCT s.CUI, s.TERM
FROM DMWB_NHS_SNOMED_Lexicon_TOKENS t
INNER JOIN DMWB_NHS_SNOMED_Lexicon_TOKENINDEX ti ON t.TOKENID = ti.TOKENID
INNER JOIN DMWB_NHS_SNOMED_SCT s ON ti.CUI = s.CUI
WHERE t.TOKEN = 'diabetes';
```

---

### DMWB_NHS_SNOMED_Lexicon_TOKENS
**Purpose:** Word vocabulary (all unique words in SNOMED terms)  
**Rows:** 127,220

| Column | Type | Description |
|--------|------|-------------|
| `TOKENID` | INT | Unique word identifier |
| `TOKEN` | NVARCHAR | Normalized word (lowercase) |
| `FREQ` | INT | Frequency count |

---

### DMWB_NHS_SNOMED_Lexicon_WEQ
**Purpose:** Word equivalencies (synonyms, spelling variants)  
**Rows:** 25,349

| Column | Type | Description |
|--------|------|-------------|
| `WORD1` | NVARCHAR | Word variant 1 |
| `WORD2` | NVARCHAR | Word variant 2 (equivalent) |

**Usage:** Fuzzy search (e.g., 'color' ≈ 'colour').

---

## 6. SNOMED Query Table (1 table)

### DMWB_NHS_SNOMED_Query_Table_SCTQT
**Purpose:** Denormalized query optimization table (pre-joined concept + description data)  
**Rows:** 22,918,684

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | SNOMED Concept ID |
| `TUI` | NVARCHAR | Description ID |
| `TERM` | NVARCHAR | Term text |
| `TYP` | TINYINT | Term type |
| `STAT` | TINYINT | Status |
| `PRIMITIVE` | BIT | Primitive concept |
| `PCUI` | NVARCHAR | Parent concept (immediate) |
| `LEV` | SMALLINT | Hierarchy level |

**Usage:** Fast single-table queries avoiding expensive joins.

```sql
-- Find all descendants of 'Diabetes mellitus' (73211009)
SELECT DISTINCT CUI, TERM
FROM DMWB_NHS_SNOMED_Query_Table_SCTQT
WHERE PCUI = '73211009';
```

---

## 7. SNOMED Transitive Closure (1 table)

### DMWB_NHS_SNOMED_Transitive_Closure_SCTTC
**Purpose:** Pre-computed IS-A relationship closure (all ancestor paths)  
**Rows:** 11,637,305

| Column | Type | Description |
|--------|------|-------------|
| `SupertypeID` | NVARCHAR | Ancestor Concept ID |
| `SubtypeID` | NVARCHAR | Descendant Concept ID |

**Usage:** Query subsumption (e.g., "find all types of diabetes").

```sql
-- Find all diabetes types (descendants of 73211009)
SELECT DISTINCT tc.SubtypeID, s.TERM
FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
INNER JOIN DMWB_NHS_SNOMED_SCT s ON tc.SubtypeID = s.CUI AND s.TYP = 1
WHERE tc.SupertypeID = '73211009';
```

---

## 8. SNOMED Core (6 tables)

### DMWB_NHS_SNOMED_SCT
**Purpose:** SNOMED CT descriptions (terms/synonyms for concepts)  
**Rows:** 3,337,614

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | **Description ID** (NOT Concept ID!) |
| `MODULEID` | NVARCHAR | Module/extension ID |
| `PRIMITIVE` | BIT | Concept is primitive (not fully defined) |
| `STAT` | TINYINT | Status (0=current, 1=retired) |
| `TUI` | NVARCHAR | Concept ID (confusing name!) |
| `TUISTAT` | TINYINT | Concept status |
| `TYP` | TINYINT | Description type (1=FSN, 2=Synonym, 3=Preferred) |
| `TERM` | NVARCHAR | **The actual term text** |
| `F0-F5` | BIT | Feature flags |
| `FREQ` | TINYINT | Frequency category |
| `RDATE` | NVARCHAR | Effective date |

**⚠️ IMPORTANT:** 
- `CUI` = Description ID (not Concept ID!)
- `TUI` = Concept ID (confusing but true)
- Use `TYP = 1` for Fully Specified Names (FSN)
- Use `TYP = 3` for Preferred Terms (PT)

**Usage:**
```sql
-- Get preferred term for concept 73211009
SELECT TERM FROM DMWB_NHS_SNOMED_SCT 
WHERE TUI = '73211009' AND TYP = 3 AND STAT = 0;
```

---

### DMWB_NHS_SNOMED_SCTHIER
**Purpose:** SNOMED hierarchical relationships (IS-A only, one level)  
**Rows:** 1,476,926

| Column | Type | Description |
|--------|------|-------------|
| `CHILD` | NVARCHAR | Child Concept ID |
| `PARENT` | NVARCHAR | Parent Concept ID |
| `CTERM` | NVARCHAR | Child term (for readability) |
| `PTERM` | NVARCHAR | Parent term (for readability) |
| `DNUM` | INT | Distance/depth number |

**Usage:** Navigate SNOMED hierarchy (use SCTTC for transitive queries).

```sql
-- Find direct parents of a concept
SELECT PARENT, PTERM FROM DMWB_NHS_SNOMED_SCTHIER WHERE CHILD = '266267005';
```

---

### DMWB_NHS_SNOMED_SCTREL
**Purpose:** All SNOMED relationships (including non-IS-A types)  
**Rows:** 3,430,701

| Column | Type | Description |
|--------|------|-------------|
| `CUI` | NVARCHAR | Source Concept ID |
| `RCUI` | NVARCHAR | Destination Concept ID |
| `RTYP` | NVARCHAR | Relationship Type Concept ID |
| `RGRP` | SMALLINT | Relationship group |
| `MODULEID` | NVARCHAR | Module ID |
| `STAT` | TINYINT | Status |

**Usage:** Find 'Finding site', 'Causative agent', 'Associated morphology', etc.

```sql
-- Find 'Finding site' for 'Myocardial infarction' (22298006)
SELECT DISTINCT r.RCUI, s.TERM
FROM DMWB_NHS_SNOMED_SCTREL r
INNER JOIN DMWB_NHS_SNOMED_SCT s ON r.RCUI = s.TUI AND s.TYP = 3
WHERE r.CUI = '22298006' AND r.RTYP = '363698007'; -- Finding site
```

---

### DMWB_NHS_SNOMED_SCTMODREL
**Purpose:** Module-level relationship metadata  
**Rows:** 137

| Column | Type | Description |
|--------|------|-------------|
| `MODULEID` | NVARCHAR | Module identifier |
| `RTYP` | NVARCHAR | Relationship type |
| `ACTIVE` | BIT | Active flag |

---

### DMWB_NHS_SNOMED_SCTMRCM
**Purpose:** Machine-Readable Concept Model (MRCM) constraints  
**Rows:** 277

| Column | Type | Description |
|--------|------|-------------|
| `DOMAIN` | NVARCHAR | Domain concept |
| `CONSTRAINT` | NVARCHAR | MRCM constraint definition |

**Usage:** Validate SNOMED concept modeling rules.

---

### DMWB_NHS_SNOMED_VERSIONS
**Purpose:** SNOMED CT release version metadata  
**Rows:** 6

| Column | Type | Description |
|--------|------|-------------|
| `RELEASE` | NVARCHAR | Release identifier (e.g., 'UK Edition') |
| `VERSION` | NVARCHAR | Version string |
| `DATE` | DATETIME | Release date |

---

## 9. User/Application Data (Not in TRUD)

The following databases are **not included** in the TRUD download. They are empty workspace databases created by the DMWB application for user-specific data:

- **EPR Data.mdb** - Electronic Patient Record data (user clinical data)
- **User Data.mdb** - User allowlists, source systems, version tracking  
- **User Cluster Enumerations.mdb** - Custom groupings and scratchpad data
- **NHS Data Migration Workbench GUI.mdb** - Application interface (no data tables)

These are created locally when using the DMWB GUI application and are not distributed via TRUD.

---

## Common Query Patterns

### 1. Read Code → SNOMED CT with Description

```sql
SELECT 
    m.SCUI AS ReadCode,
    rct.TERM AS ReadTerm,
    m.TCUI AS SnomedConceptID,
    m.TTUI AS SnomedDescriptionID,
    sct.TERM AS SnomedTerm,
    CASE m.MAPTYP 
        WHEN '1' THEN 'Exact'
        WHEN '2' THEN 'Broader'
        WHEN '3' THEN 'Narrower'
    END AS MapType
FROM DMWB_NHS_Data_Migration_Maps_RCTSCTMAP m
LEFT JOIN DMWB_NHS_READ_RCT rct ON m.SCUI = rct.CUI AND rct.TUI = '00'
LEFT JOIN DMWB_NHS_SNOMED_SCT sct ON m.TTUI = sct.CUI
WHERE m.SCUI = 'G802.';
```

### 2. Find All Diabetes Concepts (Subsumption Query)

```sql
-- Using transitive closure (fast)
SELECT DISTINCT tc.CUI AS ConceptID, s.TERM AS PreferredTerm
FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
INNER JOIN DMWB_NHS_SNOMED_SCT s ON tc.CUI = s.TUI AND s.TYP = 3
WHERE tc.PCUI = '73211009' -- Diabetes mellitus
AND s.STAT = 0; -- Current only
```

### 3. Text Search Across All Terms

```sql
SELECT TOP 20
    TUI AS ConceptID,
    TERM,
    CASE TYP 
        WHEN 1 THEN 'FSN'
        WHEN 2 THEN 'Synonym'
        WHEN 3 THEN 'Preferred'
    END AS TermType
FROM DMWB_NHS_SNOMED_SCT
WHERE TERM LIKE '%myocardial infarction%'
AND STAT = 0
ORDER BY TYP, TERM;
```

### 4. Get Concept Hierarchy Path

```sql
-- Recursive CTE to build path
WITH ConceptPath AS (
    SELECT CUI, PCUI, CAST(CUI AS NVARCHAR(MAX)) AS Path, 0 AS Level
    FROM DMWB_NHS_SNOMED_SCTHIER
    WHERE CUI = '22298006' -- Myocardial infarction
    
    UNION ALL
    
    SELECT h.CUI, h.PCUI, CAST(cp.Path + ' → ' + h.PCUI AS NVARCHAR(MAX)), cp.Level + 1
    FROM DMWB_NHS_SNOMED_SCTHIER h
    INNER JOIN ConceptPath cp ON h.CUI = cp.PCUI
    WHERE cp.Level < 10
)
SELECT TOP 1 Path AS HierarchyPath, Level
FROM ConceptPath
ORDER BY Level DESC;
```

### 5. Find ICD-10 Code for SNOMED Concept

```sql
SELECT 
    m.SCUI AS SnomedConceptID,
    sct.TERM AS SnomedTerm,
    m.TCUI AS ICD10Code,
    icd.TERM AS ICD10Description
FROM DMWB_NHS_Data_Migration_Maps_SCTICDMAP m
INNER JOIN DMWB_NHS_SNOMED_SCT sct ON m.SCUI = sct.TUI AND sct.TYP = 3
INNER JOIN DMWB_NHS_Data_Migration_Maps_ICD icd ON m.TCUI = icd.CUI
WHERE m.SCUI = '73211009'; -- Diabetes mellitus
```

---

## Index Recommendations

For optimal query performance, create these indexes:

```sql
-- Mapping tables
CREATE INDEX IX_RCTSCTMAP_SCUI ON DMWB_NHS_Data_Migration_Maps_RCTSCTMAP(SCUI);
CREATE INDEX IX_RCTSCTMAP_TCUI ON DMWB_NHS_Data_Migration_Maps_RCTSCTMAP(TCUI);
CREATE INDEX IX_RCTSCTMAP_TTUI ON DMWB_NHS_Data_Migration_Maps_RCTSCTMAP(TTUI);

-- SNOMED descriptions
CREATE INDEX IX_SCT_TUI ON DMWB_NHS_SNOMED_SCT(TUI); -- Concept ID lookup
CREATE INDEX IX_SCT_CUI ON DMWB_NHS_SNOMED_SCT(CUI); -- Description ID lookup
CREATE INDEX IX_SCT_TERM ON DMWB_NHS_SNOMED_SCT(TERM); -- Text search

-- Transitive closure
CREATE INDEX IX_SCTTC_PCUI ON DMWB_NHS_SNOMED_Transitive_Closure_SCTTC(PCUI);
CREATE INDEX IX_SCTTC_CUI ON DMWB_NHS_SNOMED_Transitive_Closure_SCTTC(CUI);

-- Relationships
CREATE INDEX IX_SCTREL_CUI ON DMWB_NHS_SNOMED_SCTREL(CUI);
CREATE INDEX IX_SCTREL_RCUI ON DMWB_NHS_SNOMED_SCTREL(RCUI);
CREATE INDEX IX_SCTREL_RTYP ON DMWB_NHS_SNOMED_SCTREL(RTYP);

-- Read Codes
CREATE INDEX IX_RCT_CUI ON DMWB_NHS_READ_RCT(CUI);
CREATE INDEX IX_RCTTC_PCUI ON DMWB_NHS_READ_RCTTC(PCUI);
```

---

## Important Notes

### Column Naming Confusion
The DMWB database uses non-standard column naming:
- **SCT table:** `CUI` = Description ID, `TUI` = Concept ID (reversed!)
- **Other tables:** `CUI` = Concept ID (standard)
- Always check context when using CUI/TUI

### Status Codes
- `STAT = 0` → Current/Active
- `STAT = 1` → Retired/Inactive

### Term Types (TYP column)
- `TYP = 1` → Fully Specified Name (FSN)
- `TYP = 2` → Synonym
- `TYP = 3` → Preferred Term (PT)

### Map Types (MAPTYP column)
- `'1'` → Exact match
- `'2'` → Broader mapping (source is more specific)
- `'3'` → Narrower mapping (source is more general)

---

## Table Size Summary

| Category | Tables | Total Rows |
|----------|--------|------------|
| Data Migration Maps | 15 | 1,528,006 |
| Public Code Usage | 1 | 1,133,250 |
| READ Codes | 10 | 5,468,678 |
| SNOMED History | 9 | 5,070,302 |
| SNOMED Lexicon | 3 | 13,103,993 |
| SNOMED Query Table | 1 | 22,918,684 |
| SNOMED Transitive Closure | 1 | 11,637,305 |
| SNOMED Core | 6 | 8,245,661 |
| **TOTAL** | **46** | **69,105,879** |

> User/Application Data tables are not included in TRUD distribution.

---

## Schema Verification

This schema documentation was verified against the actual SQL Server database on **2025-12-28**. All table names, column names, data types, and row counts match the exported database structure.

**DMWB Version:** 41.2.0 (November 2025 release from TRUD)

**Key notes:**
- Hierarchy tables (SCTHIER, RCTHIER, CTV3HIER) use `CHILD`/`PARENT`/`CTERM`/`PTERM`/`DNUM` columns
- Read Code tables (RCT, CTV3) use `T30`/`T60`/`T198` term length columns instead of single `TERM` column
- Transitive closure tables use `SupertypeID`/`SubtypeID` column naming
- RCTTC uses `SUBTYPEID`/`SUPERTYPEID` (all uppercase)
- User/Application Data databases are not included in TRUD distribution

---

## See Also

- [Export Process Documentation](README_Export_To_SQL.md)
- [SQL Server Migration Summary](../docs/SQL_Migration_Summary.md)
- [SQL Server Mapping Functions Guide](../docs/SQL_Server_Mapping_Functions_Guide.md)
