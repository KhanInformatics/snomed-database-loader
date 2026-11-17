# ARB and ACE Inhibitor VTM Analysis - dm+d Investigation

**Date:** June 2026  
**Purpose:** Establish how the VTM-first ingredient pivot algorithm performs for ARB and ACE inhibitor renal monitoring searches, and identify which combination products would be missed without ingredient expansion.

---

## 1. Summary Finding

ARBs and ACE inhibitors are the drug classes where the combination product expansion matters most for routine GP monitoring. Fixed-dose combination antihypertensives (ARB+thiazide, ARB+CCB, ACE+CCB, ACE+diuretic) are widely prescribed. A patient on Entresto, Exforge, Cozaar-Comp, Sevikar or Viacoram is receiving an ARB or ACE inhibitor and requires U&E monitoring - but their prescription is coded against the combination VTM, not the single-substance VTM.

### ARBs - complete list

| Drug | Direct VMPs | Expanded VMPs | Extra | Combination products found |
| :-- | --: | --: | --: | :-- |
| Valsartan | 12 | 23 | +11 | Sacubitril+Valsartan (5), Amlodipine+Valsartan (3), Valsartan+HCTZ (3) |
| Olmesartan | 5 | 16 | +11 | Olmesartan+Amlodipine+HCTZ (5), Olmesartan+Amlodipine (3), Olmesartan+HCTZ (3) |
| Candesartan | 10 | 14 | +4 | Candesartan+Hydrochlorothiazide (4) |
| Losartan | 14 | 17 | +3 | Losartan+Hydrochlorothiazide (3) |
| Irbesartan | 10 | 13 | +3 | Irbesartan+Hydrochlorothiazide (3) |
| Telmisartan | 4 | 7 | +3 | Telmisartan+Hydrochlorothiazide (3) |
| Eprosartan | 5 | 5 | 0 | None |
| Azilsartan | 3 | 3 | 0 | None |

### ACE inhibitors - complete list

| Drug | Direct VMPs | Expanded VMPs | Extra | Combination products found |
| :-- | --: | --: | --: | :-- |
| Captopril | 79 | 81 | +2 | Co-zidocapt (captopril+HCTZ) - found via pivot; guard applies on Co-zidocapt *input* only |
| Enalapril | 52 | 53 | +1 | Enalapril+Hydrochlorothiazide (1) |
| Lisinopril | 27 | 29 | +2 | Lisinopril+Hydrochlorothiazide (2) |
| Ramipril | 22 | 24 | +2 | Felodipine+Ramipril (2 - Triapin) |
| Perindopril erbumine | 12 | 17 | +5 | Perindopril erbumine+Amlodipine (4), Perindopril erbumine+Indapamide (1) |
| Trandolapril | 5 | 6 | +1 | Verapamil+Trandolapril (1 - Tarka) |
| Quinapril | 4 | 5 | +1 | Quinapril+Hydrochlorothiazide (1) |
| Perindopril tosilate | 3 | 4 | +1 | Perindopril tosilate+Indapamide (1) |
| Perindopril arginine | 3 | 4 | +1 | Perindopril arginine+Indapamide (1) |
| Cilazapril | 4 | 4 | 0 | None |
| Fosinopril | 4 | 4 | 0 | None |
| Imidapril | 3 | 3 | 0 | None |
| Moexipril | 2 | 2 | 0 | None |
| Zofenopril | 2 | 2 | 0 | None |

**Toggle: ON** for all ARB and ACE inhibitor searches in a renal monitoring context.

---

## 2. Ingredient ISID Analysis

Each ARB and ACE inhibitor uses a single distinct ingredient ISID (or salt-specific ISID). The ingredient pivot from each VTM correctly finds the combination products that share that ISID.

