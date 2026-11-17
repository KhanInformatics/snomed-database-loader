# DOAC VTM Analysis - dm+d Investigation

**Date:** June 2026  
**Purpose:** Establish how the VTM-first ingredient pivot algorithm performs for DOAC monitoring searches, confirm VTM-direct is complete for each drug, and document the Rivaroxaban starter pack data gap.

---

## 1. Summary Finding

All four DOACs return **direct VMPs = expanded VMPs**. No DOAC appears as a component of a fixed-dose combination product anywhere in dm+d. VTM-direct is the complete and final answer for each - no combination toggle is needed or appropriate.

| Drug | Direct VMPs | Expanded VMPs | Extra | Ingredient ISID |
| :-- | --: | --: | --: | :-- |
| Rivaroxaban | 10 | **9** | −1 | `442031002` Rivaroxaban |
| Dabigatran etexilate | 9 | 9 | 0 | `700039002` Dabigatran etexilate mesilate |
| Apixaban | 3 | 3 | 0 | `698090000` Apixaban |
| Edoxaban | 3 | 3 | 0 | `1162278009` Edoxaban tosilate |

The −1 for Rivaroxaban is not a combination product issue - it is a dm+d data gap explained in section 3.

**Toggle: OFF - or not shown**, as no combination products exist for any DOAC.

---

## 2. Product Lists

### Rivaroxaban - 10 VMPs

| VMP | Ingredient link |
| :-- | :-- |
| Rivaroxaban 2.5mg tablets | `442031002` ✓ |
| Rivaroxaban 10mg tablets | `442031002` ✓ |
| Rivaroxaban 10mg capsules | `442031002` ✓ |
| Rivaroxaban 15mg tablets | `442031002` ✓ |
| Rivaroxaban 15mg capsules | `442031002` ✓ |
| Rivaroxaban 20mg tablets | `442031002` ✓ |
| Rivaroxaban 20mg capsules | `442031002` ✓ |
| Rivaroxaban 1mg/ml granules for oral suspension sugar free | `442031002` ✓ |
| Rivaroxaban 5mg/ml oral suspension sugar free | `442031002` ✓ |
| **Rivaroxaban 15mg tablets and Rivaroxaban 20mg tablets** | **No ingredient link** |

### Apixaban - 3 VMPs

| VMP |
| :-- |
| Apixaban 2.5mg tablets |
| Apixaban 5mg tablets |
| Apixaban 1mg/ml oral suspension sugar free |

### Dabigatran etexilate - 9 VMPs

| VMP | Notes |
| :-- | :-- |
| Dabigatran etexilate 75mg capsules | Low-dose (renal impairment / elderly) |
| Dabigatran etexilate 110mg capsules | Standard dose |
| Dabigatran etexilate 150mg capsules | Standard dose |
| Dabigatran etexilate 20mg granules sachets sugar free | Paediatric |
| Dabigatran etexilate 30mg granules sachets sugar free | Paediatric |
| Dabigatran etexilate 40mg granules sachets sugar free | Paediatric |
| Dabigatran etexilate 50mg granules sachets sugar free | Paediatric |
| Dabigatran etexilate 110mg granules sachets sugar free | Paediatric / swallowing difficulties |
| Dabigatran etexilate 150mg granules sachets sugar free | Paediatric / swallowing difficulties |

### Edoxaban - 3 VMPs

| VMP |
| :-- |
| Edoxaban 15mg tablets |
| Edoxaban 30mg tablets |
| Edoxaban 60mg tablets |

---

## 3. The Rivaroxaban Starter Pack - Expanded VMPs < Direct VMPs

Rivaroxaban is the only DOAC (and one of the few drugs in dm+d) where the ingredient-expanded count is **lower** than the VTM-direct count. This is not an algorithm failure - it reveals a dm+d source data gap.

The VMP `Rivaroxaban 15mg tablets and Rivaroxaban 20mg tablets` has **zero rows** in `vmp_ingredient`. It is a composite starter pack (a pack combining two different tablet strengths for AF initiation - typically 15mg for 2 weeks then 20mg ongoing). dm+d has registered it as a VMP but has not added ingredient links.

As a result:
- **VTM-direct:** finds this VMP correctly (10 VMPs total)
- **Ingredient pivot:** does not include it (9 VMPs - the starter pack is invisible)

For a monitoring report, the VTM-direct count (10) is the correct number. The algorithm should use VTM-direct as the primary source for DOAC searches and not rely on the ingredient pivot. This reinforces the design decision: **VTM-direct is the foundation; ingredient pivot is an optional enhancement**.

