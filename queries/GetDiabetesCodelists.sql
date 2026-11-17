USE SNOMEDCT;
GO

-- ================================================================
-- Get SNOMED codes for Diabetes ACE/ARB contraindication clusters
-- Source table: PCD_Refset_Content_V2 (6 columns)
--   Cluster_ID, Cluster_Description, SNOMED_code, SNOMED_code_description,
--   PCD_Refset_ID, Service_and_Ruleset
-- ================================================================
-- TXACE_COD - 3 codes (ACE inhibitor contraindications)
--   134390006  Angiotensin converting enzyme inhibitor not indicated (situation)
--   315364008  Angiotensin converting enzyme inhibitors contraindicated (situation)
--   407564000  Angiotensin converting enzyme inhibitor not tolerated (situation)
--
-- TXAII_COD - 3 codes (ARB contraindications)
--   394987009  Angiotensin II receptor antagonists contraindicated (situation)
--   407565004  Angiotensin II receptor antagonist not tolerated (situation)
--   407572003  Angiotensin II receptor antagonist not indicated (situation)
-- ================================================================

-- Define the clusters of interest (table variable so it can be reused by multiple queries)
DECLARE @ClusterList TABLE (
    Cluster_ID           NVARCHAR(50),
    Cluster_Description  NVARCHAR(300),
    PCD_Refset_ID        NVARCHAR(50)
);

INSERT INTO @ClusterList (Cluster_ID, Cluster_Description, PCD_Refset_ID)
VALUES 
    ('TXACE_COD','Angiotensin-converting enzyme (ACE) inhibitor contraindications (expiring) codes','^999005251000230104'),
    ('TXAII_COD','Angiotensin II receptor blockers (ARB) contraindications (expiring) codes','^999004491000230106');

    SELECT 
    cl.Cluster_ID,
    cl.Cluster_Description,
    prc.SNOMED_code,
    prc.SNOMED_code_description
FROM @ClusterList cl
JOIN PCD_Refset_Content_V2 prc
    ON prc.Cluster_ID = cl.Cluster_ID
ORDER BY cl.Cluster_ID, prc.SNOMED_code;
