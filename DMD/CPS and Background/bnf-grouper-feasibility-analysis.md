# BNF Grouper Feasibility Analysis

**Date:** 2026-06-27  
**Database tested:** `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release (`nhsbsa_dmd_6.0.0_20260601000001`)  
**Purpose:** Establish whether BNF codes in dm+d supplementary data can reduce or eliminate the need for expert pharmacist curation of medication monitoring groups, as described in [curated-medication-groups-requirements-analysis.md](curated-medication-groups-requirements-analysis.md).

---

## 1. Executive Summary

BNF codes in dm+d are real, tested, and populated for **72.4% of active VMPs** (17,334 of 23,950). For the 15 MVP monitoring groups identified in the requirements analysis, BNF codes can **reduce the curation burden significantly** by generating a small, correctly bounded candidate list of VTMs for each group. However, BNF codes **cannot eliminate pharmacist review entirely**. For six of the fifteen groups the BNF section is too broad and VTM-level filtering is still required; for two groups the clinical concept spans multiple BNF chapters; and VMP-level clinical exclusions remain irreducibly human judgements.

The practical conclusion is that BNF codes should become the **automated candidate-generation mechanism** in the curation workflow described in the requirements analysis, replacing a manual scan of all 3,098 active VTMs with a focused review of typically 5 to 30 VTMs per group. The pharmacist review step is reduced but not removed.

---

## 2. The BNF Code in dm+d Supplementary Data

### 2.1 What is stored

The `dmd_bnf` table stores one or more BNF codes per VMP (Virtual Medical Product). Each code is exactly 8 characters in the format `CCSSPPZZ`:

| Positions | Meaning | Example |
| :-- | :-- | :-- |
| CC | BNF chapter | `02` = Cardiovascular |
| SS | BNF section | `08` = Anticoagulants |
| PP | BNF sub-section / paragraph | `02` = Oral anticoagulants |
| ZZ | Sub-paragraph | `00` = default |

The granularity is therefore equivalent to BNF paragraph level (e.g., BNF 2.8.2 = code `02080200`).

### 2.2 Coverage in the June 2026 release

| Metric | Count |
| :-- | --: |
| Active VMPs | 23,950 |
| Active VMPs with at least one BNF code | 17,334 |
| Active VMPs with no BNF code | 6,616 |
| BNF coverage rate | 72.4% |

### 2.3 Why 27.6% of VMPs have no BNF code

The gap does not reflect a data quality problem. It reflects a fundamental difference in scope between dm+d and the BNF.

**dm+d is broader than the BNF.** dm+d is the UK master catalogue of all licensed medicines, approved devices, and certain unlicensed special preparations. The BNF covers medicines that are prescribable or commonly used in clinical practice and carries a standard chapter/section classification for each. Some products in dm+d have no BNF classification because they sit outside the BNF's scope.

Route data for the 6,616 unclassified VMPs shows the pattern clearly:

| Primary route | VMPs without BNF code | % of unclassified |
| :-- | --: | --: |
| No route recorded | 3,210 | 48.5% |
| Intravenous | 1,290 | 19.5% |
| Oral | 892 | 13.5% |
| Cutaneous | 293 | 4.4% |
| Route not applicable | 227 | 3.4% |
| All other routes | 704 | 10.6% |

The three main reasons products lack a BNF code are:

**1. Radiopharmaceuticals and nuclear medicine products** account for most of the "no route recorded" category. Sodium iodide [I-131] alone contributes 398 VMPs. These are not classified within the standard BNF chapter structure and are administered in specialist nuclear medicine departments. They are irrelevant to primary care monitoring.

**2. Hospital-only intravenous preparations** account for the 1,290 IV VMPs. These include cytotoxic chemotherapy (carboplatin, paclitaxel, fluorouracil, docetaxel, oxaliplatin), biologic IV infusions (trastuzumab, rituximab), contrast media (ioversol, iopamidol, iomeprol), and critical-care IV drugs (noradrenaline, vancomycin, morphine IV, bupivacaine). These are prescribed and administered entirely in secondary care under protocols and do not appear in the BNF's prescribing sections.

**3. Oral specials and unlicensed preparations** account for most of the 892 oral VMPs. These are bespoke manufactured or imported unlicensed formulations (often concentration-adjusted liquids for children or patients unable to swallow). They may have no standard BNF classification because they are extemporaneous rather than licensed products, or because the dm+d record was created for a specific special-order product that pre-dates or post-dates BNF listing. For primary care monitoring purposes the clinically important oral forms of every key monitoring drug (lithium, valproate, warfarin, methotrexate, prednisolone, etc.) all have BNF codes; the unlicensed oral specials that lack codes are niche formulations rarely encountered in routine monitoring searches.

**Practical implication for the MVP groups:** All 15 MVP monitoring drug groups have near-complete BNF coverage. The only meaningful gaps found on direct query are: 8 methotrexate VMPs (high-dose injection formulations without BNF codes), 3 hydroxocobalamin VMPs (cyanide antidote large-volume infusions), 1 lithium chloride VMP (IV electrolyte), and isolated single-VMP gaps for dexamethasone and ergocalciferol — none of which are relevant to primary care monitoring searches. See section 4 for detail.

All key primary care monitoring drugs — lithium, valproate, warfarin, DOACs, methotrexate, hydroxychloroquine, levothyroxine, prednisolone, metformin, oral iron, and vitamin D — have near-complete BNF coverage.

---

## 3. Coverage Analysis for All 15 MVP Groups

The following table reports the results of direct SQL queries against the `dmd_bnf`, `vmp`, and `vtm` tables using the corrected 8-character BNF codes.

| Clinical group | BNF code | VMPs | VTMs | Verdict |
| :-- | :-- | --: | --: | :-- |
| ACE inhibitors | `02050501` | 234 | 23 | ✓ Clean, dedicated section |
| ARBs | `02050502` | 95 | 22 | ✓ Clean, but see note |
| Oral anticoagulants (all) | `02080200` | 59 | 10 | ⚠ Warfarin and DOACs merged |
| DMARDs (conventional + biologic) | `10010300` | 181 | 23 | ⚠ Misses azathioprine, ciclosporin, mycophenolate |
| Lithium (all salts) | `04020300` | 16 | 4 | ✓ Clean, all lithium salts present |
| Valproate | `04080100` | 640 | 32 | ✗ Entire antiepileptic section — too broad |
| Amiodarone and dronedarone | `02030200` | 178 | 13 | ✗ Entire antiarrhythmic section — too broad |
| Levothyroxine and thyroid | `06020100` | 181 | 4 | ✓ Clean thyroid section |
| Metformin and diabetes combos | `06010200` | 172 | 44 | ✗ All oral antidiabetics — too broad |
| Antipsychotics | `04020100` | 313 | 33 | ⚠ Broad class — clinical boundary needed |
| Systemic glucocorticoids | `06030200` | 184 | 11 | ✓ Correctly separated from inhaled and topical |
| Oral iron | `09010101` | 66 | 14 | ✓ Clean, precisely separated from parenteral |
| Parenteral iron | `09010102` | 11 | 6 | ✓ Clean, precisely separated from oral |
| Vitamin B12 | `09010200` | 71 | 5 | ⚠ Also contains folic acid (44 VMPs) |
| Vitamin D | `09060400` | 216 | 12 | ✓ Clean vitamin D section |

**Verdicts:**
- ✓ = BNF code generates a correctly bounded candidate list; pharmacist reviews to confirm, not to discover
- ⚠ = BNF code generates the right territory but contains additional VTMs that need explicit exclusion
- ✗ = BNF section is far too broad; BNF is useful only as a starting filter, and VTM selection is mandatory

---

## 4. Detailed Group-by-Group Findings

### 4.1 ACE inhibitors — BNF `02050501` ✓

BNF 2.5.5.1 maps precisely to ACE inhibitors. The 23 VTMs include:

- All established ACE inhibitors: captopril, enalapril, lisinopril, ramipril, perindopril (all salt forms), fosinopril, quinapril, cilazapril, imidapril, moexipril, trandolapril.
- Fixed-dose combinations: enalapril + hydrochlorothiazide, lisinopril + hydrochlorothiazide, ramipril + felodipine, perindopril + amlodipine, perindopril + indapamide, verapamil + trandolapril, quinapril + hydrochlorothiazide.

No non-ACE drugs appear in this code. A pharmacist reviewing the 23-VTM list for a monitoring group needs only to decide whether to include or exclude specific combinations — a small task.

**BNF alone is sufficient to generate the candidate list. Pharmacist decides scope policy (include/exclude combinations).**

### 4.2 ARBs — BNF `02050502` ✓ with note

BNF 2.5.5.2 contains 22 VTMs including all standard ARBs (candesartan, irbesartan, losartan, olmesartan, telmisartan, valsartan, azilsartan, eprosartan) and their fixed-dose combinations.

One clinical judgment is required: `Sacubitril + Valsartan` (Entresto) is mapped to this BNF code. Sacubitril+Valsartan is an ARNI (angiotensin receptor-neprilysin inhibitor), not a pure ARB. Whether it belongs in an "ARBs" renal monitoring group is a clinical decision that BNF cannot resolve. A pharmacist familiar with the drug's monitoring requirements would decide in minutes.

**BNF alone generates the correct candidate list. One clinical boundary decision required for sacubitril+valsartan.**

### 4.3 Oral anticoagulants / DOACs — BNF `02080200` ⚠

BNF 2.8.2 contains 10 VTMs: warfarin (26 VMPs), apixaban (3), rivaroxaban (10), dabigatran (9), edoxaban (3), acenocoumarol (1), phenindione (3), phenprocoumon (1), coumarin (1), and pentosan polysulfate sodium (2).

This BNF code correctly excludes parenteral anticoagulants (heparin, LMWH — those are in `02080100`). However, it cannot separate:

- "All oral anticoagulants" from "DOACs only" from "Warfarin only"
- Pentosan polysulfate sodium (used for bladder pain syndrome — unusual anticoagulant inclusion)

The BNF code narrows the field from 23,950 VMPs to 59 VMPs across 10 known VTMs. A pharmacist then takes approximately 5 minutes to specify that "DOACs only" = apixaban, rivaroxaban, dabigatran, edoxaban.

**BNF generates the right territory. VTM-level inclusion decisions required to form sub-groups.**

### 4.4 DMARDs — BNF `10010300` ⚠ multi-chapter problem

BNF 10.1.3 maps correctly to the DMARD section (23 VTMs: methotrexate, hydroxychloroquine, leflunomide, penicillamine, sulfasalazine, gold salts, plus all approved biologics and JAK inhibitors).

However, three drugs commonly included in a clinical "DMARDs and Immunosuppressants" monitoring group are in different BNF chapters:

| Drug | BNF code | Reason for separate chapter |
| :-- | :-- | :-- |
| Azathioprine | `08020100` | BNF 8.2.1 — cytotoxic immunosuppressants (transplant/oncology chapter) |
| Mycophenolate mofetil | `08020100` | BNF 8.2.1 — same reason |
| Ciclosporin (systemic) | `08020200` | BNF 8.2.2 — other immunosuppressants |

Separately, ciclosporin eye drops for dry eye disease are mapped to `11040200` (BNF 11.4.2 — ophthalmic anti-inflammatory). This means that a BNF-based query for `08020200` already provides the separation between systemic ciclosporin and ophthalmic ciclosporin that the requirements analysis flagged as a manual curation challenge. **The feared ciclosporin/eye-drops problem is already solved by BNF codes.**

For the broader group, a pharmacist must explicitly add the BNF 8.2.x VTMs to the BNF 10.1.3 core list.

**BNF 10010300 is the correct core. Pharmacist adds 3 known VTMs from BNF 8.2.x. Ciclosporin route separation is free.**

### 4.5 Lithium — BNF `04020300` ✓

BNF 4.2.3 maps cleanly to all lithium products. The 16 VMPs cover lithium carbonate (5 VMPs), lithium citrate (4 VMPs), and other lithium salts.

One gap was found: `Lithium chloride 1.5mmol/10ml solution for injection` has no BNF code at all. This is an IV electrolyte product, not a standard oral lithium therapy product, but it is flagged for completeness. A BNF-only query would correctly retrieve all 15 oral and modified-release lithium VMPs and miss only this one IV formulation. The monitoring group for lithium therapy would not normally include the IV salt.

**BNF alone is sufficient for the oral lithium monitoring group. IV lithium chloride is out of scope for monitoring and not in the BNF data.**

### 4.6 Valproate — BNF `04080100` ✗

BNF 4.8.1 is "Control of epilepsy", covering all antiepileptic drugs. The 640 VMPs span 32 VTMs including carbamazepine, lamotrigine, phenytoin, levetiracetam, topiramate, pregabalin, clonazepam, clobazam, gabapentin, phenobarbital, and many others, as well as sodium valproate (35 VMPs) and valproic acid (8 VMPs).

BNF alone cannot retrieve just valproate. A pharmacist must select the two target VTMs from the 32-VTM candidate list.

However, BNF 4.8.1 still provides value: it narrows the search space to the correct chapter and confirms that both valproate salt forms have BNF coverage. Starting from BNF `04080100`, a pharmacist selects sodium valproate and valproic acid from a 32-VTM list. That is faster than scanning the full VTM catalogue.

**BNF is a useful starting filter but VTM-level selection is mandatory for valproate.**

### 4.7 Amiodarone and dronedarone — BNF `02030200` ✗

BNF 2.3.2 is "Drugs for arrhythmias" (a broad antiarrhythmic class). The 178 VMPs span 13 VTMs including amiodarone, dronedarone, disopyramide, flecainide, mexiletine, propafenone, and sotalol among others.

BNF cannot extract just amiodarone and dronedarone. A pharmacist must select these two from the 13-VTM list.

**BNF narrows to 13 antiarrhythmic VTMs. Pharmacist selects 2.**

### 4.8 Levothyroxine and thyroid hormones — BNF `06020100` ✓

BNF 6.2.1 (thyroid hormones) maps cleanly. The 4 VTMs found are levothyroxine, liothyronine, and combination forms. No non-thyroid products appear.

The 181 VMPs reflect the very large number of levothyroxine product variants in dm+d (143 levothyroxine VMPs alone were confirmed in earlier analysis).

**BNF alone generates the correct candidate list with no noise.**

### 4.9 Metformin — BNF `06010200` ✗

BNF 6.1.2 is "Antidiabetic drugs" (all oral antidiabetics). The 44 VTMs include metformin (23 VMPs), but also SGLT2 inhibitors (empagliflozin, dapagliflozin, canagliflozin), DPP-4 inhibitors (sitagliptin, alogliptin, saxagliptin, linagliptin, vildagliptin), sulfonylureas (gliclazide, glibenclamide, tolbutamide, glimepiride, glipizide), GLP-1 receptor agonists, pioglitazone, acarbose, nateglinide, repaglinide, and insulin-containing combinations.

A pharmacist must select metformin plus specific metformin-containing fixed-dose combinations from a 44-VTM field.

**BNF narrows to 44 antidiabetic VTMs. Pharmacist selects metformin plus combination products.**

### 4.10 Antipsychotics — BNF `04020100` ⚠

BNF 4.2.1 contains 33 VTMs (313 VMPs) covering all antipsychotics — both typical (chlorpromazine, haloperidol, prochlorperazine, fluphenazine, trifluoperazine) and atypical (olanzapine, quetiapine, risperidone, amisulpride, aripiprazole, clozapine, lurasidone, etc.).

The BNF code correctly assembles the antipsychotic class. Whether the monitoring group should include all antipsychotics or only high-metabolic-risk atypicals or only clozapine is a clinical governance question that BNF cannot answer.

**BNF delivers the full antipsychotic class. Pharmacist sets clinical boundaries for the monitoring group.**

### 4.11 Systemic glucocorticoids — BNF `06030200` ✓

BNF 6.3.2 maps to systemic glucocorticoid therapy. The 11 VTMs (184 VMPs) are the expected oral and injectable systemic corticosteroids: betamethasone, cortisone, deflazacort, dexamethasone, hydrocortisone, methylprednisolone (base and sodium succinate), prednisolone, prednisone, and triamcinolone acetonide.

Route verification confirmed that all hydrocortisone VMPs under this code have oral routes. Inhaled corticosteroids (BNF 3.2 = `03020000`, 101 VMPs) and nasal/ophthalmic preparations are in completely separate BNF sections.

One minor note: methylprednisolone aceponate (1 VMP) appears in `06030200` despite being a topical dermatological product. This single VMP would need a VMP-level exclusion if the group is intended to capture only oral/parenteral systemic steroids.

**BNF correctly separates systemic from inhaled and topical. One VMP-level exclusion may be needed.**

### 4.12 Oral iron — BNF `09010101` ✓

BNF 9.1.1.1 (oral iron, the sub-paragraph level) maps to exactly the right products: ferrous sulfate, ferrous fumarate, ferrous gluconate, ferrous citrate, ferric maltol, sodium feredetate, and ferrous-combination products. No parenteral iron appears.

**BNF provides clean oral iron separation at sub-paragraph level.**

### 4.13 Parenteral iron — BNF `09010102` ✓

BNF 9.1.1.2 (parenteral iron) maps to exactly the right products: ferric carboxymaltose, ferric derisomaltose, iron sucrose, iron dextran, iron sorbitol, ferumoxytol (6 VTMs, 11 VMPs).

**BNF provides clean parenteral iron separation at sub-paragraph level.**

### 4.14 Vitamin B12 — BNF `09010200` ⚠

BNF 9.1.2 groups B12 (cyanocobalamin, hydroxocobalamin) together with folic acid and levomefolic acid (5 VTMs, 71 VMPs). Of these 71 VMPs, 44 belong to folic acid alone.

A monitoring group for "Vitamin B12 therapy" must explicitly exclude the 2 folic acid VTMs from the BNF-generated candidate list. Hydroxocobalamin is also used in cyanide poisoning antidote formulations (the two large-volume powder-for-infusion VMPs that have no BNF code); those would not appear in a BNF query.

**BNF narrows to 5 VTMs. Pharmacist excludes folic acid (2 VTMs) to get B12 only.**

### 4.15 Vitamin D — BNF `09060400` ✓

BNF 9.6.4 maps to vitamin D products. The 12 VTMs (216 VMPs) include colecalciferol (88 VMPs), ergocalciferol (64 VMPs), calcitriol, alfacalcidol, and combination preparations. One ergocalciferol VMP has no BNF code but this is a minor gap.

Whether to include calcitriol/alfacalcidol (active metabolites, often used in renal disease) alongside colecalciferol/ergocalciferol (supplementation) depends on the clinical question — a small but real curation decision.

**BNF delivers the correct vitamin D class. Pharmacist decides whether active metabolites are in scope.**

---

## 5. Summary Assessment

### 5.1 What BNF codes can do automatically

For **nine of the fifteen MVP groups**, a single BNF code generates a well-bounded candidate list of 4 to 23 VTMs. The pharmacist review becomes confirmation and policy-setting rather than discovery. This is a substantial reduction from scanning 3,098 active VTMs.

| Group | Reduction in review scope |
| :-- | :-- |
| ACE inhibitors | 3,098 → 23 VTMs |
| ARBs | 3,098 → 22 VTMs |
| Lithium | 3,098 → 4 VTMs |
| Levothyroxine / thyroid | 3,098 → 4 VTMs |
| Systemic corticosteroids | 3,098 → 11 VTMs |
| Oral iron | 3,098 → 14 VTMs |
| Parenteral iron | 3,098 → 6 VTMs |
| Vitamin D | 3,098 → 12 VTMs |
| Antipsychotics | 3,098 → 33 VTMs |

For a further **four groups** where the BNF section is broader than the clinical concept, the pharmacist starts with a BNF-generated list of 5 to 44 VTMs rather than 3,098:

| Group | BNF candidate list | Selection task |
| :-- | :-- | :-- |
| Oral anticoagulants / DOACs | 10 VTMs | Select 4 DOACs or warfarin from 10 |
| Vitamin B12 | 5 VTMs | Exclude 2 folic acid VTMs from 5 |
| Antiarrhythmics → amiodarone/dronedarone | 13 VTMs | Select 2 from 13 |
| Valproate | 32 VTMs | Select 2 from 32 antiepileptics |

For **one group** (metformin/diabetes combinations) the BNF section spans 44 antidiabetic VTMs and requires more substantive VTM selection work, though still far less than a full-catalogue scan.

For **one group** (DMARDs + immunosuppressants) the pharmacist must combine BNF `10010300` with three specific VTMs from BNF chapter 8. The BNF still identifies the right territory; it cannot do the cross-chapter assembly automatically.

### 5.2 What BNF codes cannot do

BNF codes cannot:

1. **Separate sub-groups within a broad section.** Valproate from other antiepileptics, DOACs from warfarin, metformin from other oral antidiabetics, and amiodarone from other antiarrhythmics all require explicit VTM selection that BNF alone cannot provide.

2. **Assemble multi-chapter clinical concepts.** A clinical "DMARDs and Immunosuppressants" monitoring group spans BNF chapters 8 and 10. No single BNF query retrieves the complete clinical set.

3. **Apply monitoring intent.** Whether olanzapine for nausea should be included in annual metabolic monitoring is a clinical governance question. BNF knows only that it is an antipsychotic.

4. **Cover 27.6% of VMPs that have no BNF code.** For the MVP groups this is a minor issue (all key monitoring drugs have near-complete BNF coverage), but it becomes material for any broader prescribing taxonomy.

5. **Make VMP-level exclusions.** Methylprednisolone aceponate is classified under systemic glucocorticoids by BNF even though it is a topical product. Sacubitril+valsartan sits in the ARB section. These VMP-level anomalies need human review.

---

## 6. Proposed Two-Level Architecture Enabled by BNF

The evidence supports a revised curation model that replaces step-by-step manual VTM discovery with BNF-seeded candidate generation:

### Level 1 — BNF seed query (automated)

For each clinical monitoring group, record:

- One or more BNF 8-character code prefixes that cover the drug class.
- A VTM include-list (for cases where the BNF section is broader than needed).
- A VTM exclude-list (for edge cases such as folic acid in the B12 BNF section).
- A cross-chapter supplement list (for DMARDs + chapter 8 immunosuppressants).

This level is executed by a script against the dm+d database and produces a candidate VTM/VMP/AMP set automatically.

### Level 2 — Pharmacist confirmation review (reduced)

The pharmacist review becomes:

- Is the BNF-generated VTM list complete?
- Are any VTMs out of scope for this monitoring question (VTM-level exclusion)?
- Are any combination products in or out?
- Is the user-facing group name safe?
- Are the monitoring parameters (tests, intervals, ownership) correct?

This review typically takes minutes for clean groups and up to an hour for complex multi-chapter groups. It is not eliminated but it is transformed from an open-ended discovery task into a bounded confirmation task.

---

## 7. Worked BNF Query Template

The following SQL structure illustrates how BNF codes would feed the curation pipeline:

```sql
-- Candidate generation for a BNF-seeded monitoring group
-- Example: ACE inhibitors
SELECT 
    t.vtmid,
    t.nm                               AS vtm_name,
    COUNT(DISTINCT v.vpid)             AS vmp_count,
    COUNT(DISTINCT a.apid)             AS amp_count,
    MIN(b.bnf_code)                    AS bnf_code