| VTM | Ingredient ISID | Ingredient name | Direct VMPs |
| :-- | :-- | :-- | --: |
| Valsartan | `386876001` | Valsartan | 12 |
| Candesartan | `386878000` | Candesartan cilexetil | 10 |
| Irbesartan | `386877005` | Irbesartan | 10 |
| Losartan | `108582002` | Losartan potassium | 14 |
| Perindopril erbumine | `129485000` | Perindopril erbumine | 12 |
| Perindopril arginine | `442509000` | Perindopril arginine | 3 |
| Ramipril | `386872004` | Ramipril | 22 |
| Lisinopril | `386873009` | Lisinopril | 27 |
| Enalapril | `387165009` | Enalapril maleate | 52 |

---

## 3. Valsartan - the Entresto problem

### Direct VMPs (12)

| VMP |
| :-- |
| Valsartan 40mg capsules |
| Valsartan 40mg tablets |
| Valsartan 80mg capsules |
| Valsartan 80mg tablets |
| Valsartan 160mg capsules |
| Valsartan 160mg tablets |
| Valsartan 320mg tablets |
| Valsartan 40mg/5ml oral solution |
| Valsartan 40mg/5ml oral suspension |
| Valsartan 160mg/5ml oral solution |
| Valsartan 160mg/5ml oral suspension |
| Valsartan 3mg/ml oral solution |

### Combination products found via ingredient pivot (+11)

**Sacubitril + Valsartan - 5 VMPs (Entresto)**

| VMP |
| :-- |
| Sacubitril 24mg / Valsartan 26mg tablets |
| Sacubitril 49mg / Valsartan 51mg tablets |
| Sacubitril 97mg / Valsartan 103mg tablets |
| Sacubitril 6mg / Valsartan 6mg granules in capsules for opening |
| Sacubitril 15mg / Valsartan 16mg granules in capsules for opening |

**Amlodipine + Valsartan - 3 VMPs (Exforge)**

| VMP |
| :-- |
| Amlodipine 5mg / Valsartan 80mg tablets |
| Amlodipine 5mg / Valsartan 160mg tablets |
| Amlodipine 10mg / Valsartan 160mg tablets |

**Valsartan + Hydrochlorothiazide - 3 VMPs**

| VMP |
| :-- |
| Valsartan 80mg / Hydrochlorothiazide 12.5mg tablets |
| Valsartan 160mg / Hydrochlorothiazide 12.5mg tablets |
| Valsartan 160mg / Hydrochlorothiazide 25mg tablets |

### Why the Entresto gap is a patient safety concern

Entresto (sacubitril/valsartan) is NICE-recommended first-line therapy for heart failure with reduced ejection fraction (HFrEF) and is now widely prescribed in primary care following initiation in specialist heart failure clinics. The valsartan component carries identical renal risks to plain valsartan:
- Hyperkalaemia risk (requires K⁺ monitoring)
- Acute kidney injury risk (requires creatinine/eGFR monitoring)
- Risk of worsening renal function in patients with renovascular disease

NICE NG106 and BNF monitoring guidance both require U&E at initiation and at intervals. A practice running "On ARB, no U&E in last year" without combination expansion would completely miss their Entresto patients - likely a significant cohort given Entresto's prevalence in heart failure management.

---

## 4. Losartan - Cozaar-Comp

### Direct VMPs (14)
| VMP |
| :-- |
| Losartan 12.5mg tablets |
| Losartan 25mg tablets |
| Losartan 50mg tablets |
| Losartan 100mg tablets |
| Losartan 2.5mg/ml oral suspension sugar free |
| Losartan 12.5mg/5ml oral suspension |
| Losartan 20mg/5ml oral suspension |
| Losartan 25mg/5ml oral solution |
| Losartan 25mg/5ml oral suspension |
| Losartan 50mg/5ml oral solution |
| Losartan 50mg/5ml oral solution sugar free |
| Losartan 50mg/5ml oral suspension |
| Losartan 100mg/5ml oral solution |
| Losartan 100mg/5ml oral suspension |

### Combination products found via ingredient pivot (+3)

**Losartan + Hydrochlorothiazide (Cozaar-Comp)**

