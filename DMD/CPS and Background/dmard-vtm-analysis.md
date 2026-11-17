# DMARD VTM Analysis - dm+d Investigation

**Date:** June 2026  
**Purpose:** Establish how the VTM-first ingredient pivot algorithm performs for DMARD monitoring searches, and verify that VTM-direct traversal gives a complete result for each drug in the class.

---

## 1. Summary Finding

Every DMARD tested returns **direct VMPs = expanded VMPs**. The ingredient pivot adds zero additional products for any drug in this class. This is the most important positive finding from the algorithm validation: the drugs requiring the most rigorous blood test monitoring in general practice are exactly the drugs where the algorithm is simplest, most reliable, and requires no toggle decision from the clinician.

| Drug | VTM | Ingredient ISIDs | Direct VMPs | Expanded VMPs | Extra |
| :-- | :-- | :-- | --: | --: | --: |
| Methotrexate | Single VTM | 2 (base + sodium salt) | 110 | 110 | 0 |
| Azathioprine | Single VTM | 1 | 70 | 70 | 0 |
| Hydroxychloroquine | Single VTM | 1 | 34 | 34 | 0 |
| Ciclosporin | Single VTM | 1 | 18 | 18 | 0 |
| Mycophenolate mofetil | Single VTM | 2 (mofetil + hydrochloride) | 10 | 10 | 0 |
| Sulfasalazine | Single VTM | 1 | 10 | 10 | 0 |
| Penicillamine | Single VTM | 1 | 8 | 8 | 0 |
| Leflunomide | Single VTM | 1 | 4 | 4 | 0 |
| **Total across class** | | | **274** | **274** | **0** |

---

## 2. Ingredient ISID Analysis

| VTM | Ingredient ISID | Ingredient name | VMPs |
| :-- | :-- | :-- | --: |
| Methotrexate | `387381009` | Methotrexate | 61 |
| Methotrexate | `412247000` | Methotrexate sodium | 49 |
| Azathioprine | `372574004` | Azathioprine | 70 |
| Hydroxychloroquine | `13502005` | Hydroxychloroquine sulfate | 34 |
| Ciclosporin | `387467008` | Ciclosporin | 18 |
| Mycophenolate mofetil | `386976000` | Mycophenolate mofetil | 9 |
| Mycophenolate mofetil | `441632007` | Mycophenolate mofetil hydrochloride | 1 |
| Sulfasalazine | `387248006` | Sulfasalazine | 10 |
| Penicillamine | `387235007` | Penicillamine | 8 |
| Leflunomide | `386981009` | Leflunomide | 4 |

The pivot from each ISID finds only VMPs already in the direct set - confirming that none of these substances appear as components of fixed-dose combination products in dm+d.

---

## 3. Drug-by-Drug Analysis

### Methotrexate - 110 VMPs

Two ingredient ISIDs under one VTM. VTM-direct captures both automatically:

- **Methotrexate base** (`387381009`): 61 VMPs - oral tablets, oral solutions/suspensions, subcutaneous pre-filled syringes
- **Methotrexate sodium** (`412247000`): 49 VMPs - high-dose IV preparations and some injectable forms

The clinician types "methotrexate", selects one VTM, and gets all 110 VMPs - oral DMARD tablets, self-injection devices (Metoject, Methofar, Jylamvo), and hospital IV preparations - in a single step. The salt split is invisible to the user and requires no additional selection.

No combination products exist for methotrexate anywhere in dm+d. The ingredient pivot is a no-op: both ISIDs are unique to this VTM.

**Monitoring note:** Ardens DMARD monitoring for methotrexate includes FBC, U&E, LFT at 12-week intervals. The 110 VMPs span all routes (oral and subcutaneous), so both the GP-initiated oral DMARD patients and the self-injection patients are captured by a single VTM selection.

---

### Azathioprine - 70 VMPs

Single ingredient ISID (`372574004`). The 70 VMPs reflect dm+d's comprehensive specials coverage: three standard solid-dose tablets (25mg, 50mg, 75mg, 100mg) plus a very large number of oral liquid preparations at different concentrations, and one IV preparation.

Selected VMPs:

