# Amiodarone and Dronedarone VTM Analysis - dm+d Investigation

**Date:** June 2026  
**Purpose:** Establish how the VTM-first algorithm performs for cardiovascular monitoring searches covering amiodarone and dronedarone, and verify the VMP-to-AMP expansion required for prescription issue matching.

---

## 1. Summary Finding

Amiodarone and Dronedarone are algorithmically clean for VTM-first medication search.

Both drugs have:

- One active VTM.
- One ingredient ISID under the VTM.
- No ingredient-pivot expansion into other VTMs.
- No combination products in dm+d.

The important implementation point is not combination expansion. It is AMP expansion. The VMP set is the clinical scope, but the prescription issue match must use AMPs.

| Drug | VTM | Ingredient ISIDs | Direct VMPs | Expanded VMPs | Extra VMPs | Active AMPs for issue matching | Toggle |
| :-- | :-- | --: | --: | --: | --: | --: | :-- |
| Amiodarone | Single VTM | 1 | 51 | 51 | 0 | 124 | Off / hidden |
| Dronedarone | Single VTM | 1 | 1 | 1 | 0 | 12 | Off / hidden |
| **Total** | | **2** | **52** | **52** | **0** | **136** | |

This means a clinician can select one VTM for each monitoring drug. The resolver then expands:

`VTM -> VMP clinical scope -> AMP prescription match scope`

No VMPP or AMPP expansion is required for prescription issue matching in our system.

---

## 2. Monitoring Use Case

These are the Ardens examples being modelled:

| Search | Monitoring requirement |
| :-- | :-- |
| `On Amiodarone` | No U&E, LFT, or TFT in the last 6 months |
| `On Dronedarone` | No U&E or LFT in the last 1 year |

The drug selection is simple, but the monitoring rule is drug-specific:

- Amiodarone requires U&E, LFT, and TFT within 6 months.
- Dronedarone requires U&E and LFT within 1 year.

So these should not be treated as one generic "antiarrhythmic monitoring" rule. The medication cohort resolver should identify patients on each drug; the monitoring layer should attach the correct test set and interval.

---

## 3. Ingredient ISID Analysis

| VTM | Ingredient ISID | Ingredient name | Direct VMPs | Active AMPs |
| :-- | :-- | :-- | --: | --: |
| Amiodarone | `52574003` | Amiodarone hydrochloride | 51 | 124 |
| Dronedarone | `703121007` | Dronedarone hydrochloride | 1 | 12 |

Both are straightforward salt-form cases. The clinician sees `Amiodarone` or `Dronedarone`; dm+d stores the VMP ingredient as the hydrochloride salt. VTM-direct traversal hides that chemistry from the user while still returning the complete product set.

The ingredient pivot finds no additional VTMs for either ISID. This confirms that neither drug appears as a component of a fixed-dose combination product in dm+d.

---

## 4. VMP and AMP Expansion

### 4.1 Formulation summary

| Drug | Formulation group | VMPs | Active AMPs |
| :-- | :-- | --: | --: |
| Amiodarone | Tablets | 2 | 67 |
| Amiodarone | Oral solution | 23 | 23 |
| Amiodarone | Oral suspension | 23 | 23 |
| Amiodarone | Oral powder sachet | 1 | 1 |
| Amiodarone | Injection | 2 | 10 |
| Dronedarone | Tablets | 1 | 12 |

Amiodarone has many VMPs because dm+d includes numerous oral liquid specials at different concentrations. Most of those liquid VMPs have one active AMP each. The standard tablet VMPs carry the largest AMP expansion:

| VMP | Active AMPs |
| :-- | --: |
| Amiodarone 100mg tablets | 31 |
| Amiodarone 200mg tablets | 36 |
| Amiodarone 150mg/3ml solution for injection ampoules | 5 |
| Amiodarone 300mg/10ml solution for injection pre-filled syringes | 5 |
| Dronedarone 400mg tablets | 12 |