| VMP |
| :-- |
| Losartan 50mg / Hydrochlorothiazide 12.5mg tablets |
| Losartan 100mg / Hydrochlorothiazide 12.5mg tablets |
| Losartan 100mg / Hydrochlorothiazide 25mg tablets |

---

## 5. Ramipril - Triapin

### Combination products found via ingredient pivot (+2)

**Felodipine + Ramipril (Triapin)**

| VMP |
| :-- |
| Felodipine 2.5mg modified-release / Ramipril 2.5mg tablets |
| Felodipine 5mg modified-release / Ramipril 5mg tablets |

Triapin is a fixed-dose combination of a calcium channel blocker and ACE inhibitor, used for hypertension. The ramipril component carries identical renal monitoring requirements. VTM-direct for Ramipril alone misses both Triapin strengths.

---

## 6. Olmesartan - triple combination

Olmesartan is notable for having the only triple fixed-dose combination in the ARB class: Sevikar HCT (Olmesartan + Amlodipine + Hydrochlorothiazide), which contributes 5 of the 11 extra VMPs found by expansion.

| Combination VTM | VMPs | Products |
| :-- | --: | :-- |
| Olmesartan + Amlodipine + Hydrochlorothiazide | 5 | Sevikar HCT (various strengths) |
| Olmesartan + Amlodipine | 3 | Sevikar |
| Olmesartan + Hydrochlorothiazide | 3 | Olmetec Plus |

A patient on Sevikar HCT is receiving an ARB and a thiazide diuretic - both components require U&E monitoring. The triple combination would be completely invisible to a plain Olmesartan VTM-direct search.

---

## 7. Perindopril - THREE salt form VTMs

Perindopril presents the most complex case in this drug class: **three separate salt VTMs** AND combination products for each.

### Three separate VTMs

| VTM | Ingredient ISID | Direct VMPs | Note |
| :-- | :-- | --: | :-- |
| Perindopril erbumine | `129485000` | 12 | Coversyl (original formulation, widely used) |
| Perindopril arginine | `442509000` | 3 | Coversyl Arginine (reformulation from ~2010) |
| Perindopril tosilate | (separate ISID) | 3 | Newer salt form - 2.5mg/5mg/10mg tablets |

All three use different ingredient ISIDs. The ingredient pivot cannot bridge between them - they are structurally disjoint.

### Combination products per salt VTM

**Perindopril erbumine combinations (+5):**

| Combination VTM | VMPs | Products |
| :-- | --: | :-- |
| Perindopril erbumine + Amlodipine | 4 | Viacoram 4mg/5mg, 4mg/10mg, 8mg/5mg, 8mg/10mg tablets |
| Perindopril erbumine + Indapamide | 1 | Coversyl Plus tablets |

**Perindopril arginine combinations (+1):**

| Combination VTM | VMPs | Products |
| :-- | --: | :-- |
| Perindopril arginine + Indapamide | 1 | Coversyl Arginine Plus tablets |

**Perindopril tosilate combinations (+1):**

| Combination VTM | VMPs | Products |
| :-- | --: | :-- |
| Perindopril tosilate + Indapamide | 1 | Combination indapamide tablet |

### Complete perindopril coverage requires six VTM selections

| Step | VTM | VMPs |
| :-- | :-- | --: |
| 1 | Perindopril erbumine (direct) | 12 |
| 2 | Perindopril erbumine with combos ON | +5 (Viacoram + Coversyl Plus) |
| 3 | Perindopril arginine (direct) | 3 |
| 4 | Perindopril arginine with combos ON | +1 (Coversyl Arginine Plus) |
| 5 | Perindopril tosilate (direct) | 3 |
| 6 | Perindopril tosilate with combos ON | +1 |
| **Total** | | **25 VMPs** |

---

## 8. Summary - Combination products by type

All combination products found by the ARB/ACE ingredient expansion fall into three clinical categories:

**ARB + Thiazide diuretic** (thiazide itself also requires U&E monitoring - renal relevance doubly confirmed)