| VMP | Notes |
| :-- | :-- |
| Azathioprine 25mg tablets | Standard oral DMARD - most common GP prescription |
| Azathioprine 50mg tablets | Standard oral DMARD |
| Azathioprine 75mg tablets | Standard oral DMARD |
| Azathioprine 100mg tablets | Standard oral DMARD |
| Azathioprine 50mg powder for solution for injection vials | Hospital IV - rare in GP records |
| Azathioprine 2.5mg/5ml oral solution | Paediatric liquid |
| Azathioprine 5mg/5ml, 10mg/5ml, 25mg/5ml ... oral solutions/suspensions | Specials: many fine-grained concentrations for weight-based paediatric or LD dosing |

The large number of oral liquid VMPs (approximately 60 of the 70) represents dm+d's extemporaneous and specials preparations registered at very specific concentrations to support weight-based or dose-titrated prescribing. These are valid prescribable products and correct to include in a monitoring search.

**Monitoring note:** Ardens requires FBC, U&E, LFT - initially every 4 weeks, then every 12 weeks at stable dose. All 70 VMPs would be included regardless of route or formulation.

---

### Hydroxychloroquine - 34 VMPs

Single ingredient ISID (`13502005 | Hydroxychloroquine sulfate`). Note: dm+d names this as "Hydroxychloroquine sulfate" (the salt form) internally, but the VTM name is "Hydroxychloroquine". VTM-direct correctly captures all 34 VMPs under the single VTM - the salt form distinction is invisible to the user.

Selected VMPs:

| VMP | Notes |
| :-- | :-- |
| Hydroxychloroquine 200mg tablets | Quinoric, Plaquenil - standard oral tablet |
| Hydroxychloroquine 300mg tablets | Higher-strength tablet for weight-based dosing |
| Hydroxychloroquine 100mg/5ml–400mg/5ml oral solutions/suspensions | Many concentration variants for liquid dosing |

**Monitoring note:** Ardens requires ophthalmology retinopathy screening at 1 year if taken for more than 5 years. This is a coding-based check (presence of retinopathy screen code) combined with the medication check, not a blood test. All 34 VMPs are relevant.

---

### Leflunomide - 4 VMPs

Single ingredient ISID (`386981009`). Clean and simple:

| VMP |
| :-- |
| Leflunomide 10mg tablets |
| Leflunomide 15mg tablets |
| Leflunomide 20mg tablets |
| Leflunomide 100mg tablets |

The 100mg loading dose tablet and the three maintenance dose strengths. VTM-direct is complete. No liquid preparations, no IV, no combination products.

**Monitoring note:** Ardens requires BP/weight check plus FBC/U&E/LFT every 12 weeks.

---

### Sulfasalazine - 10 VMPs

Single ingredient ISID (`387248006`). Covers all standard forms:

| VMP | Notes |
| :-- | :-- |
| Sulfasalazine 500mg tablets | Standard oral tablet |
| Sulfasalazine 500mg gastro-resistant tablets | EC tablet (Salazopyrin EN) |
| Sulfasalazine 500mg suppositories | Rectal - IBD use, may appear in RA/IBD crossover patients |
| Sulfasalazine 3g/100ml retention enema | Rectal |
| Sulfasalazine 500mg/5ml oral suspension | Liquid |
| Sulfasalazine 100–250mg/5ml oral suspensions (5 VMPs) | Specials liquid preparations |

**Monitoring note:** Ardens requires FBC, U&E, LFT - initially monthly, then every 3 months.

---

### Ciclosporin - 18 VMPs - Note: includes ophthalmic preparations

Single ingredient ISID (`387467008`). The 18 VMPs span **two distinct clinical uses**:

**Systemic immunosuppressant (6 VMPs):**

| VMP |
| :-- |
| Ciclosporin 10mg capsules |
| Ciclosporin 25mg capsules |
| Ciclosporin 50mg capsules |
| Ciclosporin 100mg capsules |
| Ciclosporin 100mg/ml oral solution sugar free |
| Ciclosporin 250mg/5ml solution for infusion ampoules |
| Ciclosporin 50mg/1ml solution for infusion ampoules |

**Ophthalmic preparations (11 VMPs):**