This is the concrete reason that VMP-only wireframes are not enough for execution. `Amiodarone` looks like 51 VMPs clinically, but the prescription issue table must be matched against 124 AMPs.

### 4.2 Amiodarone oral liquids

Amiodarone includes 46 oral liquid VMPs:

- 23 oral solutions.
- 23 oral suspensions.

They cover concentrations from 5mg/5ml up to 500mg/5ml, including intermediate specials such as 22mg/5ml, 31.25mg/5ml, 65mg/5ml, 80mg/5ml, and 85mg/5ml.

These are valid prescribable products and should be included in a medication monitoring cohort. They are exactly the type of product that would be missed if the implementation used only a small hand-written list of standard tablet products.

---

## 5. Drug-by-Drug Analysis

### Amiodarone - 51 VMPs, 124 AMPs

Amiodarone is one active VTM:

| Property | Value |
| :-- | :-- |
| VTM id | `774551007` |
| VTM name | Amiodarone |
| Ingredient | `52574003 | Amiodarone hydrochloride` |
| Direct VMPs | 51 |
| Expanded VMPs | 51 |
| Active AMPs | 124 |
| Extra VMPs from ingredient pivot | 0 |

VTM-direct traversal captures:

- Standard oral tablets: 100mg and 200mg.
- Oral solution specials.
- Oral suspension specials.
- One oral powder sachet VMP.
- IV injection ampoules and pre-filled syringes.

**Monitoring note:** Ardens monitoring for amiodarone checks U&E, LFT, and TFT within 6 months. The medication resolver should include the full Amiodarone VTM scope, then expand to AMPs for issue matching.

**Route note:** Amiodarone includes 49 oral VMPs and 2 IV VMPs. Do not remove IV products in the generic resolver. If a particular monitoring report should only include long-term primary-care oral therapy, that decision belongs in the report rule layer, using prescribing status, repeat issue, recency, route, or care ownership. It should not be hidden inside VTM expansion.

### Dronedarone - 1 VMP, 12 AMPs

Dronedarone is one active VTM:

| Property | Value |
| :-- | :-- |
| VTM id | `775703009` |
| VTM name | Dronedarone |
| Ingredient | `703121007 | Dronedarone hydrochloride` |
| Direct VMPs | 1 |
| Expanded VMPs | 1 |
| Active AMPs | 12 |
| Extra VMPs from ingredient pivot | 0 |

The complete VMP set is:

| VMP | Active AMPs |
| :-- | --: |
| Dronedarone 400mg tablets | 12 |

**Monitoring note:** Ardens monitoring for dronedarone checks U&E and LFT within 1 year. There is no combination-product decision and no salt-form decision for the user.

---

## 6. Comparison with DMARDs

| Property | Amiodarone / Dronedarone | DMARDs |
| :-- | :-- | :-- |
| Multiple VTMs needed? | No, one VTM per drug | No, one VTM per drug for the analysed DMARDs |
| Ingredient pivot adds products? | No | No |
| Combination toggle needed? | No | No |
| Main implementation risk | Forgetting AMP expansion | Ciclosporin ophthalmic false positives plus AMP expansion |
| Monitoring complexity | Different test set and interval per drug | Different monitoring intervals and test sets by DMARD |

This is a cleaner class than the DMARD examples. There is no ciclosporin-style route problem where eye preparations sit under the same VTM as systemic products. The only route nuance is Amiodarone IV, which is best handled by issue status and care ownership rather than by changing the core resolver.

---

## 7. Implementation Recommendation

For these Ardens-style cardiovascular monitoring searches:

1. Search and select the VTM.
2. Resolve direct VMPs.
3. Check ingredient expansion, but expect no extra products.
4. Hide or disable the combination toggle.
5. Expand the final VMP set to AMPs.
6. Match prescription issues against AMPs.
7. Apply the monitoring rule separately:
   - Amiodarone: U&E, LFT, TFT within 6 months.
   - Dronedarone: U&E, LFT within 1 year.

