# Lithium VTM Analysis - dm+d Investigation

**Date:** June 2026  
**Purpose:** Establish whether the VTM-first ingredient pivot algorithm can automatically capture all lithium prescriptions, or whether multi-VTM selection is required.

---

## 1. Lithium VTMs in dm+d

Five VTMs exist for lithium in the current dm+d release:

| VTM | VTM ID | Status | Relevant? |
| :-- | :-- | :-- | :-- |
| Lithium carbonate | `776555000` | Active | Yes - systemic oral therapy |
| Lithium citrate | `776556004` | Active | Yes - systemic oral therapy (liquid) |
| Lithium chloride | `24662111000001101` | Active | Yes - systemic injection (specialist) |
| Lithium succinate + Zinc sulfate | `776558003` | Active | No - topical skin preparation, guarded by " + " |
| Lithium | `321719003` | **Invalid (retired)** | No - historical, no active VMPs |

The three active systemic VTMs are the relevant set for lithium monitoring.

---

## 2. Ingredient ISID Analysis

Each VTM uses a completely distinct ingredient ISID. There is no shared ISID between any of the three systemic VTMs:

| VTM | Ingredient ISID | Ingredient name | VMPs |
| :-- | :-- | :-- | --: |
| Lithium carbonate | `387095003` | Lithium carbonate | 5 |
| Lithium citrate | `387098001` | Lithium citrate | 4 |
| Lithium chloride | `54835003` | Lithium chloride | 1 |
| **Total** | | | **10** |

---

## 3. Algorithm Pivot Test

Running the VTM-first ingredient expansion algorithm from Lithium carbonate:

**Step 1 - VTM-direct:** 5 VMPs returned (all Lithium carbonate).

**Step 2 - Ingredient pivot:** collects ISID `387095003 | Lithium carbonate`, searches globally across dm+d → finds **only the same 5 VMPs**. The Lithium citrate and Lithium chloride ISIDs are completely absent from the result.

**Conclusion: the algorithm cannot bridge across the three lithium VTMs.** The ISIDs are genuinely different chemical species. The pivot from Lithium carbonate will never retrieve a single Lithium citrate or Lithium chloride VMP.

This is identical to the valproate finding: the separation is not a gap in the algorithm but a structural property of dm+d. The three salts are registered as distinct pharmaceutical ingredients.

---

## 4. Product List by VTM

### Lithium carbonate - 5 VMPs

| VMP | Notes |
| :-- | :-- |
| Lithium carbonate 250mg tablets | Camcolit - standard tablet, immediate-release |
| Lithium carbonate 200mg modified-release tablets | Priadel - low-strength MR, used for dose titration |
| Lithium carbonate 400mg modified-release tablets | Priadel - standard maintenance dose |
| Lithium carbonate 450mg modified-release tablets | Liskonum - alternative MR tablet |
| Lithium carbonate 200mg/5ml oral suspension | Liquid formulation of carbonate salt |

### Lithium citrate - 4 VMPs

| VMP | Notes |
| :-- | :-- |
| Lithium citrate 509mg/5ml oral solution | Priadel Liquid (standard strength) |
| Lithium citrate 1.018g/5ml oral solution | Priadel Liquid (double strength) |
| Lithium citrate 520mg/5ml oral solution sugar free | Sugar-free liquid for diabetic/specific patients |
| Lithium citrate 564mg modified-release tablets | Li-liquid modified-release tablet form |

### Lithium chloride - 1 VMP

| VMP | Notes |
| :-- | :-- |
| Lithium chloride 1.5mmol/10ml solution for injection ampoules | Specialist/hospital use - rarely seen in GP prescribing but present in dm+d |

---

## 5. Clinical Significance

### Who is on Lithium citrate?

Priadel Liquid (Lithium citrate) is prescribed where patients cannot swallow tablets - a common clinical scenario in older adults, those with swallowing difficulties, and patients requiring very precise dose titration. It is a standard and widely used preparation in secondary care psychiatry, with prescriptions frequently appearing in GP records after initiation in mental health services.

**A lithium monitoring search using only Lithium carbonate would miss every Priadel Liquid prescription.** These patients would not receive monitoring reminders for serum lithium levels, U&E, TFT, or weight - despite the same clinical risk as carbonate-treated patients.

### Who is on Lithium chloride?

Lithium chloride injection is used in specialist contexts (historically in some renal replacement therapy protocols and research settings). It is unlikely to represent significant GP prescribing volume but is present in dm+d and theoretically reachable via a monitoring search.

### Missing patient calculation

| Search scope | VMPs covered | Patients potentially missed |
| :-- | --: | :-- |
| Lithium carbonate only | 5 | All patients on Priadel Liquid, Li-liquid, and lithium chloride |
| Lithium carbonate + Lithium citrate | 9 | Only lithium chloride injection patients |
| All three VTMs | **10** | None - complete |

Using Lithium carbonate alone misses **50% of the VMP population** (5 of 10 VMPs). In real-world prescribing volumes, the carbonate forms dominate, but the 50% figure represents VMP coverage - and any missed VMP could represent patients who fall through monitoring.

---

## 6. Why the Algorithm Cannot Fix This

The three lithium salts are chemically distinct entities:

- **Lithium carbonate** (Li₂CO₃): the standard oral solid-dose salt
- **Lithium citrate** (Li₃C₆H₅O₇): the citrate salt used in liquid formulations
- **Lithium chloride** (LiCl): the chloride salt used in injection

In dm+d, each has a unique SNOMED substance concept (ingredient ISID). There is no shared ISID that could act as a bridge. The ingredient pivot algorithm works by finding shared ISIDs across VMPs - if the ISIDs have no overlap, no pivot is possible.

This is fundamentally different from the amoxicillin case:
- **Amoxicillin:** sodium and trihydrate forms sit under one VTM → VTM-direct captures both automatically
- **Lithium:** each salt has its own VTM and its own ISID → no automatic aggregation is possible

The only technically conceivable workaround would be a higher-level "Lithium (any salt)" concept, but no such VTM exists in dm+d (the retired "Lithium" VTM `321719003` has no active VMPs and should not be used).

---

## 7. Comparison with Sodium Valproate

| Property | Valproate | Lithium |
| :-- | :-- | :-- |
| Number of relevant VTMs | 2 | 3 |
| Total VMPs across all forms | 45 | 10 |
| Algorithm bridges them? | No | No |
| % missed if primary VTM only | 22% (valproic acid) | 50% (citrate + chloride) |
| Safety programme relevance | MHRA Valproate Pregnancy Prevention Programme | Narrow therapeutic index - serum level monitoring mandatory |
| Named combination guard needed? | No | No (Lithium succinate + Zinc sulfate is guarded, but unrelated) |

Both cases require the UI to surface sibling VTMs and prompt multi-selection. The lithium case has higher VMP-level miss rate (50%) but the valproate case has a specific named MHRA safety programme that makes the consequence of missing patients more formally defined.

---

## 8. UX Recommendation

When a user selects any of the three systemic lithium VTMs, the medication selection card should:

1. Show the product count for the selected VTM (e.g. Lithium carbonate: 5 products)
2. Display a blue info panel: **"For complete lithium monitoring, also add the other salt forms"**
3. Surface sibling chips: `+ Lithium citrate  4 products` and `+ Lithium chloride  1 product`
4. After all three are added, show the combined summary: **10 products across 3 medicines**
5. Not show a combination toggle - none of the three VTMs have combination products

The sibling prompt should appear regardless of which lithium VTM the user selects first. The UI should be aware that Lithium succinate + Zinc sulfate is unrelated (topical dermatology) and must not be suggested as a sibling.
