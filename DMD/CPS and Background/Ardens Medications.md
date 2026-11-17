# Ardens Medication Monitoring and Prescribing Searches

Date reviewed: 2026-06-25

Purpose: summarise what Ardens appears to provide for medication monitoring and prescribing searches, then translate that into implications for our dm+d / VTM-first medication search work.

## Executive summary

Ardens treats medication search as part of an operational monitoring workflow, not just as a way to find products or build a static codelist.

The pattern across the Ardens material is:

1. Define the medicine cohort.
2. Attach monitoring requirements to that cohort.
3. Separate routine annual monitoring from high-risk or overdue monitoring.
4. Route patients into practical recall or review work queues.
5. Support patient-level action through alerts, templates, and drill-down lists.
6. Provide practice-level oversight through achieved / remaining counts and trends.

For our work, the main point is that the VTM search layer should be able to produce precise, explainable medication cohorts that can then be used by monitoring rules. The search component should not only return product matches. It should preserve the clinician's intent, for example "Amoxicillin including combinations" versus "this exact named combination only", because downstream monitoring and safety searches depend on that intent. It also needs to expand the final VMP scope to AMPs, because prescription records are normally matched at actual product level rather than at VMP abstraction level.

## Ardens components found

### 1. EMIS Web Prescribing - Monitoring searches

