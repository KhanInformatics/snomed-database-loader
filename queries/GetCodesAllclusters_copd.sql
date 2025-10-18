USE SNOMEDCT;
GO

-- Get SNOMED codes for selected PCD COPD clusters
-- Replace the VALUES below with your exact COPD cluster tuples (Cluster_ID, Cluster_Description, PCD_Refset_ID)

DECLARE @ClusterList TABLE (
    Cluster_ID           NVARCHAR(50),
    Cluster_Description  NVARCHAR(300),
    PCD_Refset_ID        NVARCHAR(50)
);

-- Paste COPD cluster tuples here
INSERT INTO @ClusterList (Cluster_ID, Cluster_Description, PCD_Refset_ID)
VALUES
    ('ABPMDEC_COD','Codes indicating patient has chosen not to undertake ambulatory blood pressure monitoring (ABPM)','999028531000230107'),
    ('ACEDEC_COD','Codes indicating the patient has chosen not to receive angiotensin-converting enzyme (ACE) inhibitor','999009011000230109'),
    ('ACE_COD','Angiotensin-converting enzyme (ACE) inhibitor prescription codes','12464201000001109'),
    ('AIIDEC_COD','Codes indicating the patient has chosen not to receive angiotensin II receptor blockers (ARB)','999008011000230100'),
    ('AII_COD','Angiotensin II receptor blockers (ARB) prescription codes','12464301000001100'),
    ('AMPL_COD','Left foot amputation codes','999009531000230107'),
    ('AMPR_COD','Right foot amputation codes','999009611000230103'),
    ('BEMPACIDADV_COD','Codes indicating adverse reaction to bempedoic acid','999028611000230103'),
    ('BEMPACIDALL_COD','Codes indicating allergy to bempedoic acid','999028651000230104'),
    ('BEMPACIDCON_COD','Bempedoic acid contraindicated codes','999028691000230109'),
    ('BEMPACIDDEC_COD','Codes indicating the patient has chosen not to receive bempedoic acid','999028731000230101'),
    ('BEMPACIDNIND_COD','Bempedoic acid not indicated codes','999028811000230104'),
    ('BEMPACID_COD','Bempedoic acid drug codes','175571000001107'),
    ('BLDTESTDEC_COD','Codes indicating the patient has chosen not to receive a blood test','999011611000230101'),
    ('BPDEC_COD','Codes indicating the patient has chosen not to have blood pressure procedure','999012611000230106'),
    ('CHD_COD','Coronary heart disease (CHD) codes','999000771000230107'),
    ('CHOLMAX_COD','Codes indicating the patient is on maximum tolerated cholesterol lowering treatment','999011451000230100'),
    ('CKD1AND2_COD','Chronic kidney disease (CKD) stage 1-2 codes','999004051000230107'),
    ('CKDRES_COD','Chronic kidney disease (CKD) resolved codes','999004171000230102'),
    ('CKD_COD','Chronic kidney disease (CKD) stage 3-5 codes','999004011000230108'),
    ('CLINBP_COD','Blood pressure recording codes excluding home and ambulatory blood pressure','999036281000230108'),
    ('CONABL_COD','Congenital absence of left foot codes','999031371000230106'),
    ('CONABR_COD','Congenital absence of right foot codes','999031411000230105'),
    ('CVDASS2_COD','Cardiovascular disease (CVD) risk assessment codes','999011011000230107'),
    ('DMINVITE_COD','Invite for diabetes care review codes','999012371000230109'),
    ('DMMAX_COD','Codes for maximum tolerated diabetes treatment','999010651000230109'),
    ('DMPCADEC_COD','Codes indicating the patient has chosen not to receive diabetes quality indicator care','999010691000230104'),
    ('DMPCAPU_COD','Codes for diabetes quality indicator care unsuitable for patient','999010731000230107'),
    ('DMRES_COD','Diabetes resolved codes','999003371000230102'),
    ('DMTYPE2_COD','Codes for diabetes type 2','999010771000230109'),
    ('DM_COD','Diabetes mellitus codes','999004691000230108'),
    ('DSEPDEC_COD','Codes indicating the patient has chosen not to have diabetes structured education programme','999010811000230109'),
    ('DSEPPU_COD','Codes for diabetes structured education programme unsuitable for the patient','999010851000230108'),
    ('DSEPSU_COD','Diabetes structured education programme service unavailable codes','999010891000230103'),
    ('DSEP_COD','Referred for diabetes structured education programme codes','999012651000230105'),
    ('EZETIMIBEADV_COD','Codes indicating adverse reaction to ezetimibe','999027491000230106'),
    ('EZETIMIBEALL_COD','Codes indicating allergy to ezetimibe','999027571000230108'),
    ('EZETIMIBECON_COD','Ezetimibe contraindicated codes','999028851000230100'),
    ('EZETIMIBEDEC_COD','Codes indicating the patient has chosen not to receive ezetimibe','999028891000230105'),
    ('EZETIMIBENIND_COD','Ezetimibe not indicated codes','999028971000230101'),
    ('EZETIMIBE_COD','Ezetimibe drug codes','115131000001105'),
    ('FEDEC_COD','Codes indicating the patient has chosen not to have a foot examination','999008531000230102'),
    ('FEPU_COD','Codes for foot examination unsuitable for patient','999008651000230105'),
    ('FHYP_COD','Familial hypercholesterolemia diagnostic codes','999006811000230109'),
    ('FRC_COD','Foot risk classification codes','999008851000230109'),
    ('HOMEAMBBP_COD','Home and ambulatory blood pressure recording codes','999036291000230105'),
    ('HOMEBPDEC_COD','Codes indicating patient chosen not to undertake home blood pressure measurement (HBPM)','999028571000230109'),
    ('HSTRK_COD','Haemorrhagic stroke codes','999012811000230105'),
    ('HTMAX_COD','Codes for maximal blood pressure (BP) therapy','999006651000230109'),
    ('IFCCHBAM_COD','IFCC HbA1c monitoring range codes','999003251000230103'),
    ('INCLISIRANADV_COD','Codes indicating adverse reaction to inclisiran','999029011000230100'),
    ('INCLISIRANALL_COD','Codes indicating allergy to inclisiran','999029051000230101'),
    ('INCLISIRANCON_COD','Inclisiran contraindicated codes','999029091000230106'),
    ('INCLISIRANDEC_COD','Codes indicating the patient has chosen not to receive inclisiran','999029131000230109'),
    ('INCLISIRANNIND_COD','Inclisiran not indicated codes','999029211000230109'),
    ('INCLISIRAN_COD','Inclisiran drug codes','175591000001106'),
    ('LIPIDTHERADV_COD','Adverse reaction to lipid lowering drug codes','999029531000230102'),
    ('LIPIDTHERCON_COD','Lipid therapy contraindicated codes','999027051000230107'),
    ('LIPIDTHERDEC_COD','Lipid therapy declined codes','999026251000230102'),
    ('LIPIDTHERNIND_COD','Lipid therapy not indicated codes','999027131000230104'),
    ('MAL_COD','Codes for microalbuminuria','999013331000230101'),
    ('MILDFRAIL_COD','Mild frailty diagnosis codes','999013531000230106'),
    ('MODFRAIL_COD','Moderate frailty diagnosis codes','999013571000230108'),
    ('NPTDEC_COD','Codes indicating the patient has chosen not to have a neuropathy assessment','999009571000230109'),
    ('NPTPU_COD','Codes for neuropathy assessment unsuitable for patient','999009691000230109'),
    ('PAD_COD','Peripheral arterial disease (PAD) diagnostic codes','999005931000230101'),
    ('PCSK9IADV_COD','Codes indicating adverse reaction to proprotein convertase subtilisin kexin type 9 inhibitor','999027651000230103'),
    ('PCSK9IALL_COD','Codes indicating allergy to proprotein convertase subtilisin kexin type 9 inhibitor','999027691000230108'),
    ('PCSK9ICON_COD','Proprotein convertase subtilisin kexin type inhibitor drug contraindicated codes','999029251000230108'),
    ('PCSK9IDEC_COD','Codes indicating the patient has chosen not to receive proprotein convertase subtilisin kexin type inhibitor drug','999029291000230103'),
    ('PCSK9ININD_COD','Proprotein convertase subtilisin kexin type inhibitor drug not indicated codes','999029371000230109'),
    ('PCSK9I_COD','PCSK9 Inhibitors','115171000001107'),
    ('PRT_COD','Codes for proteinuria','999010331000230106'),
    ('SERFRUC_COD','Serum fructosamine codes','999005691000230107'),
    ('SEVFRAIL_COD','Severe frailty diagnosis codes','999012131000230109'),
    ('STATINDEC_COD','Codes indicating the patient has chosen not to receive a statin prescription','999008051000230101'),
    ('STATINTOL_COD','Codes for intolerance to statins','999027211000230104'),
    ('STAT_COD','Statin codes','12464001000001103'),
    ('STRK_COD','Stroke diagnosis codes','999005531000230105'),
    ('TIA_COD','Transient ischaemic attack (TIA) codes','999005291000230109'),
    ('TXACE_COD','Angiotensin-converting enzyme (ACE) inhibitor contraindications (expiring) codes','999005251000230104'),
    ('TXAII_COD','Angiotensin II receptor blockers (ARB) contraindications (expiring) codes','999004491000230106'),
    ('TXSTAT_COD','Statin contraindications (expiring) codes','999008571000230100'),
    ('XACE_COD','Angiotensin-converting enzyme (ACE) inhibitor contraindications (persisting) codes','999004371000230104'),
    ('XAII_COD','Angiotensin II receptor blockers (ARB) contraindications (persisting) codes','999004331000230101'),
    ('XSTAT_COD','Statin contraindications (persisting) codes','999008291000230103');

