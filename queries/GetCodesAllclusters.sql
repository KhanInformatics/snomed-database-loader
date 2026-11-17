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
    ('ASTEXACB_COD','Codes indicating the number of asthma exacerbations','999020051000230106'),
    ('ASTINVITE_COD','Invite for asthma care review codes','999012051000230101'),
    ('ASTMONDEC_COD','Codes indicating the patient has chosen not to receive asthma monitoring','999009651000230104'),
    ('ASTPCADEC_COD','Codes indicating the patient has chosen not to receive asthma quality indicator care','999009811000230104'),
    ('ASTPCAPU_COD','Codes for asthma quality indicator care unsuitable for patient','999009851000230100'),
    ('ASTRES_COD','Asthma resolved codes','999010051000230100'),
    ('ASTSPIR_COD','Spirometry codes for asthma','999010171000230105'),
    ('ASTTRT_COD','Asthma-related drug treatment codes','12463601000001108'),
    ('AST_COD','Asthma diagnosis codes','999012891000230104'),
    ('BRONCCHALENG_COD','Bronchial challenge test codes','999036521000230109'),
    ('FBC_COD','Full blood count (FBC) test recording codes','999031251000230105'),
    ('FENO_COD','Codes indicating FeNO test performed','999020211000230103'),
    ('IGE_COD','Total IgE level codes','999036531000230106'),
    ('PEFRVAR_COD','Peak expiratory flow rate variability done codes','999036541000230100'),
    ('REV_COD','Asthma review codes','999011931000230101'),
    ('SKINTEST_COD','Skin prick test for house dust mite codes','999036551000230102'),
    ('SPIRPCASU_COD','Diagnostic spirometry quality indicator service unavailable codes','999013251000230100'),
    ('WRITPASTP_COD','Written personalised asthma plan codes','999020651000230102');

    SELECT 
    cl.Cluster_ID,
    cl.Cluster_Description,
    prc.SNOMED_code,
    prc.SNOMED_code_description
FROM @ClusterList cl
JOIN PCD_Refset_Content_V2 prc
    ON prc.Cluster_ID = cl.Cluster_ID
ORDER BY cl.Cluster_ID, prc.SNOMED_code;


