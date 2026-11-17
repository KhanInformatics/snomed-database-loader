# Curated Medication Groups Requirements Analysis

**Date:** 2026-06-26  
**Purpose:** Define what would be required to build functionality similar in shape to Ardens medication monitoring searches and EMIS Drug Groups, without copying their proprietary content.

---

## 1. Executive Summary

The VTM-first dm+d resolver gets us a long way, but it does not replace the curated medication group layer used by products such as Ardens and EMIS.

The practical target is not one algorithm. It is a four-layer medication knowledge system:

1. **Structural resolver:** dm+d-driven `VTM -> VMP -> AMP`, with optional ingredient-pivot expansion for combinations and named-combination guards.
2. **Curated group layer:** clinically named sets such as `Oral iron`, `DMARDs`, `ACE inhibitors`, `ARBs`, `DOACs`, `All lithium`, `All valproate`, `Systemic ciclosporin`, and `Drugs needing annual monitoring`.
3. **Clinical rule layer:** monitoring tests, intervals, age rules, sex rules, route/formulation filters, stable therapy rules, initiation/titration exceptions, secondary-care ownership, and exclusion logic.
4. **Operational workflow layer:** alerts, invite queues, non-responder handling, dashboards, audit snapshots, and patient-level explanation.

The key conclusion is that we should not try to recreate EMIS Groups or Ardens by hand from day one. We should build a governed medication group platform where most candidate groups are generated from dm+d and then clinically curated, versioned, tested, and released.

The MVP should focus on high-risk prescribing and monitoring groups first. Full EMIS-style drug grouping across the whole prescribing universe is a much larger, ongoing informatics product.

---

## 2. Evidence Base

### Ardens

The Ardens EMIS prescribing monitoring article describes a `2.20 Prescribing - Monitoring` folder that includes drug monitoring for ACE inhibitors, levothyroxine, anticoagulants, DMARDs and other medicines. It also describes invite workflows, Blood Test Due Analyser integration, secondary-care/hospital issue handling, non-responder searches, and a `Register and Monitoring - by drug` breakdown.

The Ardens SystmOne drug monitoring article exposes a similar pattern through `Prescribing | Monitoring`, with folders such as `Drugs | Annual`, `Drugs | Anticoagulants`, `Drugs | DMARDS`, and `Drugs | HRD`. It also describes pop-up alerts, templates, primary-care versus secondary-care monitoring, accessibility cohorts, and monitoring frequencies based on national guidance.

This is not just codelist search. It is an end-to-end medication monitoring workflow.

### EMIS Drug Groups

Local observation in the medication search background note shows that EMIS Web Code Selector has a `Groups` tab, alongside `Ingredients` and `Approved names`. The observed `Groups` search for iron surfaced curated categories such as:

- Drugs Used In Iron Deficiency Anaemia.
- Oral Iron Therapy.
- Parenteral Iron Therapy.

Selecting one of those groups populated a product list. That behaviour is not derivable from a single dm+d join. It reflects editorial grouping.

Public support material also describes EMIS Drug Group sorting as grouping medicines along BNF subcategories, making long medication lists easier to navigate. Public EMIS MKB support material describes the EMIS Medical Knowledge Base as regularly updated, aligned with dm+d and UK SNOMED CT, and used for prescribing decision support.

The exact EMIS group definitions are proprietary. The relevant lesson is the shape of the capability: curated, maintained, clinically meaningful groups sitting above raw dm+d concepts.

---

## 3. Current dm+d Scale