FROM dmd_bnf b
JOIN vmp v   ON b.vpid   = v.vpid    AND v.invalid = 0
JOIN vtm t   ON v.vtmid  = t.vtmid   AND t.invalid = 0
LEFT JOIN amp a ON v.vpid = a.vpid   AND a.invalid = 0
WHERE b.bnf_code = '02050501'            -- ACE inhibitors
-- For groups needing VTM exclusion, add:
-- AND t.nm NOT IN ('Unwanted VTM')
-- For groups needing cross-chapter supplement, run a UNION:
-- UNION ALL SELECT ... WHERE b.bnf_code = '08020200' AND t.nm IN ('Ciclosporin')
GROUP BY t.vtmid, t.nm
ORDER BY t.nm;
```

For groups with an over-broad BNF section (e.g., valproate from antiepileptics), the template changes to a VTM-first query seeded by the BNF candidate list:

```sql
-- Valproate: use BNF 04080100 to confirm coverage, then select by VTM
SELECT 
    t.vtmid,
    t.nm                               AS vtm_name,
    COUNT(DISTINCT v.vpid)             AS vmp_count,
    COUNT(DISTINCT a.apid)             AS amp_count
FROM vtm t
JOIN vmp v   ON t.vtmid = v.vtmid AND v.invalid = 0
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
-- Pharmacist-curated VTM selection (fed by the BNF 04080100 candidate list):
WHERE t.nm IN ('Sodium valproate', 'Valproic acid')
AND t.invalid = 0
GROUP BY t.vtmid, t.nm
ORDER BY t.nm;
```

---

## 8. BNF Reference Table for 15 MVP Groups

| Group | Primary BNF code | Coverage verdict | VTMs in BNF section | Required extra step |
| :-- | :-- | :-- | --: | :-- |
| ACE inhibitors | `02050501` | Clean | 23 | None — confirm combinations policy |
| ARBs | `02050502` | Clean | 22 | Decide on sacubitril+valsartan |
| All oral anticoagulants | `02080200` | Broad | 10 | Select sub-group VTMs |
| DOACs only | `02080200` | Broad | 10 | Select apixaban, rivaroxaban, dabigatran, edoxaban |
| Warfarin and coumarins | `02080200` | Broad | 10 | Select warfarin and acenocoumarol |
| DMARDs (BNF) | `10010300` | Core | 23 | Add azathioprine, mycophenolate, ciclosporin from BNF 08020100/08020200 |
| Lithium (all salts) | `04020300` | Clean | 4 | None |
| Valproate | `04080100` | Over-broad | 32 | Select sodium valproate + valproic acid |
| Amiodarone monitoring | `02030200` | Over-broad | 13 | Select amiodarone + dronedarone |
| Levothyroxine / thyroid | `06020100` | Clean | 4 | None — confirm liothyronine in scope |
| Metformin + combos | `06010200` | Over-broad | 44 | Select metformin and metformin-containing VTMs |
| Antipsychotics | `04020100` | Class | 33 | Set clinical boundary (all vs monitoring-risk subset) |
| Systemic corticosteroids | `06030200` | Clean | 11 | Exclude methylprednisolone aceponate VMP if needed |
| Oral iron | `09010101` | Clean | 14 | None |
| Parenteral iron | `09010102` | Clean | 6 | None |
| Vitamin B12 | `09010200` | Broad | 5 | Exclude folic acid VTMs (2) |
| Vitamin D | `09060400` | Clean | 12 | Decide on calcitriol/alfacalcidol scope |

---

## 9. Conclusion

The BNF grouper data in dm+d does not replace the need for a pharmacist. It does substantially reduce the curation burden.

**Problems it solves:**

- Eliminates open-ended VTM scanning for groups that have a single-section BNF classification. For nine MVP groups the pharmacist moves from "discover which VTMs exist" to "confirm a short candidate list of 4 to 33 VTMs".
- Automatically separates routes that the requirements analysis flagged as manual work: systemic versus inhaled corticosteroids, systemic versus ophthalmic ciclosporin, oral versus parenteral iron.
- Provides a deterministic, monthly-refreshable candidate set that is always anchored to the current dm+d release.

**Problems it does not solve:**

- Over-broad BNF sections for valproate, metformin, antiarrhythmics — VTM selection remains mandatory.
- Cross-chapter groupings (DMARDs + immunosuppressants) — multi-section assembly remains a pharmacist task.
- Monitoring-intent decisions (which antipsychotics warrant annual metabolic monitoring) — irreducibly clinical.
- 27.6% of VMPs lack BNF codes, limiting the approach for any wider prescribing taxonomy beyond the primary care monitoring use cases.

**Recommended change to the curation workflow:**

Replace *Step 2 — Automated candidate generation* in the requirements analysis workflow with a BNF-seeded query that produces the initial VTM list. The pharmacist review step remains in place but operates on a bounded list rather than an open-ended one. The expected reduction in pharmacist time for the 15 MVP groups is from several days of scanning to a few hours of confirmation review.

---

## Appendix: SQL Queries Used

### BNF code length and coverage

```sql
-- Confirm all BNF codes are 8-character fixed length
SELECT DISTINCT LEN(bnf_code) AS code_len, COUNT(*) AS cnt
FROM dmd_bnf GROUP BY LEN(bnf_code);

