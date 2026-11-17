# Medication Search - Background and Research Findings

**Date:** June 2026  
**Purpose:** Reference document capturing everything established during investigation into dm+d-based medication search for the Custom Report Builder.

---

## Contents

1. [The dm+d Data Model](#1-the-dmd-data-model)
2. [The Salt Form Problem](#2-the-salt-form-problem)
3. [Why VTM-First Resolves the Salt Problem](#3-why-vtm-first-resolves-the-salt-problem)
4. [The Combination Product Problem](#4-the-combination-product-problem)
5. [The Ingredient Pivot](#5-the-ingredient-pivot)
6. [The Named Combination Guard](#6-the-named-combination-guard)
7. [Empirical Validation](#7-empirical-validation)
8. [Clinical Impact of Missing Combination Products](#8-clinical-impact-of-missing-combination-products)
9. [Comparison with EMIS Web](#9-comparison-with-emis-web)
10. [Known Limitations and Edge Cases](#10-known-limitations-and-edge-cases)
11. [Summary Recommendations](#11-summary-recommendations)

---

## 1. The dm+d Data Model

NHS dm+d (Dictionary of Medicines and Devices) organises prescribable products in a five-level hierarchy:

```
VTM  - Virtual Therapeutic Moiety
  └── VMP  - Virtual Medicinal Product
        └── VMPP - Virtual Medicinal Product Pack
              └── AMP  - Actual Medicinal Product
                    └── AMPP - Actual Medicinal Product Pack
```

| Level | What it represents | Example |
| :-- | :-- | :-- |
| **VTM** | The clinical drug concept - above salt and formulation | Methotrexate |
| **VMP** | A specific generic formulation at a specific strength | Methotrexate 2.5mg tablets |
| **VMPP** | The VMP at a specific pack size | Methotrexate 2.5mg tablets 28 tablet |
| **AMP** | A specific branded product from a specific manufacturer | Methofar 2.5mg tablets (Accord) |
| **AMPP** | The AMP at a specific pack size | Methofar 2.5mg tablets 28 tablet |

In GP clinical systems, prescriptions are typically recorded at VMP or AMP level. Dispensing records in some systems are at AMPP level. Any complete medication search must expand through all four levels below VTM to capture all relevant records.

### The ingredient model

Separately from the VTM–VMP hierarchy, dm+d maintains a many-to-many ingredient relationship:

```
ingredient  (isid, nm)          - substance concepts from SNOMED CT
vmp_ingredient (vpid, isid)     - maps each VMP to its ingredient substance(s)
```

Each VMP has one row in `vmp_ingredient` per active ingredient. A single-substance VMP has one row; a combination VMP has one row per component. The `isid` is a SNOMED CT substance concept ID.

---

## 2. The Salt Form Problem

When a drug exists in multiple salt or ester forms, dm+d assigns each form a distinct ingredient concept. The base substance and its salt forms are different ISIDs:

| Drug | Ingredient | ISID | VMPs linked |
| :-- | :-- | :-- | --: |
| Amoxicillin | Amoxicillin (base) | `372687004` | **0** |
| Amoxicillin | Amoxicillin sodium | `427483001` | 10 |
| Amoxicillin | Amoxicillin trihydrate | `96068000` | 21 |
| Methotrexate | Methotrexate (base) | `387381009` | 61 |
| Methotrexate | Methotrexate sodium | `412247000` | 49 |
| Warfarin | Warfarin (base) | `372756006` | **0** |
| Warfarin | Warfarin sodium | `63167009` | 27 |
| Morphine | Morphine (base) | `373529000` | **0** |
| Morphine | Morphine sulfate | `60886004` | 129 |

**The problem:** The ingredient concept that matches the common drug name - "Amoxicillin", "Warfarin", "Morphine" - typically has zero or very few VMPs linked to it. The prescribable products are registered against the specific salt form. A search that queries `ingredient.nm` directly, and then looks up VMPs via `vmp_ingredient`, will return empty or grossly incomplete results for the most common drug names.

This is not a data quality issue. It is by design - dm+d records the precise chemical entity of each preparation, which is clinically and regulatorily necessary. The problem arises only when a clinician-facing search exposes the ingredient layer directly.

### Scale of the problem

Across all active ingredients in the current dm+d release that have at least one VMP linked to them (3,521 substances), analysis of naming patterns finds approximately **557 confirmed base-salt pairs** - drugs where a common name links to a base ISID with zero or few VMPs, and a salt-form ISID with the actual prescribable products. A further 136 compound modifier variants exist. The problem affects the majority of commonly prescribed drug classes.

---

## 3. Why VTM-First Resolves the Salt Problem

The VTM concept exists precisely to represent the clinical drug entity above salt chemistry. NHS BSA assigns all salt and form variants of a single drug to the same VTM. As a result, traversing **VTM → VMP directly** (via the `vmp.vtmid` column) returns all forms automatically:

| VTM | Direct VMPs | Salt forms included | How |
| :-- | --: | :-- | :-- |
| Amoxicillin | 15 | Amoxicillin sodium (4) + Amoxicillin trihydrate (11) | All under same VTM |
| Methotrexate | 110 | Methotrexate base (61) + Methotrexate sodium (49) | All under same VTM |
| Warfarin | 27 | Warfarin sodium (27) - only form in use | All under same VTM |
| Morphine | 129 | Morphine sulfate (129) - only form in use | All under same VTM |

**The salt problem dissolves at VTM level.** No algorithm is needed to handle salt forms if the search starts from the VTM table rather than the ingredient table.

This is why **the search primitive must be `vtm.nm`**, not `ingredient.nm`. The VTM name is the concept that matches how clinicians think. A clinician types "amoxicillin" and expects all amoxicillin products - the VTM named "Amoxicillin" delivers exactly that in a single join, with no salt-specific logic required.

---

## 4. The Combination Product Problem

VTM-direct search correctly handles salt forms but does not capture products where the drug appears as one component of a named combination. Co-amoxiclav (amoxicillin + clavulanic acid) sits under its own VTM - "Co-amoxiclav" - entirely separate from the "Amoxicillin" VTM. A VTM-direct search for Amoxicillin will never see co-amoxiclav.

This matters clinically. A patient on co-amoxiclav is receiving amoxicillin. A patient on Janumet (sitagliptin + metformin) is receiving metformin. A patient on Inegy (simvastatin + ezetimibe) is receiving simvastatin. If a medication report does not include combination products, patients on those products are invisible to it.

The scale of the problem varies by drug class:

| VTM | VTM-direct VMPs | With combinations | Combination VTMs found |
| :-- | --: | --: | :-- |
| Amoxicillin | 15 | 31 | Co-amoxiclav |
| Metformin | 23 | 45 | Janumet, Xigduo, Synjardy, Komboglyze, Vokanamet, Jentadueto, Eucreas, Vipdomet, Competact, Avandamet |
| Simvastatin | 15 | 21 | Inegy, Cholib, Cholesterol+Simvastatin |
| Amlodipine | 22 | 37 | Exforge, Sevikar, Sevikar HCT, Viacoram |
| Ramipril | 22 | 24 | Triapin (Felodipine + Ramipril) |
| Ezetimibe | 1 | 5 | Inegy, Nustendi |
| Linagliptin | 1 | 5 | Glyxambi, Jentadueto |
| Methotrexate | 110 | 110 | None - no combination products exist |
| Warfarin | 27 | 27 | None - never combined |

For ezetimibe and linagliptin, the VTM-direct count is almost meaningless - the vast majority of real-world prescribing is in combination products. For metformin, missing the combinations means missing nearly half of all patients on the drug.

---

## 5. The Ingredient Pivot

To find combination products without requiring the user to know about or select each combination VTM individually, the algorithm uses the ingredient ISIDs collected from the direct VMPs as a global search key across dm+d.

**Mechanism:**

1. Fetch all VMPs directly under the selected VTM (via `vmp.vtmid`)
2. Collect all distinct `isid` values from those VMPs via `vmp_ingredient`
3. Search the entire `vmp_ingredient` table for any VMP containing any of those ISIDs
4. The results include the original VMPs plus any combination product VMPs that share an ingredient

**Why this works - the shared ISID bridge:**

Every VMP in dm+d, whether single-ingredient or a combination, has its ingredients registered in `vmp_ingredient`. The manufacturers of Janumet, Xigduo and every other metformin combination all used the same ISID (`109083009 | Metformin hydrochloride`) when registering those products with NHS BSA. This is not designed for our algorithm - it is a structural property of dm+d. The ISID acts as a reliable bridge between VTMs.

Example - Sitagliptin 50mg / Metformin 1g tablets (a Janumet VMP):

```
vmp_ingredient rows:
  vpid = 17071811000001108  isid = 109083009  (Metformin hydrochloride)
  vpid = 17071811000001108  isid = 423307000  (Sitagliptin)
```

When we search for ISIDs collected from Metformin VTM VMPs, we find `109083009`, which matches the first row above, bringing the Janumet VMP into scope. The sitagliptin row is also there - it just does not interfere. The same logic works symmetrically: searching from the Sitagliptin VTM would collect ISID `423307000` and also find the same Janumet VMP.

**Visual representation - Metformin:**

```
                    [Metformin VTM]
                          |
                     23 direct VMPs
                  (all use ISID: 109083009
                   Metformin hydrochloride)
                          |
                    pivot: search all dm+d
                    for ISID 109083009
                          |
     ┌────────┬───────────┼──────────┬────────┬──── ...
     |        |           |          |        |
  Sitagliptin Dapagliflozin Empagliflozin Linagliptin  (6 more)
  +Metformin  +Metformin   +Metformin   +Metformin
  (2 VMPs)    (2 VMPs)      (4 VMPs)    (2 VMPs)

Total: 45 VMPs (23 direct + 22 combination across 10 VTMs)
```

---

## 6. The Named Combination Guard

Without a guard, the ingredient pivot over-expands when the selected VTM is itself a named combination product. Two naming conventions require coverage.

### The " + " separator - standard dm+d combination format

Example: a clinician selects "Dithranol + Zinc oxide + Salicylic acid" VTM (16 direct VMPs). Without the guard the algorithm collects the ISIDs for all three ingredients, then pivots globally:

| Ingredient | Total VMPs in dm+d |
| :-- | --: |
| Salicylic acid | 285 |
| Zinc oxide | 91 |
| Dithranol | 71 |

The pivot returns **381 VMPs** - every topical product containing any of those common skin treatment ingredients. The clinician selected a specific three-ingredient combination, not "anything containing salicylic acid". The guard prevents this: if `vtm.nm LIKE '% + %'`, return the 16 VTM-direct VMPs and stop.

### The "Co-" prefix - British pharmacopoeial combination convention

"Co-" is the British pharmacopoeial naming convention for fixed-dose combination products. There are **24 active VTMs** in dm+d that use it: Co-amoxiclav, Co-codamol, Co-careldopa, Co-beneldopa, Co-cyprindiol, Co-dydramol, Co-amilofruse, Co-amilozide, Co-fluampicil and others. Because their VTM names do not contain " + ", an initial " + "-only guard does not protect them.

The failure mode is identical: the algorithm misclassifies the VTM as single-substance, collects ISIDs for common drugs, and pivots globally:

| VTM | Components | Direct VMPs | Without guard | With guard |
| :-- | :-- | --: | --: | --: |
| Co-methiamol | Paracetamol + Methionine | 1 | 161 | **1** |
| Co-flumactone | Spironolactone + Hydroflumethiazide | 2 | 91 | **2** |
| Co-phenotrope | Atropine sulfate + Diphenoxylate | 1 | 46 | **1** |

Co-methiamol is the clearest example: it is a niche preparation (paracetamol + methionine, used as an antidote in paracetamol overdose) with 1 VMP. Without the "Co-" guard, the algorithm collects the paracetamol ISID and returns all 161 paracetamol-containing VMPs across dm+d. Adding `OR vtm.nm LIKE 'Co-%'` returns the correct 1 VMP.

### The complete guard

```sql
IF vtm.nm LIKE '% + %' OR vtm.nm LIKE 'Co-%':
    return VTM-direct VMPs only - no ingredient pivot
```

**Validated against all 3,103 active VTMs in dm+d: no false positives.** The guard correctly classifies 731 VTMs (24%) as named combinations and 2,372 (76%) as single-substance.

| VTM | Guard triggered? | Result |
| :-- | :-- | :-- |
| Lidocaine + Adrenaline | Yes (" + ") | 10 VMPs - lidocaine+adrenaline products only |
| Dithranol + Zinc oxide + Salicylic acid | Yes (" + ") | 16 VMPs - that specific combination only |
| Sacubitril + Valsartan | Yes (" + ") | 5 VMPs - correct |
| Co-amoxiclav | Yes ("Co-") | 16 VMPs - co-amoxiclav products only |
| Co-codamol | Yes ("Co-") | Correct direct VMPs only |
| Co-methiamol | Yes ("Co-") | 1 VMP - correct (not 161) |
| Amoxicillin | No | Pivot runs → finds Co-amoxiclav (+16 VMPs) |
| Metformin | No | Pivot runs → finds all combination diabetes drugs (+22 VMPs) |
| Simvastatin | No | Pivot runs → finds Inegy, Cholib (+6 VMPs) |

**The asymmetry:** The guard only applies when a combination VTM is the **selected input**. Co-amoxiclav and Co-codamol can still appear as expansion *results* when a single-ingredient VTM is the input - the guard on Co-amoxiclav does not prevent amoxicillin's pivot from finding co-amoxiclav VMPs via the shared amoxicillin trihydrate ISID. This is correct: a clinician searching "Amoxicillin" should find co-amoxiclav products; a clinician who explicitly selected "Co-amoxiclav" should get only co-amoxiclav products.

---

## 7. Empirical Validation

### Full dm+d validation - all 3,103 active VTMs

The complete algorithm (VTM-direct + ingredient pivot + named combination guard with both " + " and "Co-" arms) was run against every active VTM in dm+d that has at least one VMP - **3,103 VTMs in total**.

**Summary:**

| Category | Count | % |
| :-- | --: | --: |
| Total VTMs tested | 3,103 | 100% |
| Combination VTMs (guard applied - " + " or "Co-") | 731 | 24% |
| Single-substance VTMs | 2,372 | 76% |
| - Single with combination products found (expansion > 0) | 587 | 25% of single |
| - Single with no combination products (expansion = 0, has ingredient links) | 1,643 | 69% of single |
| - Single with no ingredient links at all | 92 | 4% of single |
| - Single with partial ingredient links (some VMPs missing) | 142 | 6% of single |

**Correct expansions - clinically meaningful single-substance VTMs finding combination products:**

| VTM | Direct | Expanded | Combination products found |
| :-- | --: | --: | :-- |
| Paracetamol | 53 | 161 | All paracetamol-containing combinations (co-codamol, co-dydramol, Migraleve, cold & flu products) |
| Betamethasone | 53 | 118 | Combination steroid topical products |
| Lidocaine | 35 | 100 | Combination local anaesthetics (dental, topical, IV) |
| Naloxone | 8 | 23 | Targinact (oxycodone+naloxone), Suboxone (buprenorphine+naloxone) |
| Dihydrocodeine | 13 | 22 | Combination opioid products (co-dydramol etc.) |
| Norethisterone | 4 | 12 | Combined oral contraceptives |
| Salbutamol | 31 | 39 | Combination inhalers (Combivent, Duolin etc.) |
| Oxycodone | 26 | 31 | Oxycodone+naloxone (Targinact) |
| Naproxen | 19 | 21 | Naproxen+sumatriptan (Treximet) |
| Metformin | 23 | 45 | All combination diabetes drugs (Janumet, Xigduo, Synjardy, Jentadueto and 6 others) |
| Amlodipine | 22 | 37 | Exforge, Sevikar, Sevikar HCT, Viacoram |
| Simvastatin | 15 | 21 | Inegy, Cholib, Cholesterol+Simvastatin |
| Amoxicillin | 15 | 31 | Co-amoxiclav (all strengths/routes) |
| Lamivudine | 5 | 13 | Combivir, Kivexa, Trizivir |
| Tenofovir disoproxil | 5 | 11 | Truvada, Atripla and similar HIV combinations |
| Losartan | 14 | 17 | Losartan+Hydrochlorothiazide (Cozaar-Comp) |
| Ezetimibe | 1 | 5 | Inegy, Nustendi |
| Linagliptin | 1 | 5 | Glyxambi, Jentadueto |
| Ramipril | 22 | 24 | Triapin (Felodipine+Ramipril) |

**Excipient and electrolyte over-expansion (toggle OFF is the correct default):**

The highest expansion values across all 3,103 VTMs belong to pharmaceutical excipients and electrolytes, not therapeutic drugs:

| VTM | Direct | Expanded | Why it expands so far |
| :-- | --: | --: | :-- |
| Glucose | 45 | 384 | IV infusion vehicle in hundreds of combination IV products |
| Sodium chloride | 162 | 451 | Saline vehicle used in virtually every IV preparation |
| Calcium chloride | 16 | 256 | IV electrolyte in many combination infusion fluids |
| Salicylic acid | 81 | 285 | Common topical keratolytic in many combination skin products |
| Potassium chloride | 30 | 220 | IV electrolyte replacement, common in IV fluid combinations |
| Coal tar | 72 | 228 | Multiple coal tar preparations used in combination topicals |
| Sodium bicarbonate | 75 | 199 | IV buffer and antacid component in many combinations |
| Zinc oxide | 7 | 91 | Common topical base in combination skin products |

These are not algorithm failures. A clinician who searches "Glucose" is looking for glucose infusion products; with toggle OFF they get 45 direct VMPs (correct). Toggle ON would return 384 VMPs including every product where glucose is a vehicle or excipient, which may or may not be wanted depending on context. The toggle is the appropriate mechanism.

**Named combination guard - " + " arm:**
731 combination VTMs (24% of all tested) were correctly handled by the guard - all returned VTM-direct VMPs only, with no ingredient expansion. Examples: Sacubitril + Valsartan (5 VMPs), Budesonide + Formoterol (5 VMPs), Olmesartan + Amlodipine (3 VMPs), Simvastatin + Ezetimibe (3 VMPs).

**Named combination guard - "Co-" arm:**
The "Co-" prefix is the British pharmacopoeial convention for naming fixed-dose combination products. There are 24 active VTMs in dm+d that use it - Co-amoxiclav, Co-codamol, Co-careldopa, Co-dydramol, Co-amilofruse and others. These are genuine named combinations, but because their VTM names do not contain " + ", the original guard did not recognise them as combinations and incorrectly applied the ingredient pivot.

The failure mode is identical to the " + " case: the algorithm sees a VTM name with no " + " flag, classifies it as a single-substance VTM, collects its ingredient ISIDs, and pivots globally. The problem is that the collected ISIDs belong to common drugs (paracetamol, spironolactone, atropine) that appear across hundreds of unrelated products.

Taking Co-methiamol as the clearest example:

- Co-methiamol is paracetamol + methionine. It has **1 VMP** - a niche preparation used as an antidote in paracetamol overdose where methionine is co-administered to support glutathione synthesis.
- Without the guard, the algorithm collects the paracetamol ISID from that 1 VMP, then searches all of dm+d for every product containing paracetamol - plain paracetamol tablets, co-codamol, Migraleve, cold and flu products - and returns **161 VMPs**.
- A clinician who selected "Co-methiamol" from search results wanted that single specific preparation, not a broad paracetamol search.

The fix - adding `OR vtm.nm LIKE 'Co-%'` to the guard - returns the correct 1 VMP and stops there, exactly as it does for any " + " named combination.

| VTM | Components | Direct VMPs | Without guard | With guard |
| :-- | :-- | --: | --: | --: |
| Co-methiamol | Paracetamol + Methionine | 1 | 161 | **1** |
| Co-flumactone | Spironolactone + Hydroflumethiazide | 2 | 91 | **2** |
| Co-phenotrope | Atropine sulfate + Diphenoxylate | 1 | 46 | **1** |

**Important:** the guard only applies when a "Co-" VTM is the **selected input**. It does not prevent Co-amoxiclav or Co-codamol from appearing as expansion *results* when searching from a single-ingredient VTM. When a clinician searches "Amoxicillin", the algorithm pivots via the amoxicillin trihydrate ISID and correctly surfaces Co-amoxiclav VMPs - because at that point the input VTM is "Amoxicillin" (no guard triggered), and Co-amoxiclav VMPs happen to share the amoxicillin ingredient. The guard only fires when the user has directly selected the Co-amoxiclav VTM itself.

**Negative cases - VMPs not reachable via ingredient expansion:**

| Category | VTMs affected | Explanation |
| :-- | --: | :-- |
| Homeopathic products | ~80 VTMs | Zero ingredient links by design - homeopathic VMPs have no chemical ingredient registrations in dm+d |
| Vaccines and biologics | COVID-19 vaccine (−44), Normal immunoglobulin (−5), Influenza H1N1 (−1) | Many biologic VMPs have no or incomplete ingredient links in dm+d |
| Sodium hyaluronate | −56 | 59 VMPs but only 3 have ingredient links - likely a dm+d data completeness issue for this substance class |
| Miscellaneous (honey, fish oil, dextranomer, etc.) | ~10 VTMs | Natural products and biologics with no ingredient entries |
| Single-VMP gaps (conventional drugs) | ~50 VTMs including rivaroxaban, semaglutide, memantine, ropinirole, aripiprazole | Each missing exactly 1–3 VMPs due to sporadic ingredient link gaps in dm+d source data |

In all negative cases, VTM-direct search still returns the VMPs correctly - the gap only affects the ingredient pivot step. For conventional prescription drugs, the gaps are small (1–3 VMPs) and reflect dm+d source data quality rather than algorithm failures.

---

## 8. Clinical Impact of Missing Combination Products

The following use cases illustrate why the combination product expansion matters clinically:

**DMARD monitoring - Methotrexate**  
No expansion needed. VTM-direct returns 110 VMPs covering all formulations and both salt forms. No combination products exist.

**Anticoagulant audit - Warfarin**  
No expansion needed. 27 VMPs, all warfarin sodium, complete.

**Statin drug interaction - Simvastatin** (e.g. contraindication with a new antibiotic)  
Without expansion: 15 VMPs. With expansion: 21 VMPs. A patient on Inegy (Simvastatin + Ezetimibe) is receiving simvastatin and is at risk. Missing them is a patient safety failure.

**Renal safety - Ibuprofen in CKD patients**  
Without expansion: 29 VMPs. With expansion: 39 VMPs (+10 ibuprofen+codeine combinations). A patient on ibuprofen+codeine has identical renal risk.

**Antihypertensive audit - Amlodipine**  
Without expansion: 22 VMPs. With expansion: 37 VMPs (+15). A patient on Exforge (Amlodipine + Valsartan) is receiving amlodipine and belongs in a CCB audit.

**Diabetes audit - Metformin**  
Without expansion: 23 VMPs. With expansion: 45 VMPs (+22 across 10 combination VTMs). Every modern SGLT2 inhibitor + metformin and DPP-4 inhibitor + metformin combination is missed without expansion. This represents close to half of real-world metformin prescribing in contemporary GP practice.

**Paracetamol - intent-dependent**  
Without expansion: 53 VMPs (correct for "patients on plain paracetamol").  
With expansion: 161 VMPs (correct for "patients on any paracetamol-containing product" - co-codamol, Migraleve, cold and flu products). Both are correct depending on the clinical question. This is the strongest argument for an explicit user-controlled toggle rather than always-on expansion.

---

## 9. Comparison with EMIS Web

EMIS Web Code Selector provides three search modes for medications:

| Tab | Searches | Salt form problem? | Combination products? |
| :-- | :-- | :-- | :-- |
| **Groups** (default) | EMIS-proprietary curated groupings, updated monthly by Informatics Pharmacists | Solved by curation | Solved by curation |
| **Ingredients** | dm+d active ingredient ISIDs directly | **Yes** - same salt form problem: "Amoxicillin" base returns 0 products | Partial - user must know which ISIDs to select |
| **Approved names** | rINN/BAN name from preparation description | Partially - closer to VTM level but not equivalent | No |

EMIS solves the salt form and combination product problems via the Groups tab, which requires ongoing pharmacist maintenance resource. Their Ingredients tab exposes the same salt form problem that a raw ingredient ISID search would produce - which is almost certainly why Groups is the default.

**What our VTM-first approach provides** is a fourth option that none of the EMIS tabs offer:

- Searches by the drug name the clinician knows (VTM name) - no pharmacist curation required
- Automatically handles salt forms via dm+d structure - free, always up to date
- Optionally captures combination products via the ingredient pivot - no manual maintenance
- The only gap is intentionally separated drug classes (iron, vitamin D) where dm+d itself uses distinct VTMs for clinical reasons

---

## 10. Known Limitations and Edge Cases

### Intentionally separated drug classes

Several drug classes use distinct VTMs for each salt or form, and these separations are clinically intentional. The algorithm correctly does not merge them - doing so would be clinically wrong.

| Drug class | VTMs | Why separated |
| :-- | :-- | :-- |
| Iron | Ferrous sulfate, Ferrous fumarate, Ferric carboxymaltose, Iron sucrose, Ferrous gluconate (separate VTMs for each) | Non-interchangeable; different indications, routes, tolerability profiles |
| Vitamin D | Colecalciferol (D3), Ergocalciferol (D2) - separate VTMs | D2 and D3 are pharmacologically distinct |
| Vitamin B12 | Cyanocobalamin, Hydroxocobalamin - separate VTMs | Different clinical uses (oral supplementation vs IM injection for pernicious anaemia) |
| Valproate | Sodium valproate (35 VMPs), Valproic acid (10 VMPs) - separate VTMs | Distinct pharmaceutical forms; sodium salt dominates oral prescribing, valproic acid used in specific modified-release formulations |
| Lithium | Lithium carbonate (5 VMPs), Lithium citrate (4 VMPs), Lithium chloride (1 VMP) - separate VTMs | Different formulations serving different clinical needs; all used for systemic lithium therapy with narrow therapeutic index monitoring |

For these drugs, a clinician wanting "all iron products" or "all lithium products" must select multiple VTMs. The algorithm cannot infer that these should be grouped - that is a clinical judgement.

**The valproate case is clinically critical.** Sodium valproate and Valproic acid together cover 45 VMPs. A search using only Sodium valproate would miss 10 valproic acid VMPs - 22% of the full valproate prescribing population. This is directly relevant to the **MHRA Valproate Pregnancy Prevention Programme**: practices running valproate safety monitoring (annual risk acknowledgement, childbearing potential review) must capture patients on both forms or the search is materially incomplete.

**Critically, the ingredient pivot algorithm cannot bridge this gap automatically.** The two VTMs use entirely different ingredient ISIDs:

| VTM | Ingredient ISID | Ingredient name | VMPs |
| :-- | :-- | :-- | --: |
| Sodium valproate | `387481005` | Sodium valproate | 35 |
| Valproic acid | `387080000` | Valproic acid | 3 |
| Valproic acid | `5641004` | Valproate semisodium | 7 |

The pivot from Sodium valproate collects ISID `387481005` and searches globally - it finds only the same 35 VMPs. There is no shared ISID that could act as a bridge to Valproic acid products. This is unlike the amoxicillin case (where all salt forms sit under one VTM and share ISIDs through the VMP table) - here the VTMs are genuinely disjoint at the ingredient level.

Note also: within the Valproic acid VTM, there are two distinct ISIDs (valproic acid and valproate semisodium/Depakote). VTM-direct correctly returns all 10 VMPs including both sub-forms. The VTM does its grouping job within its own boundary - it just cannot reach across to Sodium valproate.

Verified against dm+d (June 2026):

| VTM | VMPs | Key products |
| :-- | --: | :-- |
| Sodium valproate | 35 | Epilim tablets/syrup/crushable tablets, Epilim Chrono, Episenta, Epival, generics |
| Valproic acid | 10 | Depakote (semisodium valproate), modified-release capsules |
| **Total** | **45** | Both forms must be selected for complete MHRA monitoring coverage |

**The lithium case is similarly critical.** Lithium carbonate alone covers 5 VMPs. Adding Lithium citrate (4 VMPs) and Lithium chloride (1 VMP) brings the total to 10 VMPs. A lithium monitoring search using only Lithium carbonate misses 50% of the lithium patient population - those prescribed liquid lithium citrate (common for patients who cannot swallow tablets) and specialist lithium chloride preparations. As with valproate, the ISIDs are distinct across the VTMs and the pivot cannot bridge them.

The UX implication for both cases: after a user selects Sodium valproate or Lithium carbonate, the interface should surface the sibling VTMs with a prompt to add them, clearly stating the patient safety consequence of not doing so.

### Products without ingredient links

A small number of VMPs in dm+d have no entries in `vmp_ingredient`:
- **Vaccines and biologics** - many have no or incomplete ingredient registrations
- **Homeopathic products** - have no chemical ingredient data by design
- **Composite packs** - combination starter packs (e.g. "Gabapentin 600mg tablets and 300mg capsules") may lack ingredient links

These products appear in VTM-direct results but do not participate in the ingredient pivot step. For most prescription drug classes this is not a concern.

### Named combination VTMs with common ingredients

The named combination guard (`% + %` and `Co-%` check) prevents over-expansion. Without it, common-ingredient combinations such as "Dithranol + Zinc oxide + Salicylic acid" would pivot via salicylic acid (285 VMPs across hundreds of unrelated topical products), and Co-methiamol (paracetamol + methionine) would expand to 161 VMPs via the paracetamol ISID. The guard covers both the standard " + " separator format and the 24 British pharmacopoeial "Co-" prefix combination VTMs.

### Perindopril

Perindopril has no VTM named "Perindopril" with VMPs linked to it. The prescribable products use salt-specific VTMs: Perindopril erbumine and Perindopril arginine are separate VTMs. A user searching "perindopril" in a VTM search would find those salt-specific VTMs rather than a single parent VTM. This is an unusual case but follows the same logic: the salt-specific VTMs are each complete sets of their respective products.

---

## 11. Summary Recommendations

1. **Search primitive must be VTM name, not ingredient name.** VTM-direct traversal resolves salt forms automatically. Ingredient-level search returns empty results for the most common drug queries.

2. **Combination product expansion should be available but user-controlled.** Always-on expansion would include co-codamol when searching paracetamol, which is wrong for many use cases. An explicit toggle ("include combination products containing this drug") gives clinicians control over intent.

3. **Apply the named combination guard.** When the selected VTM name contains " + ", skip the ingredient pivot. The VTM-direct result is already the correct and complete answer for that selection.

4. **Expand through all four sub-levels.** VMP only is insufficient. A significant proportion of prescriptions in GP systems are coded at AMP or AMPP level. Any complete medication report must traverse VMP → VMPP → AMP → AMPP.

5. **For intentionally separated drug classes (iron, vitamin D, B12), multi-select is the correct UX.** These are not algorithm failures. The user should be able to select multiple VTMs in a single report filter. A drug class grouping concept would be needed to support single-click "all iron products" - this requires editorial curation equivalent to EMIS Groups and is outside the scope of the dm+d structural approach.

6. **Include inactive (invalid) products for historical lookback.** Active-only expansion will miss prescriptions from discontinued VMPs and AMPs. Code lists for monitoring searches should include `invalid = 1` products to support lookback over historical prescription data.