| VMP | Indication |
| :-- | :-- |
| Ciclosporin 0.05% eye drops 0.4ml unit dose preservative free | Dry eye disease (Ikervis) |
| Ciclosporin 0.06% eye drops 0.4ml unit dose preservative free | Dry eye disease |
| Ciclosporin 0.06% eye drops preservative free | Dry eye disease |
| Ciclosporin 0.2% eye ointment | Dry eye / keratitis |
| Ciclosporin 0.2% eye ointment preservative free | Dry eye / keratitis |
| Ciclosporin 1mg/ml eye drops 0.3ml unit dose | Vernal keratoconjunctivitis (Verkazia) |
| Ciclosporin 1mg/ml eye drops preservative free | |
| Ciclosporin 2% eye drops | Atopic keratoconjunctivitis |
| Ciclosporin 2% eye drops preservative free | |
| Ciclosporin 2% eye ointment | |
| Ciclosporin 900micrograms/ml eye drops 0.25ml unit dose preservative free | |

**Important limitation:** A patient on ciclosporin eye drops for dry eye disease does not require systemic DMARD monitoring (U&E, LFT, FBC, BP). VTM-direct returns all 18 VMPs and does not distinguish ophthalmic from systemic. A monitoring report built on the Ciclosporin VTM would therefore send monitoring reminders to patients on eye drops - a false positive.

This is a genuine limitation of the VTM-first approach for ciclosporin specifically. The correct implementation for ciclosporin monitoring would filter to systemic formulations only, either by:
- Excluding ophthalmic route VMPs (those with "eye drops" or "eye ointment" in the VMP name)
- Using a curated list of specific systemic VMPs rather than VTM-direct

This should be flagged as a required implementation decision for any ciclosporin monitoring search.

---

### Mycophenolate mofetil - 10 VMPs

Two ingredient ISIDs under one VTM:
- `386976000 | Mycophenolate mofetil`: 9 VMPs
- `441632007 | Mycophenolate mofetil hydrochloride`: 1 VMP

Both under the same VTM - VTM-direct captures all 10, the salt split is invisible to the user. Includes capsules, tablets, oral suspensions, an IV preparation, and one topical preparation.

**Note:** One VMP - `Mycophenolate mofetil 0.1% in White soft paraffin` - is a topical dermatological preparation. As with ciclosporin, a patient using topical mycophenolate for a skin condition would not require systemic immunosuppressant monitoring. This may warrant the same formulation-level filter as ciclosporin, though topical mycophenolate is far rarer in UK GP prescribing.

---

### Penicillamine - 8 VMPs

Single ingredient ISID (`387235007`). Complete set:

| VMP |
| :-- |
| Penicillamine 125mg tablets |
| Penicillamine 250mg tablets |
| Penicillamine gastro-resistant 150mg tablets |
| Penicillamine gastro-resistant 300mg tablets |
| Penicillamine 50mg/5ml oral solution |
| Penicillamine 125mg/5ml oral solution |
| Penicillamine 250mg/5ml oral solution |
| Penicillamine 250mg/5ml oral suspension |

**Monitoring note:** Ardens requires U&E and urinalysis at intervals. Penicillamine prescribing has declined significantly in favour of newer DMARDs, but monitoring patients who remain on long-term penicillamine is still required.

---

## 4. The Ciclosporin Ophthalmic Problem

The ciclosporin case is the only DMARD where VTM-direct over-matches relative to the clinical monitoring intent. The other seven drugs either have no ophthalmic forms or have topical forms that are sufficiently rare in the patient population that the effect is negligible.

For a monitoring implementation, the recommended approach for ciclosporin is:

**Option A (preferred):** After VTM-direct, filter to systemic VMPs by excluding VMPs where the name contains "eye drops", "eye ointment", or "ophthalmic".

**Option B:** Allow the GP to see the VMP list in the selection card and deselect the ophthalmic VMPs before saving.

**Option C (simplest):** Document that the ciclosporin monitoring search may generate false positives for dry eye patients, and accept that GPs will recognise these as irrelevant when reviewing the recall list.

---

## 5. Comparison with Lithium and Valproate