Source: [Ardens Prescribing Monitoring Searches](https://support-ew.ardens.org.uk/support/solutions/articles/31000167685-2-20-prescribing-monitoring-searches)

Ardens provides a search folder under:

`Population Reporting > Ardens Searches > 2.20 Prescribing - Monitoring`

The article describes this as a suite to help practices monitor patients prescribed medicines that require regular tests or reviews. Examples given include ACE inhibitors, levothyroxine, anticoagulants, and DMARDs.

The folder is organised around:

- Patients needing monitoring or review.
- Annual drug monitoring.
- High-risk drug monitoring.
- Patients overdue blood monitoring.
- Patients overdue non-blood monitoring.
- Patients needing secondary-care or hospital prescribing ownership reviewed.
- Non-responders and partially completed monitoring.
- Register and monitoring breakdowns by drug.

The search results are not presented only as "patients on drug X". They are routed into work queues that a practice can action.

### 2. Blood Test Due Analyser

Source: [Blood Test Due Analyser](https://support-ew.ardens.org.uk/support/solutions/articles/31000165373-blood-test-due-analyser)

The Blood Test Due Analyser identifies blood tests due because of:

- Long-term condition monitoring.
- Prescribed medication monitoring.
- Diary recall monitoring.

It also includes some non-blood monitoring linked to medication review, including observations such as ECG, BMI, blood pressure, weight, and heart rate.

Important design point: Ardens states that this tool is intended for steady-state monitoring. It is not intended to manage patients who have just started a medication or are undergoing dose titration. That is a key distinction for our design. A monitoring rule needs a lifecycle state, not just a drug cohort.

### 3. Prescribing alerts

Source: [Ardens Prescribing Alerts](https://support-ew.ardens.org.uk/support/solutions/articles/31000170391-2-22-prescribing-alerts)

Ardens has a separate folder for prescribing alerts. These searches identify patients on medicines or treatments that may need review because of a safety issue. The folder is grouped by condition area, and some searches have child searches for the specific safety issue.

This matters because medication search needs to support more than one downstream purpose:

- Routine monitoring.
- Safety alert review.
- Contraindication or risk searches.
- Recall.
- Audit.
- Review workload management.

The same medication cohort definition may be reused across several different clinical workflows.

### 4. CAS alert searches

Source: [Ardens CAS Alerts](https://support-ew.ardens.org.uk/support/solutions/articles/31000163305-2-15-prescribing-cas-alerts)

Ardens includes prescribing searches for national safety alerts. The article refers to searches for recalls, special container reclassification, and supply disruption.

This reinforces that the medication selection layer should be auditable and versioned. If a search is used for a safety alert, the practice needs to know exactly which medicine concept set and which dm+d release or reference set was used.

### 5. SystmOne high-risk drug monitoring

Source: [Ardens SystmOne Drug Monitoring](https://support.ardens.org.uk/support/solutions/articles/31000059042-drug-monitoring)

The SystmOne article describes alerts and reports for high-risk medicines. It includes patient-level pop-up reminders when records are retrieved and notes that intervals are based on national guidance such as BNF, NICE, SPS, and specialist organisations.

It also describes:

- Annual monitoring split by long-term condition status.
- Accessibility or special cohorts such as care home, housebound, dementia, learning disability, and end of life.
- Removal from monitoring using codes that indicate secondary-care monitoring.
- Inclusion of some acute medicines when the medication end date is after today.
- Special handling for some medicines such as anticoagulants, corticosteroids, and azithromycin.
- Monitoring intervals that are not locally editable in the standard content, with some limited template support for stable lithium, tacrolimus, and ciclosporin monitoring.

This is useful for our design because it shows that prescribing monitoring is partly a medication cohort problem and partly a care ownership / workflow problem.

### 6. Pharmacy templates and patient-level workflow

Source: [Ardens Pharmacy](https://support-ew.ardens.org.uk/support/solutions/articles/31000172168-pharmacy)

The Ardens pharmacy material describes templates for:

- Drug monitoring.
- Drug review.
- Medication safety review.
- Creatinine clearance review.
- DRUM review.

The Drug Monitoring template is described as adapting to the patient's prescribed drugs, showing relevant drug pages and using visual status indicators for completed or missing requirements.

This suggests a useful product direction for us: after the user has selected a drug or cohort, the UI should expose why a patient is included, what is missing, and which action is expected.

### 7. Ardens Manager reporting

Source: [Ardens Manager - Prescribing Drug Monitoring](https://knowledge.ardens.org.uk/articles/ardens-manager/prescribing-drug-monitoring)

Ardens Manager provides a practice or PCN-level reporting view. It tracks monitoring completed and monitoring still remaining, with patient lists, progress views, trends, and exports.

Relevant features include:

- Achieved and remaining columns.
- Drill-down patient lists.
- A "show remaining only" type workflow.
- Medication-type monitoring reports.
- Trend charts and local targets.

This is a different layer from the medication selector, but it tells us what the selector must feed: stable, explainable cohorts that can support counts, trends, exports, and audit.

### 8. Diary recall system

Sources:

- [Ardens Diary Recall System Codes](https://support-ew.ardens.org.uk/support/solutions/articles/31000157550-ardens-diary-recall-system-codes)
- [Ardens Diary Recall Webinar](https://vimeo.com/498023969)
- [Ardens Recall Systems Overview](https://vimeopro.com/ardens/webinars/video/920477171)

The diary recall material shows that Ardens uses recall coding across several workflows, including blood tests, hospital tests, injections, procedures, long-term condition reviews, and medication-related monitoring. Examples in the code list include DOAC monitoring, high-risk anti-rheumatic drug monitoring, hypertension monitoring, lithium monitoring, and MGUS monitoring.

For our purposes, the key point is that a medication search result may need to become a recall instruction or a monitoring register, not just a one-off query result.

## Medication and monitoring categories seen

The sources above mention or imply the following monitoring groups. This is not a full Ardens content inventory, but it gives useful coverage for design.

- ACE inhibitors and related renal / electrolyte monitoring.
- Levothyroxine and thyroid monitoring.
- Anticoagulants, including DOAC monitoring.
- DMARDs and high-risk anti-rheumatic drug monitoring.
- Lithium.
- Tacrolimus.
- Ciclosporin.
- Steroids.
- Amiodarone.
- Methotrexate.
- Warfarin.
- Long-term NSAIDs, especially in higher-risk patients.
- Antipsychotics in dementia.
- B12 injections.
- Denosumab.
- GnRH analogues.
- MGUS monitoring.

This list should be treated as a prompt for our own catalogue, not as an authoritative Ardens list. The authoritative content sits inside Ardens search folders, templates, and reference materials.

## Public examples found for "Register and Monitoring - by drug"

The EMIS article publicly shows the folder names, but most individual report names are hidden inside screenshots or customer-local reporting suites. I searched the public web and found examples from four useful sources:

- The official Ardens EMIS article, including the "Register and Monitoring - by drug" screenshots.
- A public NHS Surrey/Sussex drug-monitoring audit workbook that references `2.20 Prescribing - Monitoring (Ardens v1.5)`.
- A Birmingham and Solihull DOAC resource pack that shows Ardens DOAC monitoring examples.
- The official Ardens SystmOne drug-monitoring article, which exposes equivalent `Drugs | Annual`, `Drugs | Anticoagulants`, `Drugs | DMARDS`, and `Drugs | HRD` examples.

Evidence grading used below:

- `Exact EMIS`: an EMIS by-drug report name was found in a public source.
- `Ardens SystmOne equivalent`: an equivalent Ardens SystmOne drug-monitoring report or template was publicly visible.
- `Adjacent Ardens evidence`: Ardens evidence exists for the medicine or recall type, but I did not find a public EMIS by-drug report name.
- `Technical`: likely a support folder rather than a patient-facing monitoring category.

| Folder shown in EMIS screenshot | Public examples found | Evidence grade | Notes |
| --- | --- | --- | --- |
| ADHD | `On Atomoxetine`, `On Dexamfetamine`, `On Guanfacine`, `On Lisdexamfetamine`, `On Methylphenidate`; monitoring examples include no BP, HR, height, weight, or BMI in the last 6 months. | Exact EMIS and Ardens SystmOne equivalent | Found in the public NHS Surrey/Sussex audit workbook. SystmOne equivalent examples include `No BP, HR, height or weight in last 6m + HRD Primary care monitoring`. |
| Anticoagulants | DOAC reports split by CrCl band, for example no CrCl in the relevant interval for CrCl 15-24, 25-34, 35-44, 45-54, 55-59, and missing FBC, U&E, or LFT in the matching interval. | Official EMIS screenshot and external NHS DOAC resource | The Birmingham and Solihull DOAC pack shows the path `2.20 Prescribing-Monitoring > Anticoagulants > More detail` and example DOAC report names. |
| Cardiovascular | `On Amiodarone`, no U&E, LFT, or TFT in last 6 months; `On Dronedarone`, no U&E or LFT in last 1 year. | Exact EMIS | Found in the public NHS Surrey/Sussex audit workbook. SystmOne also shows annual monitoring examples such as ACE/ARB, digoxin, thiazide diuretic, ivabradine, and statin. |
| Dermatology | I did not find a public EMIS by-drug report name for this subfolder. Public Ardens-adjacent examples include `Dermatology review` in Diary Recall, plus immunomodulator monitoring examples that may be relevant clinically but are filed elsewhere in public evidence. | Adjacent Ardens evidence | Treat this as a gap. The public screenshot proves the folder exists, but I could not confirm a specific EMIS report name from public pages. |
| Diabetes | `On Metformin`, no U&E in last 1 year. Pharmacy material also exposes `Metformin Initiation` and `SGLT-2 Inhibitor Initiation` templates. | Ardens SystmOne equivalent and Ardens template evidence | I did not find a public EMIS by-drug report name under the Diabetes folder. |
| DMARDs & Immunosuppressants | `On Azathioprine`, no FBC, U&E, or LFT in last 12 weeks; `On Ciclosporin`, no BP in last 4 weeks and no FBC, U&E, LFT, HbA1c/FBG in last 4 weeks; `On Hydroxychloroquine`, no retinopathy screening in last 1 year if taken for more than 5 years; `On Leflunomide`, no BP/weight or no FBC/U&E/LFT in last 12 weeks; `On Mercaptopurine`, `On Methotrexate`, `On Mycophenolate`, `On Penicillamine`, `On Sulfasalazine`, `On Tacrolimus`. | Exact EMIS and Ardens SystmOne equivalent | This is the richest public set. Found in the audit workbook and corroborated by SystmOne drug monitoring screenshots/templates. |
| Endocrine | `On thyroid hormones`, no TSH in last 1 year; testosterone examples include no testosterone level, no FBC, and no PSA in relevant cohorts. | Ardens SystmOne equivalent | Official Ardens text also names levothyroxine as included in prescribing monitoring. |
| Gastroenterology | `On aminosalicylate (excluding sulfasalazine)`, no U&E in last 1 year. | Ardens SystmOne equivalent | I did not find a public EMIS by-drug report name under the Gastroenterology folder. |
| Genitourinary | `On mirabegron`, no BP in last 1 year. PSA monitoring register and alerts are separately documented by Ardens under men's health rather than the EMIS by-drug folder. | Ardens SystmOne equivalent and adjacent Ardens evidence | I did not find a public EMIS by-drug report name under the Genitourinary folder. |
| Haematology | Public direct evidence for the EMIS by-drug folder was not found. Adjacent examples include Ardens Diary Recall blood-test items such as ferritin, serum folate, B12 blood test, and MGUS monitoring tests. An external Greener Practice page says Ardens users can search for `Review appropriateness of blood test in last 3m - issue of oral iron`. | Adjacent Ardens evidence plus external reference to an Ardens search | Treat this as a gap until confirmed inside Ardens or from a screenshot. |
| Mental Health | `On Lithium`, no lithium level in last 12 weeks, no U&E/Ca/TFT in last 6 months, and no weight in last 6 months. Antipsychotic annual examples include no BMI/weight, no ECG, no FBC/U&E/LFT/HbA1c/FBG/lipids, and no prolactin. | Exact EMIS and Ardens SystmOne equivalent | Lithium examples are exact EMIS from the audit workbook. Antipsychotic examples are SystmOne annual monitoring examples. |
| Musculoskeletal | `On Denosumab`, no calcium in last 6 months. | Exact EMIS and Ardens SystmOne equivalent | Found in the audit workbook and corroborated by SystmOne annual/HRD monitoring examples. |
| Neurology | `On Tolcapone`, no LFT in last 8 weeks; `On Riluzole`, no FBC or LFT in last 1 year; valproate examples include childbearing-potential review, no annual risk acknowledgement form / pregnancy prevention programme, and annual BMI/FBC/LFT examples; `On phenytoin >5y`, no FBC, U&E, LFT, Ca, or vitamin D in last 5 years. | Exact EMIS and Ardens SystmOne equivalent | Tolcapone, riluzole, and valproate were found in the audit workbook. Phenytoin and annual valproate monitoring were visible in SystmOne screenshots. |
| Renal | ACE/ARB monitoring example: `On ACE or ARB`, no U&E in last 1 year. | Ardens SystmOne equivalent | The official Ardens articles name ACE inhibitors as included. I did not find a public EMIS by-drug report name under the Renal folder. |
| Respiratory | `On theophylline`, no theophylline levels in last 1 year. Corticosteroid template and steroid-card related searches are also publicly documented. | Ardens SystmOne equivalent and adjacent Ardens evidence | I did not find a public EMIS by-drug report name under the Respiratory folder. |
| Vitamins | Public direct evidence for the EMIS by-drug folder was not found. Adjacent Ardens evidence includes Diary Recall entries for B12 injection, vitamin D injection, vitamin B12 blood test, and vitamin D blood test. | Adjacent Ardens evidence | Treat this as a gap until confirmed inside Ardens or from a screenshot. |
| Women's Health | `On CHC`, no BMI or BP in last 1 year. Diary Recall also includes HRT review and contraception-related recalls. | Ardens SystmOne equivalent and adjacent Ardens evidence | I did not find a public EMIS by-drug report name under the Women's Health folder. |
| ZDenominator | Examples of denominator-style reports include `Had Azathioprine in last 6m`, `Had Leflunomide in last 6m`, `Had Methotrexate in last 6m`, and `On [drug]` register rows. | Technical | This appears to be a technical/support folder, not a clinical category. It likely contains denominator searches used by the visible reports. |

### What this means for our medication-search design

The public examples confirm that Ardens uses several repeatable search patterns:

- `On [drug]` register or denominator.
- `On [drug] excluding secondary care monitoring`.
- `On [drug]` plus missing blood monitoring in a defined interval.
- `On [drug]` plus missing non-blood monitoring, for example BP, BMI, weight, ECG, heart rate, or retinopathy screening.
- Drug-specific interval logic, for example DOAC monitoring frequency varying by CrCl band.
- Separate ownership logic for primary-care monitoring versus secondary-care monitoring.

That maps well to our proposed split between:

1. dm+d/VTM cohort definition.
2. Monitoring rule.
3. Patient workflow bucket.
4. Audit snapshot.

The gaps also matter. Some EMIS folders are publicly visible only as folder names, not as expanded report names. For our design work, we should not hard-code a presumed Ardens drug list from the public internet. We should model the patterns and leave the actual clinical rules as curated, versioned content.

## Design implications for our VTM medication search

### Separate cohort definition from monitoring rules

The current VTM work is primarily about reliably resolving a selected medicine to the right dm+d products. Ardens shows that this should feed a separate monitoring-rule layer.

Suggested separation:

- Medication cohort: which VTMs, VMPs, AMPs, ingredients, and combinations are included.
- Monitoring rule: which test, observation, review, or recall applies.
- Workflow rule: who owns the monitoring, how overdue patients are handled, and where they appear operationally.

This keeps the VTM search algorithm reusable across routine monitoring, safety alerts, prescribing reviews, and audit.

### Add an AMP execution layer

The wireframes currently explain the associated VMPs well, but VMPs are not enough for execution if prescription records store AMPs.

The resolver should therefore carry two related sets:

- Clinical scope: VTM and VMPs, used for display, explanation, ingredient pivoting, and audit.
- Prescription match scope: AMPs, used to match the actual prescribing records.

VMPP and AMPP data may still exist as separate adjunct pack metadata, but it should not be part of the medication expansion used to identify prescription issues in our system.

This is especially important for Ardens-style monitoring searches. A report such as `On Methotrexate` is clinically defined at drug level, but the patient is found because their prescription row matches one of the actual methotrexate products. If the UI stops at VMPs, the search can look correct while failing to match the stored prescribing data.

### Preserve search intent

Our named-combination guard work is directly relevant here.

Ardens-style searches need to know whether the user intended:

- A parent VTM and sensible expansions.
- A single named combination.
- Ingredient-level expansion.
- Direct product matching only.
- Inclusion or exclusion of branded and combination products.

If this intent is flattened too early, downstream monitoring can over-collect patients. The Dithranol + Zinc oxide + Salicylic acid case is a good example: an ingredient pivot can turn one specific named combination into a broad topical-product cohort.

### Support "register and monitoring by drug"

Ardens includes a by-drug register and monitoring view. Our UI should consider a similar output shape:

- Drug or drug group.
- Number of patients on the medicine.
- Number of VMPs in clinical scope.
- Number of AMPs in prescription match scope.
- Number with monitoring complete.
- Number overdue.
- Number partially complete.
- Number excluded or owned by secondary care.
- Drill-down to product and patient inclusion reason.

This would test the medication selector in a more realistic operating mode than a simple result count.

### Include blood and non-blood monitoring metadata

Ardens monitoring is not limited to blood tests. The model should be able to represent:

- Blood tests.
- Blood pressure.
- BMI.
- Weight.
- Heart rate.
- ECG.
- Creatinine clearance or renal function calculations.
- Review completion.
- Recall status.

The medication search algorithm does not need to perform these checks, but it should produce a cohort that can be joined cleanly to these requirements.

### Model steady-state separately from initiation and titration

The Blood Test Due Analyser distinction is important. A patient recently started on a medicine or currently titrating may need a different schedule from someone on stable long-term treatment.

A monitoring rule should therefore include at least:

- Applies to stable therapy.
- Applies after initiation.
- Applies after dose change.
- Applies only if repeated issue or active therapy exists.
- Excluded if therapy has ended.

The medication-search UI could expose this later as a "monitoring context" selector rather than forcing it into the VTM resolver.

### Capture ownership and exclusions

Ardens distinguishes practice-issued medicines, hospital-issued medicines, and secondary-care-monitored medicines. It also uses codes to remove patients from some monitoring searches where another service owns monitoring.

Our system should not only ask "is the patient on this medicine?" It should also support:

- Issued by practice.
- Issued by hospital or recorded as hospital.
- Monitored by practice.
- Monitored by secondary care.
- Temporarily excluded.
- Permanently excluded.
- Exclusion requires review after a period.

This is especially important for high-risk drugs where the practice may prescribe but not own specialist monitoring.

### Make workflow buckets mutually understandable

Ardens material indicates that patients are routed into practical work queues such as annual monitoring, high-risk monitoring, overdue blood monitoring, overdue non-blood monitoring, partial monitoring, non-responders, and special accessibility cohorts.

For our design, each patient or product result should be able to explain:

- Why it is included.
- Which workflow bucket it entered.
- Which more specific result groups it matched.
- Which bucket takes priority if multiple rules match.

This avoids "same patient appears everywhere" behaviour, which makes monitoring searches hard to action.

### Add audit and versioning

Ardens references national guidance and maintains content centrally. If we build our own algorithmic medication cohorts, we need equivalent audit metadata:

- dm+d release.
- SNOMED CT release if relevant.
- Algorithm version.
- Guard rules applied.
- Source references for monitoring intervals.
- Date the cohort was generated.
- Count of direct matches, ingredient-expanded matches, named-combination protected matches, and no-ingredient fallbacks.

This would help clinicians trust the result and would make changes between releases reviewable.

## Gaps to add to our wireframe set

The current wireframes cover the core medication search happy path and named-combination guard behaviour. Based on the Ardens review, I would add these screens or panels.

### 1. Monitoring rule attachment panel

After selecting a VTM or drug group, show the monitoring rules attached to that selection.

Fields:

- Monitoring type.
- Test or observation.
- Interval.
- Applies to stable therapy, initiation, or titration.
- Source reference.
- Patient count affected.

### 2. Register and monitoring by drug

A table grouped by selected drug or drug group.

Columns:

- Patients on drug.
- Monitoring complete.
- Overdue blood monitoring.
- Overdue non-blood monitoring.
- Partial monitoring.
- Secondary-care monitored.
- Non-responders.

### 3. Patient inclusion explanation

A drill-down panel for a selected patient.

Fields:

- Matched VTM / VMP / product.
- Matched AMP where the prescription row is product-coded.
- Match route, such as direct VTM, ingredient expansion, or named-combination direct-only.
- Last issue date.
- Active or ended therapy.
- Monitoring rule triggered.
- Missing item.
- Current workflow bucket.

### 4. Secondary-care ownership review

A panel for medicines that are prescribed, issued, or monitored outside the practice.

States:

- Practice issue and practice monitoring.
- Practice issue and secondary-care monitoring.
- Hospital issue recorded.
- Hospital issue needs review.
- Monitoring exclusion active.
- Monitoring exclusion expired and needs reconfirmation.

### 5. Steady-state versus initiation / titration mode

A selector that makes the monitoring context explicit.

Options:

- Stable long-term therapy.
- Recently started.
- Dose changed.
- Acute course with future end date.
- Ended therapy.

This should be separate from medicine selection because the same VTM can have different monitoring requirements depending on lifecycle state.

### 6. Recall and non-responder workflow

A work-queue view showing where patients are in the recall process.

Fields:

- Invite due.
- Invite sent.
- Second invite due.
- Third invite due.
- Non-responder.
- Needs home visit or accessibility consideration.
- Monitoring completed after recall.

### 7. Audit snapshot

A compact report view for a saved medication cohort.

Fields:

- Search name.
- dm+d release.
- Algorithm version.
- Guard rules used.
- Source references.
- Total patients.
- Achieved count.
- Remaining count.
- Export date.

## Candidate data objects

These are not implementation commitments, but they map the Ardens-style workflow into objects we could support.

### MedicationDefinition

- `id`
- `name`
- `selection_kind`
- `vtmid`
- `vmpid`
- `ingredient_ids`
- `include_combinations`
- `named_combination_guard`
- `direct_only`
- `dm_d_release`
- `algorithm_version`

### MedicationCohortResult

- `medication_definition_id`
- `vmp_id`
- `amp_id`
- `product_kind`
- `match_route`
- `input_vtmid`
- `matched_vtmid`
- `matched_ingredient_id`
- `guard_applied`
- `explanation`

### MonitoringRule

- `id`
- `drug_group`
- `medication_definition_id`
- `monitoring_item`
- `monitoring_item_type`
- `interval`
- `applies_to_stable_therapy`
- `applies_after_initiation`
- `applies_after_dose_change`
- `minimum_age`
- `maximum_age`
- `guidance_source`
- `guidance_version`

### PatientMonitoringStatus

- `patient_id`
- `monitoring_rule_id`
- `matched_vmp_id`
- `matched_amp_id`
- `last_issue_date`
- `therapy_status`
- `last_result_date`
- `due_date`
- `overdue_status`
- `workflow_bucket`
- `missing_items`
- `secondary_care_monitoring_status`
- `recall_status`

### MonitoringAuditSnapshot

- `snapshot_date`
- `medication_definition_id`
- `dm_d_release`
- `algorithm_version`
- `total_patients`
- `achieved_count`
- `remaining_count`
- `overdue_blood_count`
- `overdue_non_blood_count`
- `secondary_care_count`
- `non_responder_count`

## Things to validate locally

1. Which monitoring drug groups we can derive from dm+d alone, and which require curated clinical groupings.
2. Whether "issued by hospital" and "monitored by secondary care" are available as structured local EHR codes in the intended source system.
3. Whether VTM-level matching is enough for all monitoring rules, or whether some rules require VMP, route, formulation, strength, or dose.
4. How to handle medicines that share ingredients but have very different monitoring purposes.
5. How to version monitoring guidance independently from dm+d releases.
6. Whether patient workflow buckets should be mutually exclusive, prioritised, or multi-label.

## Practical recommendation

Adopt the Ardens pattern as the target workflow shape, but keep our core medication-search layer narrower and more deterministic.

The immediate next step should be to extend the existing VTM wireframes with a monitoring-oriented result layer:

1. A saved medication cohort with its match explanation.
2. A by-drug monitoring register view.
3. A patient-level "why included and what is missing" panel.
4. A secondary-care ownership / exclusion panel.
5. An audit snapshot showing dm+d release, algorithm version, and guard behaviour.

That would let us prove that the VTM resolver can support Ardens-style operational searches without mixing clinical monitoring rules directly into the matching algorithm.

## Sources

- [Ardens Prescribing Monitoring Searches](https://support-ew.ardens.org.uk/support/solutions/articles/31000167685-2-20-prescribing-monitoring-searches), reviewed 2026-06-25.
- [Ardens Blood Test Due Analyser](https://support-ew.ardens.org.uk/support/solutions/articles/31000165373-blood-test-due-analyser), reviewed 2026-06-25.
- [Ardens Prescribing Alerts](https://support-ew.ardens.org.uk/support/solutions/articles/31000170391-2-22-prescribing-alerts), reviewed 2026-06-25.
- [Ardens CAS Alerts](https://support-ew.ardens.org.uk/support/solutions/articles/31000163305-2-15-prescribing-cas-alerts), reviewed 2026-06-25.
- [Ardens SystmOne Drug Monitoring](https://support.ardens.org.uk/support/solutions/articles/31000059042-drug-monitoring), reviewed 2026-06-25.
- [Ardens Pharmacy](https://support-ew.ardens.org.uk/support/solutions/articles/31000172168-pharmacy), reviewed 2026-06-25.
- [Ardens Manager - Prescribing Drug Monitoring](https://knowledge.ardens.org.uk/articles/ardens-manager/prescribing-drug-monitoring), reviewed 2026-06-25.
- [Ardens Diary Recall System Codes](https://support-ew.ardens.org.uk/support/solutions/articles/31000157550-ardens-diary-recall-system-codes), reviewed 2026-06-25.
- [Ardens Diary Recall System Introduction](https://support-ew.ardens.org.uk/support/solutions/articles/31000156544-diary-recall-system-introduction), reviewed 2026-06-25.
- [Ardens Diary Recall Webinar](https://vimeo.com/498023969), reviewed 2026-06-25.
- [Ardens Recall Systems Overview](https://vimeopro.com/ardens/webinars/video/920477171), reviewed 2026-06-25.
- [NHS Surrey/Sussex Drug Monitoring Audit workbook](https://int.sussex.ics.nhs.uk/wp-content/uploads/2022/10/Drug-Monitoring-Audit-Emis-SystmOne-v2-2023.xlsx), reviewed 2026-06-25. External NHS workbook referencing Ardens v1.5 searches.
- [Birmingham and Solihull DOAC resource pack](https://www.birminghamandsurroundsformulary.nhs.uk/docs/files/Practice%20processes%20to%20support%20safe%20prescribing%20of%20DOACs.pdf), reviewed 2026-06-25. External NHS guidance showing Ardens DOAC monitoring search examples.
- [Greener Practice - Iron Appropriate Prescribing](https://www.greenerpractice.co.uk/project/iron-appropriate-prescribing/), reviewed 2026-06-25. External page that references an Ardens oral-iron search.
- [Ardens PSA Monitoring](https://support.ardens.org.uk/support/solutions/articles/31000169557-psa-monitoring), reviewed 2026-06-25.
- [Virtual Pharmacist - High Risk Drug Monitoring in Primary Care](https://virtualpharmacist.co.uk/resources/high-risk-drug-monitoring-primary-care/), reviewed 2026-06-25. External context only, not an Ardens source.