The saved definition should preserve both:

- Clinical scope: VTM and VMPs.
- Execution scope: AMPs.

This lets the UI explain the selection at the clinical level while the report runner matches the data level actually stored on prescription issues.

---

## 8. SQL Used in This Analysis

All queries were run against `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release (`nhsbsa_dmd_6.0.0_20260601000001`).

### 8.1 VTM lookup

```sql
SELECT vtmid, nm, invalid
FROM   dbo.vtm
WHERE  nm IN ('Amiodarone', 'Dronedarone')
   OR  nm LIKE '%Amiodarone%'
   OR  nm LIKE '%Dronedarone%'
ORDER BY nm;
```

### 8.2 Resolver summary

```sql
WITH target_vtms AS (
    SELECT vtmid, nm
    FROM dbo.vtm
    WHERE nm IN ('Amiodarone', 'Dronedarone')
      AND invalid = 0
),
direct_vmps AS (
    SELECT t.nm AS vtm_name, t.vtmid, v.vpid, v.nm AS vmp_name, v.pres_f
    FROM target_vtms t
    JOIN dbo.vmp v ON v.vtmid = t.vtmid
    WHERE v.invalid = 0
),
ingredients AS (
    SELECT d.vtm_name, d.vtmid, vi.isid, i.nm AS ingredient_name,
           COUNT(DISTINCT d.vpid) AS direct_vmp_count
    FROM direct_vmps d
    JOIN dbo.vmp_ingredient vi ON vi.vpid = d.vpid
    JOIN dbo.ingredient i ON i.isid = vi.isid
    GROUP BY d.vtm_name, d.vtmid, vi.isid, i.nm
),
expanded_vmps AS (
    SELECT DISTINCT ing.vtm_name AS input_vtm_name, ing.vtmid AS input_vtmid,
           v.vpid, v.nm AS vmp_name, v.vtmid AS matched_vtmid,
           mv.nm AS matched_vtm_name
    FROM ingredients ing
    JOIN dbo.vmp_ingredient vi ON vi.isid = ing.isid
    JOIN dbo.vmp v ON v.vpid = vi.vpid AND v.invalid = 0
    JOIN dbo.vtm mv ON mv.vtmid = v.vtmid
)
SELECT d.vtm_name,
       COUNT(DISTINCT d.vpid) AS direct_vmps,
       COUNT(DISTINCT e.vpid) AS expanded_vmps,
       COUNT(DISTINCT CASE WHEN e.input_vtmid <> e.matched_vtmid THEN e.vpid END) AS extra_vmps,
       COUNT(DISTINCT a.apid) AS direct_amps,
       COUNT(DISTINCT ae.apid) AS expanded_amps
FROM direct_vmps d
JOIN expanded_vmps e ON e.input_vtmid = d.vtmid
LEFT JOIN dbo.amp a ON a.vpid = d.vpid AND a.invalid = 0
LEFT JOIN dbo.amp ae ON ae.vpid = e.vpid AND ae.invalid = 0
GROUP BY d.vtm_name
ORDER BY d.vtm_name;
```

### 8.3 Ingredient ISIDs

```sql
WITH target_vtms AS (
    SELECT vtmid, nm
    FROM dbo.vtm
    WHERE nm IN ('Amiodarone', 'Dronedarone')
      AND invalid = 0
),
direct_vmps AS (
    SELECT t.nm AS vtm_name, t.vtmid, v.vpid, v.nm AS vmp_name, v.pres_f
    FROM target_vtms t
    JOIN dbo.vmp v ON v.vtmid = t.vtmid
    WHERE v.invalid = 0
)
SELECT d.vtm_name, vi.isid, i.nm AS ingredient_name,
       COUNT(DISTINCT d.vpid) AS direct_vmp_count,
       COUNT(DISTINCT a.apid) AS amp_count
