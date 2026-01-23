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
    ('BP_COD','Blood pressure (BP) recording codes','^999012731000230108'),
    ('BPDEC_COD','Codes indicating the patient has chosen not to have blood pressure procedure','^999012611000230106'),
    ('BMIDEC_COD','Codes indicating the patient has chosen not to have their body mass index (BMI) measured','^999011091000230101'),
    ('BMILMH_COD','Low, normal or high body mass index (BMI) codes','^999022651000230101'),
    ('BMIPU_COD','Codes for body mass index (BMI) measurement unsuitable for patient','^999011131000230103'),
    ('ALC_COD','Alcohol consumption codes','^999007011000230101'),
    ('LDLCCHOL_COD','Low density lipoprotein (LDL) cholesterol test results codes','^999018771000230107'),
    ('GLUC_COD','Glucose test recording codes','^999006891000230103'),
    ('GLUCDEC_COD','Codes indicating the patient has chosen not to receive a blood glucose test','^999006691000230104'),
    ('DCCTHBA1C_COD','HbA1c Diabetes Control and Complications Trial (DCCT) level codes','^999023291000230101'),
    ('MEDRVW_COD','Medication review codes','^999020811000230102'),
    ('MEDRVWDEC_COD','Codes indicating the patient has chosen not to receive a medication review','^999019011000230106'),
    ('ALCREF_COD','Referral regarding alcohol usage codes','^999023211000230107'),
    ('ALCSPADV_COD','Referral to specialist alcohol treatment service codes','^999000291000230100'),
    ('DPPATT_COD','Referral to NHS diabetes prevention programme attended','^999000851000230106'),
    ('DPPCOMP_COD','Referral to NHS diabetes prevention programme completed','^999000891000230101'),
    ('DPPOFF_COD','Referral to NHS diabetes prevention programme offered or declined','^999000931000230108'),
    ('CSDEC_COD','Codes indicating the patient has chosen not to receive cervical smear','^999009451000230102'),
    ('CSPU_COD','Codes for cervical screening quality indicator care unsuitable for patient','^999009251000230101'),
    ('BRCANSCR_COD','Breast cancer screening codes','^999016171000230107'),
    ('BRCANSCRDEC_COD','Codes indicating the patient has chosen not to have breast cancer screening','^999023811000230108'),
    ('COLCANSCR_COD','Colorectal cancer screening codes','^999016251000230109'),
    ('COLCANSCRDEC_COD','Codes indicating patient has chosen not to have bowel cancer screening','^999023731000230106'),
    ('NUTRIASS_COD','Nutrition and diet assessment codes','^999023491000230100'),
    ('NUTRIASSDEC_COD','Nutrition and diet assessment declined codes','^999036311000230106'),
    ('EXERASS_COD','Exercise level assessment codes','^999023331000230105'),
    ('EXERASSDEC_COD','Codes indicating patient has chosen not to have an exercise assessment','^999023371000230107'),
    ('ILLSUB_COD','Illicit substance abuse codes','^999023651000230108'),
    ('ILLSUBASSDEC_COD','Codes indicating patient has chosen not to have their illicit substance abuse assessment','^999023611000230109'),
    ('ILLSUBINT_COD','Illicit substance abuse intervention and declined codes','^999023691000230103'),
    ('MH_COD','Psychosis and schizophrenia and bipolar affective disease codes','^999001091000230104');

    SELECT 
    cl.Cluster_ID,
    cl.Cluster_Description,
    prc.SNOMED_code,
    prc.SNOMED_code_description
FROM @ClusterList cl
JOIN PCD_Refset_Content_V2 prc
    ON prc.Cluster_ID = cl.Cluster_ID
ORDER BY cl.Cluster_ID, prc.SNOMED_code;


