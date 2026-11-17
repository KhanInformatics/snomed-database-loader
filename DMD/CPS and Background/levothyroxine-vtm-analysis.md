# Levothyroxine VTM Analysis - dm+d Investigation

**Date:** June 2026  
**Purpose:** Establish how the VTM-first ingredient pivot algorithm performs for levothyroxine TSH monitoring searches, and document the ISID split within the Levothyroxine + Liothyronine combination VTM.

---

## 1. Summary Finding

| VTM | Direct VMPs | Expanded VMPs | Extra | Notes |
| :-- | --: | --: | --: | :-- |
| Levothyroxine | 146 | 154 | +8 | 8 combination T3/T4 VMPs found via ISID pivot |
| Liothyronine | 27 | 35 | +8 | Same 8 combination T3/T4 VMPs found from T3 direction |
| Levothyroxine + Liothyronine | 12 | - | - | Named combination - guard applies; not pivoted |

**Toggle: ON** if combined T3/T4 patients should be included in a TSH monitoring report.  
**Important caveat:** the pivot finds only 8 of the 12 Levothyroxine + Liothyronine VMPs - 4 are unreachable due to an ISID split (see section 4).

---

## 2. Thyroid VTMs in dm+d

Three active thyroid hormone VTMs exist:

| VTM ID | Name | Status | Clinical use |
| :-- | :-- | :-- | :-- |
| `776526008` | Levothyroxine | Active | T4 replacement - by far the most prescribed |
| `776546003` | Liothyronine | Active | T3 - specialist use, adjunct therapy |
| `776527004` | Levothyroxine + Liothyronine | Active | Combined T3/T4 - specialist, rare in UK |

---

## 3. Ingredient ISID Analysis

### Levothyroxine VTM (146 VMPs)

All 146 VMPs use a single ISID:

| ISID | Ingredient | VMPs |
| :-- | :-- | --: |
| `783637002` | Levothyroxine sodium anhydrous | 146 |

### Levothyroxine + Liothyronine VTM (12 VMPs)

The combination VTM uses **four ISIDs** - two levothyroxine forms and two liothyronine forms:

| ISID | Ingredient | VMPs |
| :-- | :-- | --: |
| `783637002` | Levothyroxine sodium anhydrous | 8 |
| `710809001` | Levothyroxine (base/free acid form) | 4 |
| `126204001` | Liothyronine sodium | 8 |
| `61275002` | Liothyronine (base/free acid form) | 4 |

The 8 VMPs using `783637002` (levothyroxine sodium anhydrous) share an ISID with the Levothyroxine VTM - these are found by the ingredient pivot.

The 4 VMPs using `710809001` (levothyroxine base) are **not** in the Levothyroxine VTM's ingredient set - the Levothyroxine VTM only uses `783637002`. These 4 VMPs are unreachable from the Levothyroxine VTM via the pivot.

The same pattern applies from the Liothyronine direction: the pivot from Liothyronine VTM uses the liothyronine sodium ISID and finds the same 8 combination VMPs. The 4 using the free-acid liothyronine ISID are equally unreachable from that direction.

---

## 4. Pivot Behaviour and the 4 Unreachable VMPs

```
[Levothyroxine VTM]                    [Levothyroxine + Liothyronine VTM]
      |                                           |
146 direct VMPs                               12 VMPs total
  all use ISID 783637002                          |
      |                                   ┌───────┴───────┐
   pivot via                          8 VMPs use     4 VMPs use
   ISID 783637002                     783637002      710809001
      |                               (reachable)    (NOT reachable)
      └──────── finds these 8 ──────────────┘
```

**The 4 unreachable VMPs** use the base/free-acid levothyroxine form (`710809001 | Levothyroxine`):

| VMP |
| :-- |
| Levothyroxine 18microgram / Liothyronine 4microgram tablets |
| Levothyroxine 35microgram / Liothyronine 8microgram tablets |
| Levothyroxine 73microgram / Liothyronine 17microgram tablets |
| Levothyroxine 200microgram / Liothyronine 50microgram tablets |

These appear to be the lower-precision microgram dosing forms (likely Tiromel or similar products where the levothyroxine is not recorded as the sodium anhydrous salt in dm+d).

**The 8 reachable VMPs** use `783637002 | Levothyroxine sodium anhydrous`:

| VMP |
| :-- |
| Levothyroxine sodium 9.5microgram / Liothyronine 2.25microgram tablets |
| Levothyroxine sodium 19microgram / Liothyronine 4.5microgram tablets |
| Levothyroxine sodium 38microgram / Liothyronine 9microgram tablets |
| Levothyroxine sodium 57microgram / Liothyronine 13.5microgram tablets |
| Levothyroxine sodium 76microgram / Liothyronine 18microgram tablets |
| Levothyroxine sodium 114microgram / Liothyronine 27microgram tablets |
| Levothyroxine sodium 152microgram / Liothyronine 36microgram tablets |
| Levothyroxine sodium 190microgram / Liothyronine 45microgram tablets |

These are the Armour Thyroid / desiccated thyroid equivalent T3+T4 fixed-ratio tablets (Thybon Henning, NDT-type products).

---

## 5. The 146 Direct Levothyroxine VMPs