-- Coverage: VMPs with and without BNF codes
SELECT 
    COUNT(DISTINCT v.vpid)                        AS vmps_with_bnf,
    (SELECT COUNT(*) FROM vmp WHERE invalid = 0)  AS total_active_vmps,
    (SELECT COUNT(*) FROM vmp WHERE invalid = 0)
    - COUNT(DISTINCT v.vpid)                      AS vmps_without_bnf
FROM dmd_bnf b
JOIN vmp v ON b.vpid = v.vpid AND v.invalid = 0;
```

### Coverage for 15 MVP groups

```sql
SELECT 
    grp.clinical_group, grp.bnf_code,
    COUNT(DISTINCT b.vpid)  AS vmp_count,
    COUNT(DISTINCT t.vtmid) AS vtm_count
FROM (VALUES
    ('ACE inhibitors',           '02050501'),
    ('ARBs',                     '02050502'),
    ('Oral anticoagulants',      '02080200'),
    ('DMARDs',                   '10010300'),
    ('Lithium',                  '04020300'),
    ('Antiepileptics (valproate section)', '04080100'),
    ('Antiarrhythmics',          '02030200'),
    ('Thyroid hormones',         '06020100'),
    ('Oral antidiabetics',       '06010200'),
    ('Antipsychotics',           '04020100'),
    ('Systemic glucocorticoids', '06030200'),
    ('Oral iron',                '09010101'),
    ('Parenteral iron',          '09010102'),
    ('B12 and folate',           '09010200'),
    ('Vitamin D',                '09060400')
) AS grp(clinical_group, bnf_code)
LEFT JOIN dmd_bnf b  ON b.bnf_code = grp.bnf_code
LEFT JOIN vmp v      ON b.vpid = v.vpid AND v.invalid = 0
LEFT JOIN vtm t      ON v.vtmid = t.vtmid AND t.invalid = 0
GROUP BY grp.clinical_group, grp.bnf_code
ORDER BY grp.clinical_group;
```

### VTM-level coverage gaps for key monitoring drugs

```sql
SELECT t.nm AS vtm,
    COUNT(DISTINCT v.vpid)  AS total_vmps,
    COUNT(DISTINCT b.vpid)  AS vmps_with_bnf,
    COUNT(DISTINCT v.vpid) - COUNT(DISTINCT b.vpid) AS vmps_no_bnf