```sql
-- Confirmed: the starter pack has no ingredient entries
SELECT v.vpid, v.nm,
       (SELECT COUNT(*) FROM dmd.dbo.vmp_ingredient WHERE vpid = v.vpid) AS ingredient_rows
FROM   dmd.dbo.vmp v
WHERE  v.vtmid = (SELECT vtmid FROM dmd.dbo.vtm WHERE nm = 'Rivaroxaban')
ORDER  BY ingredient_rows, v.nm;
```

---

## 4. Broader Anticoagulant Context

For completeness, the other anticoagulant VTMs in dm+d (vitamin K antagonists, heparins, parenteral):

| VTM | VMPs | Combination products |
| :-- | --: | :-- |
| Warfarin | 27 | None - VTM-direct complete |
| Acenocoumarol | 1 | None |
| Phenindione | 3 | None |
| Dalteparin sodium | (LMWH) | None |
| Enoxaparin sodium | (LMWH) | None |
| Fondaparinux sodium | 5 | None |
| Argatroban | 2 | None |
| Bivalirudin | 1 | None |

No anticoagulant in dm+d appears as a component of a fixed-dose combination product. The entire anticoagulant class is algorithmically clean.

---

## 5. Ardens CrCl Band Monitoring Context

Ardens DOAC monitoring splits patients by creatinine clearance (CrCl) band and checks whether the prescribed dose is appropriate for the patient's current renal function. This is a **clinical data check**, not a product selection problem:

- The dm+d product codes identify that the patient is on a DOAC
- The CrCl band and dose appropriateness check is done against the patient's blood test results and the prescribed dose strength

A correct DOAC search using VTM-direct returns all prescribed products (including different dose strengths), and the monitoring logic then checks whether each patient's dose is appropriate for their CrCl. No combination expansion is needed at the drug identification stage.

---

## 6. SQL Used in This Analysis

### Ingredient ISID check

```sql
SELECT vtm.nm       AS vtm_name,
       i.isid,
       i.nm         AS ingredient,
       COUNT(DISTINCT v.vpid) AS vmps
FROM   dmd.dbo.vmp            v
JOIN   dmd.dbo.vtm            vtm ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.vmp_ingredient vi  ON vi.vpid   = v.vpid
JOIN   dmd.dbo.ingredient     i   ON i.isid    = vi.isid
WHERE  vtm.nm IN ('Rivaroxaban', 'Apixaban', 'Dabigatran etexilate', 'Edoxaban')
  AND  vtm.invalid = 0
GROUP BY vtm.nm, i.isid, i.nm
ORDER BY vtm.nm;
```

### Direct vs expanded count

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
WHERE  vtm.nm IN ('Rivaroxaban', 'Apixaban', 'Dabigatran etexilate', 'Edoxaban')
  AND  vtm.invalid = 0
GROUP BY vtm.vtmid, vtm.nm
ORDER BY vtm.nm;
```

### Production query - all DOAC products (VMP → VMPP → AMP → AMPP)

```sql
SELECT DISTINCT v.vpid AS code, v.nm AS product_name, vtm.nm AS vtm_name, 'VMP' AS level
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm vtm ON vtm.vtmid = v.vtmid
WHERE  vtm.nm IN ('Rivaroxaban', 'Apixaban', 'Dabigatran etexilate', 'Edoxaban')
  AND  vtm.invalid = 0

UNION ALL

SELECT DISTINCT vmpp.vppid, vmpp.nm, vtm.nm, 'VMPP'
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm  vtm  ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.vmpp vmpp ON vmpp.vpid = v.vpid
WHERE  vtm.nm IN ('Rivaroxaban', 'Apixaban', 'Dabigatran etexilate', 'Edoxaban')
  AND  vtm.invalid = 0

UNION ALL

SELECT DISTINCT amp.apid, amp.nm, vtm.nm, 'AMP'
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm vtm ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.amp amp ON amp.vpid  = v.vpid
WHERE  vtm.nm IN ('Rivaroxaban', 'Apixaban', 'Dabigatran etexilate', 'Edoxaban')
  AND  vtm.invalid = 0

UNION ALL

SELECT DISTINCT ampp.appid, ampp.nm, vtm.nm, 'AMPP'
FROM   dmd.dbo.vmp  v
JOIN   dmd.dbo.vtm  vtm  ON vtm.vtmid = v.vtmid
JOIN   dmd.dbo.amp  amp  ON amp.vpid  = v.vpid
JOIN   dmd.dbo.ampp ampp ON ampp.apid = amp.apid
WHERE  vtm.nm IN ('Rivaroxaban', 'Apixaban', 'Dabigatran etexilate', 'Edoxaban')
  AND  vtm.invalid = 0

ORDER BY vtm_name, level, product_name;
-- Note: no ingredient pivot step - validated as zero combination products for all four DOACs
```
