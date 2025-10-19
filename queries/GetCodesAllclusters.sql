USE SNOMEDCT;
GO

-- ================================================================
-- Get SNOMED codes for selected PCD clusters, grouped by cluster
-- Source table: PCD_Refset_Content_V2 (6 columns)
--   Cluster_ID, Cluster_Description, SNOMED_code, SNOMED_code_description,
--   PCD_Refset_ID, Service_and_Ruleset
-- ================================================================

-- Define the clusters of interest (table variable so it can be reused by multiple queries)
DECLARE @ClusterList TABLE (
    Cluster_ID           NVARCHAR(50),
    Cluster_Description  NVARCHAR(300),
    PCD_Refset_ID        NVARCHAR(50)
);

INSERT INTO @ClusterList (Cluster_ID, Cluster_Description, PCD_Refset_ID)
VALUES
('ALCSCRNDEC_COD','Alcohol screening and assessment declined codes','999000251000230105'),
('ALC_COD','Alcohol consumption codes','999007011000230101'),
('ANTIPSYDRUG_COD','Antipsychotic drug codes','999000951000001101'),
('BMI30_COD','Body mass index (BMI) codes >= 30 without an associated BMI value','999011051000230106'),
('BMIDEC_COD','Codes indicating the patient has chosen not to have their body mass index (BMI) measured','999011091000230101'),
('BMIHEALTHY_COD','Body mass index (BMI) healthy codes','999016011000230101'),
('BMIOBESE_COD','Body mass index (BMI) obese codes','999016051000230102'),
('BMIOVER_COD','Body mass index (BMI) overweight codes','999016091000230107'),
('BMIPU_COD','Codes for body mass index (BMI) measurement unsuitable for patient','999011131000230103'),
('BMIUNDER_COD','Body mass index (BMI) underweight codes','999016131000230105'),
('BMIVAL_COD','Body mass index (BMI) codes with an associated BMI value','999011171000230101'),
('BMI_COD','Body mass index (BMI) codes','999010971000230107'),
('BPDEC_COD','Codes indicating the patient has chosen not to have blood pressure procedure','999012611000230106'),
('BP_COD','Blood pressure (BP) recording codes','999012731000230108'),
('CHD_COD','Coronary heart disease (CHD) codes','999000771000230107'),
('CHOL2_COD','Total cholesterol codes with a value','999003971000230103'),
('CHOLDEC_COD','Codes indicating a patient has chosen not to have a cholesterol test','999023851000230107'),
('CKD1AND2_COD','Chronic kidney disease (CKD) stage 1-2 codes','999004051000230107'),
('CKDRES_COD','Chronic kidney disease (CKD) resolved codes','999004171000230102'),
('CKD_COD','Chronic kidney disease (CKD) stage 3-5 codes','999004011000230108'),
('DMRES_COD','Diabetes resolved codes','999003371000230102'),
('DM_COD','Diabetes mellitus codes','999004691000230108'),
('ETH2016AB_COD','Asian or Asian British Bangladeshi ethnicity group codes (2016 grouping)','999001691000230105'),
('ETH2016AC_COD','Asian or Asian British Chinese ethnicity group codes (2016 grouping)','999001731000230102'),
('ETH2016AI_COD','Asian or Asian British Indian ethnicity group codes (2016 grouping)','999001771000230100'),
('ETH2016AO_COD','Asian or Asian British Any other Asian background ethnicity group codes (2016 grouping)','999001811000230100'),
('ETH2016AP_COD','Asian or Asian British Pakistani ethnicity group codes (2016 grouping)','999001851000230101'),
('ETH2016BA_COD','Black or African or Caribbean or Black British African ethnicity group codes (2016 grouping)','999001891000230106'),
('ETH2016BC_COD','Black or African or Caribbean or Black British Caribbean ethnicity group codes (2016 grouping)','999001931000230104'),
('ETH2016BO_COD','Black or African or Caribbean or Black British Any other Black or African or Caribbean background ethnicity group codes (2016 grouping)','999001971000230102'),
('ETH2016MO_COD','Mixed or multiple ethnic groups Any other Mixed or multiple ethnic background ethnicity group codes (2016 grouping)','999002011000230103'),
('ETH2016MWA_COD','Mixed or multiple ethnic groups White and Asian ethnicity group codes (2016 grouping)','999002051000230104'),
('ETH2016MWBA_COD','Mixed or multiple ethnic groups White and Black African ethnicity group codes (2016 grouping)','999002091000230109'),
('ETH2016MWBC_COD','Mixed or multiple ethnic groups White and Black Caribbean ethnicity group codes (2016 grouping)','999002131000230107'),
('ETH2016NSTAT_COD','Not stated ethnicity group codes (2016 grouping)','999002171000230109'),
('ETH2016OA_COD','Other ethnic group Arab ethnicity group codes (2016 grouping)','999002211000230107'),
('ETH2016OO_COD','Other ethnic group Any other ethnic group ethnicity group codes (2016 grouping)','999002251000230106'),
('ETH2016WB_COD','White English or Welsh or Scottish or Northern Irish or British ethnicity group codes (2016 grouping)','999002291000230101'),
('ETH2016WGT_COD','White Gypsy or Irish Traveller ethnicity group codes (2016 grouping)','999002331000230105'),
('ETH2016WI_COD','White Irish ethnicity group codes (2016 grouping)','999002371000230107'),
('ETH2016WO_COD','White Any other White background ethnicity group codes (2016 grouping)','999002411000230106'),
('EXSMOK_COD','Code for ex-smoker','999005211000230103'),
('FHYP_COD','Familial hypercholesterolemia diagnostic codes','999006811000230109'),
('GLUCDEC_COD','Codes indicating the patient has chosen not to receive a blood glucose test','999006691000230104'),
('GLUC_COD','Glucose test recording codes','999006891000230103'),
('HDLCCHOL_COD','High density lipoprotein (HDL) cholesterol test result codes','999017491000230100'),
('IFCCHBAM_COD','IFCC HbA1c monitoring range codes','999003251000230103'),
('LBMI40_COD','Body mass index (BMI) codes >= 40 without an associated BMI value','999020771000230102'),
('LDLCCHOL_COD','Low density lipoprotein (LDL) cholesterol test results codes','999018771000230107'),
('LITSTP_COD','Code for stopped lithium','999006371000230108'),
('LIT_COD','Lithium prescription codes','12465601000001107'),
('LSMOK_COD','Smoker codes','999004211000230104'),
('MHINVITE_COD','Invite mental health care review codes','999012451000230107'),
('MHPCADEC_COD','Codes indicating the patient has chosen not to receive mental health quality indicator care','999013451000230101'),
('MHPCAPU_COD','Codes for mental health quality indicator care unsuitable for patient','999013491000230106'),
('MHP_COD','Codes for mental health care plan','999013411000230100'),
('MHREM_COD','Codes for in remission from serious mental illness','999006091000230105'),
('MH_COD','Psychosis and schizophrenia and bipolar affective disease codes','999001091000230104'),
('NONHDLCCHOL_COD','Non-high density lipoprotein (Non-HDL) cholesterol test result codes','999017731000230106'),
('NONVALCHOL_COD','Cholesterol codes without a value','999018731000230105'),
('NSMOK_COD','Code for never smoked','999006051000230100'),
('PAD_COD','Peripheral arterial disease (PAD) diagnostic codes','999005931000230101'),
('SERFRUC_COD','Serum fructosamine codes','999005691000230107'),
('SMOKSTATDEC_COD','Codes indicating the patient has chosen not to give their smoking status','999012251000230108'),
('SMOK_COD','Smoking habit codes','999005651000230102'),
('STRK_COD','Stroke diagnosis codes','999005531000230105'),
('TCHOLHDL_COD','Total cholesterol high-density lipoprotein (HDL) codes','999005451000230100'),
('TIA_COD','Transient ischaemic attack (TIA) codes','999005291000230109'),
('TRIGLYC_COD','Triglyceride test result codes','999018411000230105');
-- Detail: codes grouped by cluster id/name
SELECT 
    cl.Cluster_ID,
    cl.Cluster_Description,
    prc.SNOMED_code,
    prc.SNOMED_code_description
FROM @ClusterList cl
JOIN PCD_Refset_Content_V2 prc
    ON prc.Cluster_ID = cl.Cluster_ID
ORDER BY cl.Cluster_ID, prc.SNOMED_code;