The Levothyroxine VTM has the largest direct VMP count of any endocrine drug in dm+d. The count reflects dm+d's comprehensive capture of specials, liquid preparations and the full range of branded tablets.

**Tablets (8 VMPs - standard and lactose-free):**

| VMP |
| :-- |
| Levothyroxine sodium 12.5microgram tablets |
| Levothyroxine sodium 25microgram tablets |
| Levothyroxine sodium 25microgram tablets lactose free |
| Levothyroxine sodium 50microgram tablets |
| Levothyroxine sodium 50microgram tablets lactose free |
| Levothyroxine sodium 75microgram tablets |
| Levothyroxine sodium 100microgram tablets |
| Levothyroxine sodium 100microgram tablets lactose free |

**Other formulations (138 VMPs):** Capsules (10mg–225mcg range), oral solutions and suspensions at many fine concentrations (5–300mcg/5ml), oral powder sachets, IV injection preparations for myxoedema coma. The large number of liquid VMPs reflects paediatric/neonatal dosing and patients requiring extemporaneous preparations.

---

## 6. Liothyronine - 27 direct VMPs, expands to 35

The Liothyronine VTM has 27 direct VMPs (tablets, oral solutions, injections for myxoedema coma) and expands to 35 (+8) via the same 8 Levothyroxine + Liothyronine VMPs found from the Levothyroxine direction.

For a T3 monitoring search (rare - liothyronine requires more frequent monitoring than T4), the expansion correctly surfaces patients on combined T3/T4 therapy who are also receiving liothyronine.

---

## 7. Clinical Notes for TSH Monitoring Implementation

**Levothyroxine-only monitoring (the common case):**
- Search: Levothyroxine VTM
- VTM-direct: 146 VMPs - complete for all standard levothyroxine prescriptions
- Combination toggle OFF: no combined T3/T4 patients included
- Combination toggle ON: adds 8 of 12 combination VMPs (+5.5%)

**Including combined T3/T4 patients:**
- Toggle ON adds 8 VMPs via the ISID pivot
- Misses 4 further combination VMPs (the base levothyroxine ISID split)
- For complete coverage of all combined T3/T4 prescriptions, the user would need to **also select the Levothyroxine + Liothyronine VTM directly**

**Liothyronine-only prescriptions (T3 monotherapy - uncommon):**
- A separate Liothyronine VTM selection is needed
- The Levothyroxine VTM pivot does not reach the Liothyronine VTM (different ISIDs)

---

## 8. SQL Used in This Analysis

### Ingredient ISIDs - Levothyroxine and combination VTM

```sql
-- Levothyroxine VTM ISIDs
SELECT i.isid, i.nm AS ingredient, COUNT(DISTINCT v.vpid) AS vmps
FROM   dmd.dbo.vmp            v
JOIN   dmd.dbo.vmp_ingredient vi ON vi.vpid = v.vpid
JOIN   dmd.dbo.ingredient     i  ON i.isid  = vi.isid
WHERE  v.vtmid = 776526008
GROUP BY i.isid, i.nm;

-- Levothyroxine + Liothyronine VTM ISIDs
SELECT i.isid, i.nm AS ingredient, COUNT(DISTINCT v.vpid) AS vmps
FROM   dmd.dbo.vmp            v
JOIN   dmd.dbo.vmp_ingredient vi ON vi.vpid = v.vpid
JOIN   dmd.dbo.ingredient     i  ON i.isid  = vi.isid
WHERE  v.vtmid = 776527004
GROUP BY i.isid, i.nm
ORDER BY vmps DESC;
```

### Pivot result from Levothyroxine

```sql
-- Which combination VTMs does the Levothyroxine pivot find, and how many VMPs?
SELECT vtm2.nm             AS combination_vtm,
       COUNT(DISTINCT v2.vpid) AS vmps
FROM   dmd.dbo.vmp            v
JOIN   dmd.dbo.vmp_ingredient vi  ON vi.vpid    = v.vpid
JOIN   dmd.dbo.vmp_ingredient vi2 ON vi2.isid   = vi.isid
JOIN   dmd.dbo.vmp            v2  ON v2.vpid    = vi2.vpid
JOIN   dmd.dbo.vtm            vtm2 ON vtm2.vtmid = v2.vtmid
WHERE  v.vtmid  = 776526008
  AND  v2.vtmid <> 776526008
GROUP BY vtm2.nm
ORDER BY vmps DESC;
```

### Complete coverage - all three thyroid VTMs

```sql
-- For complete coverage including all combined T3/T4 and T3-only prescriptions:
SELECT DISTINCT v.vpid, v.nm, vtm.nm AS vtm_name, 'VMP' AS level
FROM   dmd.dbo.vmp v
JOIN   dmd.dbo.vtm vtm ON vtm.vtmid = v.vtmid
WHERE  vtm.nm IN (
           'Levothyroxine',
           'Liothyronine',
           'Levothyroxine + Liothyronine'   -- select directly for the 4 base-ISID VMPs
       )
  AND  vtm.invalid = 0;
-- Note: selecting Levothyroxine + Liothyronine VTM directly (with guard)
-- captures all 12 combination VMPs, including the 4 unreachable via ingredient pivot
```