| Property | DMARDs | Lithium | Valproate |
| :-- | :-- | :-- | :-- |
| Multiple VTMs required? | No - one VTM per drug | Yes - 3 VTMs | Yes - 2 VTMs |
| Algorithm bridges gaps? | N/A - no gaps | No | No |
| Combination products? | Zero across whole class | None | None |
| Toggle needed? | No | No | No |
| Key complication | Ciclosporin includes ophthalmic VMPs | Citrate liquid missed if only carbonate selected | Depakote missed if only sodium valproate selected |
| Patient safety consequence | False positives for dry eye patients | 50% of lithium cohort missed | 22% of valproate cohort missed + MHRA programme compliance |

The DMARDs are the algorithmically cleanest drug class in this analysis. The only practical complication (ciclosporin ophthalmic) affects false positives, not false negatives - it is a lower-severity problem than the false negatives in the lithium and valproate cases.

---

## 6. SQL Used in This Analysis

All queries run against `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release (`nhsbsa_dmd_6.0.0_20260601000001`).

### 6.1 Ingredient ISIDs for each DMARD VTM

```sql
SELECT vtm.nm          AS vtm_name,
       i.isid,
       i.nm            AS ingredient,
       COUNT(DISTINCT v.vpid) AS vmps
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm            vtm ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.vmp_ingredient vi  ON vi.vpid   = v.vpid
JOIN   dmd.dbo.ingredient     i   ON i.isid    = vi.isid
WHERE  vtm.nm IN (
           'Methotrexate', 'Azathioprine', 'Hydroxychloroquine',
           'Leflunomide', 'Sulfasalazine', 'Ciclosporin',
           'Mycophenolate mofetil', 'Penicillamine'
       )
  AND  vtm.invalid = 0
GROUP BY vtm.nm, i.isid, i.nm
ORDER BY vtm.nm, vmps DESC;
```

### 6.2 Algorithm validation - direct vs expanded VMP count for each drug

This is the core algorithm test. For each DMARD VTM, it computes:
- `direct_vmps`: VMPs returned by VTM-direct traversal (Step 2 of the algorithm)
- `expanded_vmps`: VMPs returned by VTM-direct *plus* the ingredient pivot (Steps 2 + 3)
- A result where `direct_vmps = expanded_vmps` confirms zero combination products exist

```sql
SELECT vtm.nm    AS vtm_name,
       vtm.vtmid,
       COUNT(DISTINCT v.vpid) AS direct_vmps,

       -- Ingredient pivot: find all VMPs sharing an ISID with this VTM's VMPs
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
           'Methotrexate', 'Azathioprine', 'Hydroxychloroquine',
           'Leflunomide', 'Sulfasalazine', 'Ciclosporin',
           'Mycophenolate mofetil', 'Penicillamine'
       )
  AND  vtm.invalid = 0
GROUP BY vtm.vtmid, vtm.nm
ORDER BY vtm.nm;
```

### 6.3 Full VMP list for a single DMARD

Replace `'Methotrexate'` with any drug name to enumerate its products:

```sql
SELECT v.vpid, v.nm AS vmp_name, v.invalid
FROM   dmd.dbo.vmp v
WHERE  v.vtmid = (
           SELECT vtmid
           FROM   dmd.dbo.vtm
           WHERE  nm = 'Methotrexate'
             AND  invalid = 0
       )
ORDER BY v.nm;
```

### 6.4 Confirm whether a pivot crosses VTM boundaries

To verify that the ingredient pivot from drug A does *not* reach drug B (e.g. confirming methotrexate ISIDs are not shared with any other VTM):

```sql
SELECT vtm2.nm             AS found_in_vtm,
       COUNT(DISTINCT v2.vpid) AS vmps,
       CASE WHEN v2.vtmid = vtm_src.vtmid
            THEN 'direct'
            ELSE 'via pivot' END AS source