FROM direct_vmps d
JOIN dbo.vmp_ingredient vi ON vi.vpid = d.vpid
JOIN dbo.ingredient i ON i.isid = vi.isid
LEFT JOIN dbo.amp a ON a.vpid = d.vpid AND a.invalid = 0
GROUP BY d.vtm_name, vi.isid, i.nm
ORDER BY d.vtm_name, i.nm;
```

### 8.4 Matched VTMs after ingredient pivot

```sql
WITH target_vtms AS (
    SELECT vtmid, nm
    FROM dbo.vtm
    WHERE nm IN ('Amiodarone', 'Dronedarone')
      AND invalid = 0
),
direct_vmps AS (
    SELECT t.nm AS input_vtm_name, t.vtmid AS input_vtmid,
           v.vpid, v.nm AS vmp_name, v.pres_f
    FROM target_vtms t
    JOIN dbo.vmp v ON v.vtmid = t.vtmid
    WHERE v.invalid = 0
),
ingredients AS (
    SELECT DISTINCT d.input_vtm_name, d.input_vtmid, vi.isid
    FROM direct_vmps d
    JOIN dbo.vmp_ingredient vi ON vi.vpid = d.vpid
),
expanded_vmps AS (
    SELECT DISTINCT ing.input_vtm_name, ing.input_vtmid,
           v.vpid, v.nm AS vmp_name,
           v.vtmid AS matched_vtmid,
           mv.nm AS matched_vtm_name
    FROM ingredients ing
    JOIN dbo.vmp_ingredient vi ON vi.isid = ing.isid
    JOIN dbo.vmp v ON v.vpid = vi.vpid AND v.invalid = 0
    JOIN dbo.vtm mv ON mv.vtmid = v.vtmid
)
SELECT e.input_vtm_name, e.matched_vtmid, e.matched_vtm_name,
       COUNT(DISTINCT e.vpid) AS vmp_count,
       COUNT(DISTINCT CASE WHEN e.input_vtmid <> e.matched_vtmid THEN e.vpid END) AS extra_vmp_count,
       COUNT(DISTINCT a.apid) AS amp_count
FROM expanded_vmps e
LEFT JOIN dbo.amp a ON a.vpid = e.vpid AND a.invalid = 0
GROUP BY e.input_vtm_name, e.matched_vtmid, e.matched_vtm_name
ORDER BY e.input_vtm_name, e.matched_vtm_name;
```

### 8.5 Formulation and AMP counts

```sql
WITH direct AS (
    SELECT t.nm AS vtm_name, v.vpid, v.nm AS vmp_name, v.pres_f,
           CASE
             WHEN v.nm LIKE '%tablets%' THEN 'Tablets'
             WHEN v.nm LIKE '%solution for injection%' THEN 'Injection'
             WHEN v.nm LIKE '%oral solution%' THEN 'Oral solution'
             WHEN v.nm LIKE '%oral suspension%' THEN 'Oral suspension'
             WHEN v.nm LIKE '%oral powder%' THEN 'Oral powder sachet'
             ELSE 'Other'
           END AS formulation_group
    FROM dbo.vtm t
    JOIN dbo.vmp v ON v.vtmid = t.vtmid AND v.invalid = 0
    WHERE t.nm IN ('Amiodarone', 'Dronedarone')
),
amp_counts AS (
    SELECT vpid, COUNT(DISTINCT apid) AS active_amp_count
    FROM dbo.amp
    WHERE invalid = 0
    GROUP BY vpid
)
SELECT d.vtm_name, d.formulation_group,
       COUNT(DISTINCT d.vpid) AS vmp_count,
       SUM(COALESCE(ac.active_amp_count, 0)) AS amp_count
FROM direct d
LEFT JOIN amp_counts ac ON ac.vpid = d.vpid
GROUP BY d.vtm_name, d.formulation_group
ORDER BY d.vtm_name, d.formulation_group;
```