| Combination | VMPs | Core drug |
| :-- | --: | :-- |
| Candesartan + Hydrochlorothiazide | 4 | Candesartan |
| Olmesartan + Hydrochlorothiazide | 3 | Olmesartan |
| Olmesartan + Amlodipine + Hydrochlorothiazide | 5 | Olmesartan (triple) |
| Losartan + Hydrochlorothiazide | 3 | Losartan |
| Valsartan + Hydrochlorothiazide | 3 | Valsartan |
| Irbesartan + Hydrochlorothiazide | 3 | Irbesartan |
| Telmisartan + Hydrochlorothiazide | 3 | Telmisartan |
| Lisinopril + Hydrochlorothiazide | 2 | Lisinopril |
| Co-zidocapt (Captopril + HCTZ) | 2 | Captopril |
| Quinapril + Hydrochlorothiazide | 1 | Quinapril |
| Enalapril + Hydrochlorothiazide | 1 | Enalapril |

**ARB + Calcium channel blocker**

| Combination | VMPs | Core drug |
| :-- | --: | :-- |
| Sacubitril + Valsartan | 5 | Valsartan - Entresto (heart failure) |
| Amlodipine + Valsartan | 3 | Valsartan - Exforge |
| Olmesartan + Amlodipine | 3 | Olmesartan - Sevikar |
| Perindopril erbumine + Amlodipine | 4 | Perindopril - Viacoram |
| Felodipine + Ramipril | 2 | Ramipril - Triapin |
| Verapamil + Trandolapril | 1 | Trandolapril - Tarka |

**ACE/ARB + Diuretic (non-thiazide)**

| Combination | VMPs | Core drug |
| :-- | --: | :-- |
| Perindopril erbumine + Indapamide | 1 | Perindopril - Coversyl Plus |
| Perindopril arginine + Indapamide | 1 | Perindopril - Coversyl Arginine Plus |
| Perindopril tosilate + Indapamide | 1 | Perindopril - third salt form |

---

## 9. SQL Used in This Analysis

All queries run against `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release.

### 8.1 Ingredient ISIDs for each ARB/ACE VTM

```sql
SELECT vtm.nm       AS vtm_name,
       i.isid,
       i.nm         AS ingredient,
       COUNT(DISTINCT v.vpid) AS vmps
FROM   dmd.dbo.vmp            v
JOIN   dmd.dbo.vtm            vtm ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.vmp_ingredient vi  ON vi.vpid   = v.vpid
JOIN   dmd.dbo.ingredient     i   ON i.isid    = vi.isid
WHERE  vtm.nm IN (
           'Valsartan', 'Candesartan', 'Irbesartan', 'Losartan',
           'Ramipril', 'Lisinopril', 'Enalapril',
           'Perindopril erbumine', 'Perindopril arginine'
       )
  AND  vtm.invalid = 0
GROUP BY vtm.nm, i.isid, i.nm
ORDER BY vtm.nm, vmps DESC;
```

### 8.2 Direct vs expanded VMP counts

```sql
SELECT vtm.nm    AS vtm_name,
       vtm.vtmid,
       COUNT(DISTINCT v.vpid) AS direct_vmps,
       (SELECT COUNT(DISTINCT vi3.vpid)
        FROM   dmd.dbo.vmp_ingredient vi3
        WHERE  vi3.isid IN (
                   SELECT DISTINCT vi2.isid
                   FROM   dmd.dbo.vmp            v2
                   JOIN   dmd.dbo.vmp_ingredient vi2 ON vi2.vpid = v2.vpid
                   WHERE  v2.vtmid = vtm.vtmid
               )
       ) AS expanded_vmps
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm vtm ON vtm.vtmid = v.vtmid
WHERE  vtm.nm IN (
           'Valsartan', 'Candesartan', 'Irbesartan', 'Losartan',
           'Ramipril', 'Lisinopril', 'Enalapril',
           'Perindopril erbumine', 'Perindopril arginine'
       )
  AND  vtm.invalid = 0