FROM vtm t
JOIN vmp v ON t.vtmid = v.vtmid AND v.invalid = 0
LEFT JOIN dmd_bnf b ON v.vpid = b.vpid
WHERE t.invalid = 0
AND t.nm IN (
    'Lithium carbonate', 'Lithium citrate', 'Lithium chloride',
    'Sodium valproate', 'Valproic acid',
    'Warfarin', 'Apixaban', 'Rivaroxaban', 'Dabigatran etexilate', 'Edoxaban',
    'Methotrexate', 'Hydroxychloroquine', 'Leflunomide',
    'Amiodarone', 'Dronedarone', 'Levothyroxine',
    'Metformin', 'Ciclosporin', 'Azathioprine',
    'Prednisolone', 'Dexamethasone',
    'Ferrous sulfate', 'Ferric carboxymaltose', 'Iron sucrose',
    'Hydroxocobalamin', 'Cyanocobalamin',
    'Colecalciferol', 'Ergocalciferol'
)
GROUP BY t.nm
ORDER BY t.nm;
```

---

## Sources

- `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release, tables `dmd_bnf`, `vmp`, `vtm`, `amp`, `vmp_drugroute`.
- [curated-medication-groups-requirements-analysis.md](curated-medication-groups-requirements-analysis.md) — requirements context.
- NHS NHSBSA dm+d Data Model R2 v4.0 (October 2024) — schema reference for the `dmd_bnf` supplementary table.
- BNF chapter and section numbering from the British National Formulary, as reflected in the NHSBSA 8-character BNF code scheme.