-- Diagnostics: show which Cluster_ID / PCD_Refset_ID values in the table match the requested clusters
SELECT
    prc.Cluster_ID,
    prc.PCD_Refset_ID,
    COUNT(*) AS [RowCount]
FROM PCD_Refset_Content_V2 prc
INNER JOIN @ClusterList cl
    ON (
        prc.Cluster_ID = cl.Cluster_ID
        OR REPLACE(prc.PCD_Refset_ID, '^', '') = REPLACE(cl.PCD_Refset_ID, '^', '')
    )
GROUP BY prc.Cluster_ID, prc.PCD_Refset_ID
ORDER BY prc.Cluster_ID;

-- Main result: codes grouped by cluster id/name
SELECT
    cl.Cluster_ID,
    cl.Cluster_Description,
    prc.SNOMED_code,
    prc.SNOMED_code_description
FROM @ClusterList cl
INNER JOIN PCD_Refset_Content_V2 prc
    ON (
        prc.Cluster_ID = cl.Cluster_ID
        OR REPLACE(prc.PCD_Refset_ID, '^', '') = REPLACE(cl.PCD_Refset_ID, '^', '')
    )
    OR REPLACE(prc.PCD_Refset_ID, '^', '') = REPLACE(cl.PCD_Refset_ID, '^', '')
ORDER BY cl.Cluster_ID, prc.SNOMED_code;
