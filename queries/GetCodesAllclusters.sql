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
    ('COPDEXACB_COD','Codes indicating number of COPD exacerbations','999020091000230101'),
    ('COPDINVITE_COD','Invite for chronic obstructive pulmonary disease (COPD) care review codes','999013011000230108'),
    ('COPDPCADEC_COD','Codes indicating the patient has chosen not to receive chronic obstructive pulmonary disease (COPD) quality indicator care','999008971000230108'),
    ('COPDPCAPU_COD','Codes for chronic obstructive pulmonary disease (COPD) quality indicator care unsuitable for patient','999009051000230108'),
    ('COPDPCASU_COD','Chronic obstructive pulmonary disease (COPD) quality indicator service unavailable codes','999009091000230103'),
    ('COPDRES_COD','Chronic obstructive pulmonary disease (COPD) resolved codes','999009131000230100'),
    ('COPDRVW_COD','Codes for chronic obstructive pulmonary disease (COPD) review','999012691000230100'),
    ('COPD_COD','Chronic obstructive pulmonary disease (COPD) codes','999011571000230107'),
    ('FEV1FVCL70_COD','FEV1 and FVC ratio codes indicating ratio of less than 0.7 or 70 per cent','999020291000230109'),
    ('FEV1FVC_COD','FEV1 and FVC ratio codes','999020251000230104'),
    ('MRC1_COD','Codes for Medical Research Council (MRC) breathlessness scale score greater than or equal to 3','999009491000230107'),
    ('MRC_COD','Codes for Medical Research Council (MRC) breathlessness scale score','999013611000230102'),
    ('PULRHBATT_COD','Codes indicating attendance at a pulmonary rehabilitation programme','999010371000230108'),
    ('PULRHBDEC_COD','Codes for patient chose not to be referred to a pulmonary rehabilitation programme','999010411000230107'),
    ('PULRHBPU_COD','Codes indicating that a referral to a pulmonary rehabilitation programme is not suitable for the patient','999010491000230101'),
    ('PULRHBREF_COD','Codes indicating a referral to a pulmonary rehabilitation programme','999036191000230103'),
    ('PULRHBSU_COD','Codes for pulmonary rehabilitation programme unavailable','999010531000230101');

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