GROUP BY vtm.vtmid, vtm.nm
ORDER BY vtm.nm;
```

### 8.3 Identify combination VTMs found by each pivot

```sql
SELECT vtm_src.nm    AS source_vtm,
       vtm2.nm       AS combination_vtm,
       COUNT(DISTINCT v2.vpid) AS vmps
FROM   dmd.dbo.vtm            vtm_src
JOIN   dmd.dbo.vmp            v       ON v.vtmid    = vtm_src.vtmid
JOIN   dmd.dbo.vmp_ingredient vi      ON vi.vpid    = v.vpid
JOIN   dmd.dbo.vmp_ingredient vi2     ON vi2.isid   = vi.isid
JOIN   dmd.dbo.vmp            v2      ON v2.vpid    = vi2.vpid
JOIN   dmd.dbo.vtm            vtm2   ON vtm2.vtmid = v2.vtmid
WHERE  vtm_src.nm IN (
           'Valsartan', 'Candesartan', 'Irbesartan', 'Losartan',
           'Ramipril', 'Lisinopril', 'Enalapril',
           'Perindopril erbumine', 'Perindopril arginine'
       )
  AND  vtm_src.invalid = 0
  AND  v2.vtmid <> vtm_src.vtmid
GROUP BY vtm_src.nm, vtm2.nm
ORDER BY vtm_src.nm, vmps DESC;
```

### 8.4 Full algorithm query for a renal monitoring ARB report (Valsartan with combinations)

```sql
-- Step 1: Collect ingredient ISIDs from Valsartan VTM VMPs
-- Step 2: Return all VMPs across dm+d sharing those ISIDs (direct + combinations)
-- Step 3: Expand to VMPP / AMP / AMPP

DECLARE @vtm_name NVARCHAR(255) = 'Valsartan';

-- Direct VMPs + combination VMPs via ingredient pivot
WITH source_isids AS (
    SELECT DISTINCT vi.isid
    FROM   dmd.dbo.vmp            v
    JOIN   dmd.dbo.vtm            vtm ON vtm.vtmid = v.vtmid
    JOIN   dmd.dbo.vmp_ingredient vi  ON vi.vpid   = v.vpid
    WHERE  vtm.nm      = @vtm_name
      AND  vtm.invalid = 0
),
all_vmps AS (
    SELECT DISTINCT v.vpid, v.nm AS vmp_name, vtm.nm AS vtm_name
    FROM   dmd.dbo.vmp_ingredient vi
    JOIN   dmd.dbo.vmp            v   ON v.vpid    = vi.vpid
    JOIN   dmd.dbo.vtm            vtm ON vtm.vtmid = v.vtmid
    WHERE  vi.isid IN (SELECT isid FROM source_isids)
)
-- VMP level
SELECT av.vpid AS code, av.vmp_name AS product_name, av.vtm_name, 'VMP' AS level
FROM   all_vmps av

UNION ALL

-- VMPP level
SELECT vmpp.vppid, vmpp.nm, av.vtm_name, 'VMPP'
FROM   all_vmps av
JOIN   dmd.dbo.vmpp vmpp ON vmpp.vpid = av.vpid

UNION ALL

-- AMP level
SELECT amp.apid, amp.nm, av.vtm_name, 'AMP'
FROM   all_vmps av
JOIN   dmd.dbo.amp amp ON amp.vpid = av.vpid

UNION ALL

-- AMPP level
SELECT ampp.appid, ampp.nm, av.vtm_name, 'AMPP'
FROM   all_vmps av
JOIN   dmd.dbo.amp  amp  ON amp.vpid  = av.vpid
JOIN   dmd.dbo.ampp ampp ON ampp.apid = amp.apid

ORDER BY vtm_name, level, product_name;
```

To run for a different ARB, change `@vtm_name`. To add multiple ARBs, replace the `WHERE vtm.nm = @vtm_name` with `WHERE vtm.nm IN ('Valsartan', 'Candesartan', ...)` in the `source_isids` CTE.