FROM   dmd.dbo.vtm            vtm_src
JOIN   dmd.dbo.vmp            v       ON v.vtmid    = vtm_src.vtmid
JOIN   dmd.dbo.vmp_ingredient vi      ON vi.vpid    = v.vpid
JOIN   dmd.dbo.vmp_ingredient vi2     ON vi2.isid   = vi.isid
JOIN   dmd.dbo.vmp            v2      ON v2.vpid    = vi2.vpid
JOIN   dmd.dbo.vtm            vtm2   ON vtm2.vtmid = v2.vtmid
WHERE  vtm_src.nm = 'Methotrexate'
GROUP BY vtm2.nm, v2.vtmid, vtm_src.vtmid
ORDER BY source, vmps DESC;
```

A result containing only one row - the source VTM with `source = 'direct'` - confirms no cross-VTM expansion occurs.

### 6.5 Ciclosporin: separate systemic from ophthalmic VMPs

```sql
-- Systemic VMPs only (exclude ophthalmic routes)
SELECT v.vpid, v.nm
FROM   dmd.dbo.vmp v
WHERE  v.vtmid = (SELECT vtmid FROM dmd.dbo.vtm WHERE nm = 'Ciclosporin')
  AND  v.nm NOT LIKE '%eye drop%'
  AND  v.nm NOT LIKE '%eye oint%'
  AND  v.nm NOT LIKE '%ophthalmic%'
ORDER BY v.nm;

-- Ophthalmic VMPs only
SELECT v.vpid, v.nm
FROM   dmd.dbo.vmp v
WHERE  v.vtmid = (SELECT vtmid FROM dmd.dbo.vtm WHERE nm = 'Ciclosporin')
  AND  (v.nm LIKE '%eye drop%' OR v.nm LIKE '%eye oint%')
ORDER BY v.nm;
```

### 6.6 Full algorithm - production-ready query for a DMARD class report

Returns all VMPs for a set of DMARD VTMs, expanded to VMPP → AMP → AMPP, active products only:

```sql
-- Step 1: collect direct VMPs for all selected DMARD VTMs
SELECT DISTINCT v.vpid, v.nm AS vmp_name, vtm.nm AS vtm_name, 'VMP' AS level
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm vtm ON vtm.vtmid = v.vtmid
WHERE  vtm.nm IN (
           'Methotrexate', 'Azathioprine', 'Hydroxychloroquine',
           'Leflunomide', 'Sulfasalazine', 'Mycophenolate mofetil',
           'Penicillamine'
       )
  AND  vtm.invalid = 0
  -- Optionally filter to active products only:
  -- AND v.invalid = 0

UNION ALL

-- Step 2: VMPPs under those VMPs
SELECT DISTINCT vmpp.vppid, vmpp.nm, vtm.nm, 'VMPP'
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm  vtm  ON vtm.vtmid  = v.vtmid
JOIN   dmd.dbo.vmpp vmpp ON vmpp.vpid  = v.vpid
WHERE  vtm.nm IN (
           'Methotrexate', 'Azathioprine', 'Hydroxychloroquine',
           'Leflunomide', 'Sulfasalazine', 'Mycophenolate mofetil',
           'Penicillamine'
       )
  AND  vtm.invalid = 0

UNION ALL

-- Step 3: AMPs under those VMPs
SELECT DISTINCT amp.apid, amp.nm, vtm.nm, 'AMP'
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm vtm ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.amp amp ON amp.vpid  = v.vpid
WHERE  vtm.nm IN (
           'Methotrexate', 'Azathioprine', 'Hydroxychloroquine',
           'Leflunomide', 'Sulfasalazine', 'Mycophenolate mofetil',
           'Penicillamine'
       )
  AND  vtm.invalid = 0

UNION ALL

-- Step 4: AMPPs under those AMPs
SELECT DISTINCT ampp.appid, ampp.nm, vtm.nm, 'AMPP'
FROM   dmd.dbo.vmp  v
JOIN   dmd.dbo.vtm  vtm  ON vtm.vtmid  = v.vtmid
JOIN   dmd.dbo.amp  amp  ON amp.vpid   = v.vpid
JOIN   dmd.dbo.ampp ampp ON ampp.apid  = amp.apid
WHERE  vtm.nm IN (
           'Methotrexate', 'Azathioprine', 'Hydroxychloroquine',
           'Leflunomide', 'Sulfasalazine', 'Mycophenolate mofetil',
           'Penicillamine'
       )
  AND  vtm.invalid = 0

ORDER BY vtm_name, level, vmp_name;
```

No ingredient pivot step is included because the validation confirmed `direct_vmps = expanded_vmps` for every drug in this class. The ingredient pivot would be a no-op and is omitted for clarity and performance.