Local queries were run against `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release (`nhsbsa_dmd_6.0.0_20260601000001`).

| Metric | Count |
| :-- | --: |
| Active VTMs | 3,130 |
| Active VTMs with at least one active VMP | 3,098 |
| Active VMPs | 23,950 |
| Active AMPs | 166,645 |
| Named-combination guarded VTMs with active VMPs | 729 |
| Non-combination VTMs with active VMPs | 2,369 |
| Non-combination VTMs where ingredient expansion finds extra VMPs | 473 |
| Non-combination VTMs with no extra expansion but ingredient data present | 1,805 |
| VTMs where all direct VMPs have no ingredient rows | 109 |
| VTMs with partial direct VMP ingredient coverage | 81 |

High-AMP VTMs show why the UI and audit layer must handle large expansions:

| VTM | VMPs | AMPs |
| :-- | --: | --: |
| Colecalciferol | 88 | 513 |
| Sodium iodide [I-131] | 398 | 418 |
| Pregabalin | 31 | 399 |
| Sodium chloride | 158 | 361 |
| Ibuprofen | 29 | 344 |
| Tramadol | 20 | 330 |
| Paracetamol | 51 | 328 |
| Olanzapine | 30 | 322 |
| Risperidone | 20 | 301 |
| Lamotrigine | 33 | 296 |
| Quetiapine | 36 | 290 |
| Omeprazole | 54 | 284 |
| Levothyroxine | 143 | 283 |

The structural algorithm can generate a lot of candidate content, but it cannot decide clinical intent.

---

## 4. What dm+d Can Do Automatically

The dm+d resolver can safely automate these tasks:

### 4.1 Salt-form grouping within a VTM

Examples already validated:

- Amoxicillin VTM includes sodium injections and trihydrate oral products.
- Methotrexate VTM includes base and sodium salt forms.
- Warfarin VTM includes warfarin sodium products.
- Amiodarone VTM hides the hydrochloride ingredient detail from the user.

This is the strongest reason to search `vtm.nm`, not raw ingredient names.

### 4.2 Direct clinical product scope

For a selected VTM, the direct VMP set is the clinical scope.

The saved/executed scope must then expand to AMPs because the prescription issue is stored at AMP level in our system.

### 4.3 Optional combination expansion

For selected single-drug VTMs, the ingredient pivot finds products where that drug appears inside a fixed-dose combination.

Validated examples:

- Amoxicillin finds Co-amoxiclav.
- Metformin finds modern diabetes combinations.
- Simvastatin finds Simvastatin + Ezetimibe and other combinations.
- Valsartan finds Sacubitril + Valsartan, Amlodipine + Valsartan, and Valsartan + Hydrochlorothiazide.
- Levothyroxine partially finds Levothyroxine + Liothyronine.

### 4.4 Named-combination guard

The guard prevents over-expansion when the selected input is already a named combination:

```sql
vtm.nm LIKE '% + %' OR vtm.nm LIKE 'Co-%'
```

This is algorithmic and should not need manual curation except for regression tests.

### 4.5 Candidate generation for curated groups

dm+d can generate candidate members for groups by:

- **BNF code query against `dmd_bnf`.** This is the primary mechanism. Queries run against the June 2026 release confirm that 17,334 of 23,950 active VMPs (72.4%) carry an 8-character BNF code in the `dmd_bnf` supplementary table. For nine of the fifteen MVP monitoring groups a single BNF code produces a correctly bounded candidate VTM list, reducing the pharmacist review from 3,098 active VTMs to between 4 and 33 VTMs per group. See [bnf-grouper-feasibility-analysis.md](bnf-grouper-feasibility-analysis.md) for the full group-by-group evidence.
- VTM name search.
- Ingredient expansion.
- Route/formulation heuristics from VMP name or route table.
- ATC metadata where available.
- Existing manually approved group membership from a previous release.
- Delta detection between releases.

But these candidates still need clinical review.

---

## 5. What Requires Manual Curation

The manually curated layer is required where clinical intent is broader, narrower, or differently shaped than a single VTM.

### 5.1 Multi-VTM clinical concepts

Some clinically natural searches require multiple VTMs:

| Clinical concept | dm+d reality | BNF status | Residual requirement |
| :-- | :-- | :-- | :-- |
| All lithium | Lithium carbonate, Lithium citrate, Lithium chloride | `04020300` — all 4 VTMs present, clean ✓ | Confirm IV lithium chloride is out of scope |
| All valproate | Sodium valproate and Valproic acid | `04080100` — both present but section contains 32 antiepileptic VTMs ⚠ | Select 2 VTMs from BNF-generated list |
| Oral iron | Oral iron salts (ferrous/ferric) | `09010101` — 14 VTMs, no parenteral iron ✓ | None |
| Parenteral iron | IV iron preparations | `09010102` — 6 VTMs, no oral iron ✓ | None |
| Vitamin D | Colecalciferol and Ergocalciferol | `09060400` — 12 VTMs including active metabolites ✓ | Decide whether calcitriol/alfacalcidol are in scope |
| Vitamin B12 | Cyanocobalamin and Hydroxocobalamin | `09010200` — 5 VTMs but folic acid also present ⚠ | Exclude 2 folic acid VTMs from BNF-generated list |

For groups marked ✓ BNF eliminates open-ended discovery. For groups marked ⚠ BNF narrows the field to a short list requiring human selection. In both cases the pharmacist is confirming a bounded list, not scanning the full catalogue.

### 5.2 Route-specific or formulation-specific intent

Some monitoring searches should exclude products that share the VTM but do not share the monitoring risk.

Examples and BNF resolution status:

- **Ciclosporin systemic monitoring should not include ciclosporin eye drops.** Confirmed resolved by BNF: systemic ciclosporin maps to `08020200`, ophthalmic ciclosporin maps to `11040200`. A BNF-seeded query for `08020200` already excludes the eye drops with no manual VMP exclusion needed.
- Mycophenolate systemic monitoring may need to exclude rare topical preparations. BNF `08020100` covers systemic mycophenolate only — topical forms, if present, would be in a dermatology BNF section.
- **Oral iron and parenteral iron are clinically different groups.** Confirmed resolved by BNF: oral iron is `09010101`, parenteral iron is `09010102`. Separate coding at the 8-character sub-paragraph level.
- **Long-term oral corticosteroid monitoring differs from inhaled and topical steroids.** Confirmed resolved by BNF: systemic glucocorticoids are `06030200`, inhaled corticosteroids are `03020000`, topical skin preparations are in BNF chapter 13. All hydrocortisone VMPs under `06030200` were verified as oral-route products.

For these four examples, BNF does the route/formulation work automatically. The remaining curation requirement is a confirmation step, not a discovery step.

### 5.3 Class groups

Ardens and EMIS-style functionality requires classes such as ACE inhibitors, ARBs, DOACs, DMARDs, and annual monitoring drugs. dm+d does not supply these operational groupings directly, but BNF codes in `dmd_bnf` cover the pharmacological classes:

| Class | BNF code | VTMs | Notes |
| :-- | :-- | --: | :-- |
| ACE inhibitors | `02050501` | 23 | Clean, includes combinations |
| ARBs | `02050502` | 22 | Includes sacubitril+valsartan — clinical decision needed |
| Oral anticoagulants | `02080200` | 10 | Warfarin and DOACs merged — VTM filter needed for sub-groups |
| DMARDs (BNF core) | `10010300` | 23 | Does not include azathioprine, mycophenolate, ciclosporin |
| Antipsychotics | `04020100` | 33 | Full class — monitoring boundary is a clinical decision |
| Thyroid hormones | `06020100` | 4 | Clean |
| Systemic corticosteroids | `06030200` | 11 | Clean — inhaled and topical are in separate BNF sections |

BNF does not supply operational groupings such as `High-risk drugs`, `Annual monitoring drugs`, `Drugs requiring CrCl`, or `Secondary-care ownership`. Those remain entirely in the monitoring rule layer.

### 5.4 Monitoring intervals and tests

The medication group is only half of an Ardens-style search.

Each group may need:

- Blood tests.
- Non-blood observations.
- Review codes.
- Monitoring interval.
- Stable therapy logic.
- Initiation and titration exclusions.
- Age restrictions.
- Pregnancy or sex restrictions.
- Care ownership restrictions.
- Repeat or current issue rules.
- Hospital issue handling.

This cannot be derived from dm+d alone.

### 5.5 Workflow buckets

Ardens routes patients into operational buckets:

- Send invite.
- Consider invite.
- Consider visit.
- Review hospital/secondary-care issue.
- Non-responder.
- Partial monitoring completed.
- Data recalculation only, such as BMI or CrCl.

These are search workflow definitions, not medication facts.

### 5.6 Editorial naming

User-facing names are curated:

- `Oral Iron Therapy`.
- `Parenteral Iron Therapy`.
- `DMARDs & Immunosuppressants`.
- `High Risk Drug Monitoring`.
- `Annual Drug Monitoring`.

Good names reduce mistakes. They are not always the same as dm+d or BNF names.

---

## 6. Proposed Architecture

At a high level, this would need a small curated medication knowledge layer above the deterministic dm+d resolver. The resolver should continue to do the mechanical work: `VTM -> VMP -> AMP`, optional combination expansion, named-combination guarding, and audit counts. The curated layer would hold named clinical groups such as `All lithium`, `Systemic ciclosporin`, `ACE inhibitors`, `ARBs`, `DOACs`, `Oral iron`, and `Parenteral iron`, including any VMP-level exclusions needed to make the group clinically safe.

Monitoring rules and workflow rules should sit beside those curated groups rather than inside the resolver. For example, `Amiodarone` can resolve cleanly through dm+d, but the rule that it needs U&E, LFT and TFT within 6 months belongs to the monitoring layer. Each curated group should be versioned against a dm+d release, have a simple review history, show its VMP and AMP counts, and be diffed when dm+d is updated.

---

## 7. Curation Workflow

### Step 1 - Intake

A new group starts from a clinical use case, not from a drug list.

Example:

`Find patients on ACE inhibitors or ARBs who need renal monitoring.`

Required intake fields:

- Clinical question.
- Patient safety consequence of missing a patient.
- Patient burden consequence of over-including a patient.
- Source guidance.
- Scope boundaries.
- Monitoring tests.
- Ownership rules.
- Target EHR data field for matching.

### Step 2 - Automated candidate generation

Generate candidates from dm+d using:

- **BNF-seeded query.** For each group, record one or more 8-character BNF codes and query `dmd_bnf` to produce an initial VTM list. For nine of the fifteen MVP groups this produces a correctly bounded list of 4 to 33 VTMs that requires pharmacist confirmation rather than discovery. For groups with over-broad BNF sections (valproate, metformin, antiarrhythmics) the BNF query narrows the field to a manageable short list from which VTMs are selected.
- VTM name search for cross-chapter supplements (e.g., azathioprine and mycophenolate for the DMARDs group).
- Ingredient expansion for combination product policies.
- Existing approved group version for delta detection.
- Route and formulation data for residual route checks.
- Known exception library.

The output is a proposed VTM/VMP/AMP count, not an approved group.

### Step 3 - Clinical curation

A pharmacist or medication informatics reviewer confirms:

- Which VTMs are in.
- Which VTMs are out.
- Which VMPs are excluded despite VTM inclusion.
- Whether combination products are included.
- Whether route/formulation filters apply.
- Whether invalid concepts are needed for historical reporting.
- Whether the user-facing name is safe.

### Step 4 - QA and regression tests

Each group needs tests:

- Expected included exemplar products.
- Expected excluded exemplar products.
- Expected direct VMP count.
- Expected AMP count.
- Expected behaviour after ingredient expansion.
- Expected behaviour for named combinations.
- Expected behaviour after dm+d release update.

High-risk groups need explicit negative tests.

Examples:

- `Systemic ciclosporin` excludes eye drops.
- `All lithium` includes carbonate and citrate.
- `Valproate safety monitoring` includes sodium valproate and valproic acid.
- `Amiodarone monitoring` includes AMPs under Amiodarone VTM.
- `Co-methiamol` selected as input does not expand to all paracetamol products.

### Step 5 - Clinical safety signoff

Before release, each group should have:

- Named clinical owner.
- Named technical owner.
- Change summary.
- Impact counts.
- Known limitations.
- Source references.
- Signoff timestamp.

### Step 6 - Monthly release alignment

Because dm+d changes monthly, curated groups need monthly review.

The release process should:

1. Load the new dm+d release.
2. Re-resolve every concept set.
3. Diff VTM, VMP, and AMP membership.
4. Flag new candidate products.
5. Flag products no longer active.
6. Flag large count changes.
7. Require review for high-risk groups.
8. Publish a versioned release note.

---

## 8. Required Tooling

### 8.1 Medication group explorer

Needs to show:

- Group name and purpose.
- Included VTMs.
- Included VMPs.
- Excluded VMPs.
- AMP execution count.
- Combination expansion details.
- Ingredient ISIDs used.
- Named-combination guard status.
- Route/formulation breakdown.

### 8.2 Diff viewer

Needs to compare group versions:

- New VMPs.
- Removed VMPs.
- New AMPs.
- Removed AMPs.
- Changed VTM status.
- Changed ingredient links.
- Changed route/formulation data.
- New products found by combination expansion.

### 8.3 Curation interface

Must allow safe editing:

- Add VTM.
- Exclude VMP.
- Include related VTM.
- Set expansion policy.
- Set route/formulation filter.
- Attach source reference.
- Record reason for decision.
- Request review.
- Approve or reject.

### 8.4 Rule tester

Given a concept set and monitoring rule, show:

- Matched VMPs.
- Matched AMPs.
- Example prescriptions matched.
- Example prescriptions excluded.
- Patient count in a test population if available.
- Reasons for inclusion or exclusion.

### 8.5 Release pipeline

Needs:

- Automated dm+d import.
- Automated group re-resolution.
- Automated tests.
- Human review queue for flagged diffs.
- Signed release artifact.
- Rollback.
- Audit log.

### 8.6 API surface

Minimum APIs:

- Search curated groups.
- Search VTMs.
- Resolve a group to VMPs and AMPs.
- Resolve a selected VTM to VMPs and AMPs.
- Explain a resolved match.
- Get group version metadata.
- Export concept set for reporting.

---

## 9. Staffing and Governance

This cannot be owned purely by engineering.

### Required roles

- Clinical safety owner.
- Medication informatics pharmacist.
- Terminology engineer.
- Product owner.
- QA/test analyst.
- GP or primary-care clinical reviewer.
- Release manager.

### Estimated effort by phase

| Phase | Scope | Likely effort |
| :-- | :-- | :-- |
| Prototype | VTM resolver, AMP expansion, 10 to 20 curated monitoring groups | 4 to 8 weeks engineering plus pharmacist review |
| MVP | High-risk monitoring groups, release diff tooling, audit snapshots | 3 to 4 months mixed clinical/engineering work |
| Production | Monthly release process, rule tester, clinical signoff workflow, dashboards | 6 to 9 months |
| EMIS-like full group coverage | Broad prescribing taxonomy across most medication areas | Ongoing informatics function, not a one-off project |

The full EMIS Groups equivalent is not a project deliverable. It is a maintained knowledge base.

---

## 10. Recommended MVP Scope

Do not start by trying to classify all 3,098 active VTMs.

Start with high-safety, high-value monitoring groups:

1. DMARDs and immunosuppressants.
2. DOACs.
3. Warfarin and anticoagulants.
4. Lithium.
5. Valproate.
6. ACE inhibitors.
7. ARBs.
8. Amiodarone and dronedarone.
9. Levothyroxine and thyroid hormones.
10. Metformin and diabetes combinations.
11. Systemic corticosteroids.
12. Antipsychotics for annual monitoring.
13. Oral iron and parenteral iron as separate groups.
14. Vitamin B12.
15. Vitamin D.

For each group, produce:

- Curated VTM seed list.
- Direct VMP count.
- Combination expansion policy.
- Manual VMP exclusions if required.
- AMP execution count.
- Monitoring rule.
- Regression tests.
- Source references.
- Known limitations.

---

## 11. Acceptance Criteria

A curated medication group is not ready until it satisfies all of these:

1. It has a named clinical purpose.
2. It has a versioned definition.
3. It resolves against a specific dm+d release.
4. It has a visible VTM/VMP clinical scope.
5. It has an AMP execution scope.
6. It explains included combinations.
7. It explains excluded products.
8. It records whether invalid products are included for historical reporting.
9. It has source references.
10. It has at least one positive and one negative regression test.
11. It has a monthly-diff review path.
12. It has clinical signoff.

---

## 12. Risks

### 12.1 Copying proprietary content

Ardens and EMIS group definitions are proprietary. We can learn from their shape, but we should not copy their drug group membership wholesale unless licensed.

Mitigation:

- Use dm+d and public clinical guidance as primary sources.
- Build independent curation.
- Record sources for each decision.

### 12.2 False negatives

The highest risk is missing patients.

Examples:

- Lithium citrate missed if only Lithium carbonate is selected.
- Valproic acid missed if only Sodium valproate is selected.
- Combination metformin products missed if the include-combinations policy is off for diabetes audit.
- Entresto missed if valsartan monitoring does not include combinations.

Mitigation:

- Regression tests for known high-risk misses.
- Review every group with a patient-safety lens.

### 12.3 False positives

Some broad VTMs include products outside the clinical intent.

Examples:

- Ciclosporin eye drops in systemic ciclosporin monitoring.
- Topical mycophenolate in systemic immunosuppressant monitoring.
- Non-systemic corticosteroids in systemic steroid monitoring.

Mitigation:

- Route/formulation filters.
- VMP-level exclusions.
- Explain exclusions in UI and audit.

### 12.4 Monthly drift

New dm+d products can enter an approved group without being reviewed.

Mitigation:

- Monthly diff workflow.
- High-risk group review gates.
- Release notes.

### 12.5 Mixing clinical scope with execution scope

The UI may display VMPs, but the prescription issue match must use AMPs.

Mitigation:

- Always store clinical scope and execution scope separately.
- Fail closed if AMP expansion fails.
- Do not include VMPP or AMPP in issue matching for our system.

### 12.6 Overloading the VTM resolver

Trying to force all clinical grouping into the resolver will make it unsafe.

Mitigation:

- Keep the resolver deterministic.
- Put clinical judgement in curated groups and monitoring rules.

---

## 13. Build Strategy

### Recommended approach

Build an internal medication knowledge base, but keep it small and governed initially.

Use three content types:

1. **Generated definitions:** pure VTM resolver output, no manual curation.
2. **Curated medication groups:** human-reviewed concept sets.
3. **Monitoring rules:** clinical rules attached to groups.

This lets us start with deterministic dm+d behaviour and add curated content only where needed.

### What not to do

Do not:

- Hard-code product names into report SQL.
- Use ingredient search as the default user pathway.
- Treat a single BNF code as sufficient to define a monitoring group without pharmacist confirmation. BNF codes generate candidates; they do not make clinical boundary decisions.
- Use BNF codes for groups whose clinical concept spans multiple BNF chapters without explicitly adding the cross-chapter VTMs (e.g., DMARDs + chapter 8 immunosuppressants).
- Silently merge clinically distinct VTMs.
- Silently exclude products from a VTM without explanation.
- Copy Ardens or EMIS group membership without a licence.
- Match prescription issues against VMPs only.
- Include VMPP or AMPP in issue matching for our system.

---

## 14. Practical Next Steps

1. Define the first 15 MVP medication groups.
2. For each group, generate an initial candidate VTM/VMP/AMP set from dm+d.
3. Build a simple review spreadsheet or markdown table for clinical review.
4. Add SQL-backed regression tests for known edge cases.
5. Create a simple versioned schema for curated medication groups.
6. Add a monthly dm+d diff report.
7. Build a minimal UI preview showing:
   - included VTMs,
   - included VMPs,
   - excluded VMPs,
   - AMP execution count,
   - monitoring rule,
   - source references.
8. Only after this is stable, consider broader EMIS-like browsing groups.

---

## 15. Sources

- [Ardens EMIS Prescribing Monitoring Searches](https://support-ew.ardens.org.uk/support/solutions/articles/31000167685-2-20-prescribing-monitoring-searches), reviewed 2026-06-26.
- [Ardens SystmOne Drug Monitoring](https://support.ardens.org.uk/support/solutions/articles/31000059042-drug-monitoring), reviewed 2026-06-26.
- [Hero Health EMIS MKB support article](https://www.herohealthsoftware.net/primary-care/emis-support/article/what-is-the-emis-web-medical-knowledge-base-mkb-and-how-does-it-support-prescribing-decisions), reviewed 2026-06-26. External EMIS support material, not a first-party EMIS specification.
- [Primary Care IT medication issue details article](https://support.primarycareit.co.uk/portal/en-gb/kb/articles/how-to-see-details-of-medication-issued), reviewed 2026-06-26. External support material referencing EMIS Drug Group sorting.
- Local dm+d SQL Server analysis, `silentpriory\SQLEXPRESS`, database `dmd`, June 2026 release.
- Local notes in [medication-search-background.md](medication-search-background.md), [2026-06-23-vtm-medication-search-algorithm.md](2026-06-23-vtm-medication-search-algorithm.md), and the drug-specific VTM analysis files in this folder.
- [bnf-grouper-feasibility-analysis.md](bnf-grouper-feasibility-analysis.md) — full BNF code coverage test against all 15 MVP groups, June 2026 data, with corrected 8-character code queries and group-by-group verdict table.

---

## Appendix A - SQL Used for Scale Metrics

```sql
WITH active_vtms_with_vmp AS (
    SELECT t.vtmid, t.nm
    FROM dbo.vtm t
    WHERE t.invalid = 0
      AND EXISTS (
          SELECT 1
          FROM dbo.vmp v
          WHERE v.vtmid = t.vtmid
            AND v.invalid = 0
      )
),
direct AS (
    SELECT t.vtmid, t.nm AS vtm_name, v.vpid
    FROM active_vtms_with_vmp t
    JOIN dbo.vmp v ON v.vtmid = t.vtmid AND v.invalid = 0
),
direct_counts AS (
    SELECT vtmid, COUNT(DISTINCT vpid) AS direct_vmp_count
    FROM direct
    GROUP BY vtmid
),
ingredient_counts AS (
    SELECT d.vtmid,
           COUNT(DISTINCT vi.isid) AS ingredient_count,
           COUNT(DISTINCT CASE WHEN vi.isid IS NOT NULL THEN d.vpid END)
               AS vmps_with_ingredient_count
    FROM direct d
    LEFT JOIN dbo.vmp_ingredient vi ON vi.vpid = d.vpid
    GROUP BY d.vtmid
),
vtm_ingredients AS (
    SELECT DISTINCT d.vtmid AS input_vtmid, vi.isid
    FROM direct d
    JOIN dbo.vmp_ingredient vi ON vi.vpid = d.vpid
),
expanded AS (
    SELECT DISTINCT vi0.input_vtmid, v.vpid, v.vtmid AS matched_vtmid
    FROM vtm_ingredients vi0
    JOIN dbo.vmp_ingredient vi ON vi.isid = vi0.isid
    JOIN dbo.vmp v ON v.vpid = vi.vpid AND v.invalid = 0
),
expanded_counts AS (
    SELECT input_vtmid AS vtmid,
           COUNT(DISTINCT vpid) AS expanded_vmp_count,
           COUNT(DISTINCT CASE WHEN matched_vtmid <> input_vtmid THEN vpid END)
               AS extra_vmp_count
    FROM expanded
    GROUP BY input_vtmid
),
classified AS (
    SELECT t.vtmid, t.nm,
           CASE WHEN t.nm LIKE '% + %' OR t.nm LIKE 'Co-%'
                THEN 1 ELSE 0 END AS named_combo_guard,
           dc.direct_vmp_count,
           COALESCE(ec.expanded_vmp_count, 0) AS expanded_vmp_count,
           COALESCE(ec.extra_vmp_count, 0) AS extra_vmp_count,
           ic.ingredient_count,
           ic.vmps_with_ingredient_count
    FROM active_vtms_with_vmp t
    JOIN direct_counts dc ON dc.vtmid = t.vtmid
    JOIN ingredient_counts ic ON ic.vtmid = t.vtmid
    LEFT JOIN expanded_counts ec ON ec.vtmid = t.vtmid
)
SELECT 'active_vtms_total' AS metric, COUNT(*) AS value
FROM dbo.vtm
WHERE invalid = 0
UNION ALL
SELECT 'active_vtms_with_active_vmp', COUNT(*)
FROM active_vtms_with_vmp
UNION ALL
SELECT 'active_vmps', COUNT(*)
FROM dbo.vmp
WHERE invalid = 0
UNION ALL
SELECT 'active_amps', COUNT(*)
FROM dbo.amp
WHERE invalid = 0
UNION ALL
SELECT 'named_combo_guard_vtms_with_vmp', COUNT(*)
FROM classified
WHERE named_combo_guard = 1
UNION ALL
SELECT 'non_combo_vtms_with_vmp', COUNT(*)
FROM classified
WHERE named_combo_guard = 0
UNION ALL
SELECT 'non_combo_with_extra_vmp_expansion', COUNT(*)
FROM classified
WHERE named_combo_guard = 0 AND extra_vmp_count > 0
UNION ALL
SELECT 'non_combo_no_extra_expansion_has_ingredients', COUNT(*)
FROM classified
WHERE named_combo_guard = 0 AND extra_vmp_count = 0 AND ingredient_count > 0
UNION ALL
SELECT 'vtms_all_direct_vmps_no_ingredients', COUNT(*)
FROM classified
WHERE vmps_with_ingredient_count = 0
UNION ALL
SELECT 'vtms_partial_direct_vmp_ingredient_coverage', COUNT(*)
FROM classified
WHERE vmps_with_ingredient_count > 0
  AND vmps_with_ingredient_count < direct_vmp_count;
```

```sql
WITH vtm_amp_counts AS (
    SELECT t.vtmid, t.nm,
           COUNT(DISTINCT v.vpid) AS vmp_count,
           COUNT(DISTINCT a.apid) AS amp_count
    FROM dbo.vtm t
    JOIN dbo.vmp v ON v.vtmid = t.vtmid AND v.invalid = 0
    LEFT JOIN dbo.amp a ON a.vpid = v.vpid AND a.invalid = 0
    WHERE t.invalid = 0
    GROUP BY t.vtmid, t.nm
)
SELECT TOP 20 nm AS vtm_name, vmp_count, amp_count
FROM vtm_amp_counts
ORDER BY amp_count DESC, vmp_count DESC;
```
