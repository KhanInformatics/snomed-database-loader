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
    ('SMOK_COD',       'Smoking habit codes',                                              '^999005651000230102'),
    ('SMOKINVITE_COD', 'Invite for smoking care review codes',                             '^999012531000230102'),
    ('SMOKPCADEC_COD', 'Codes indicating the patient has chosen not to receive smoking quality indicator care', '^999012171000230106'),
    ('SMOKPCAPU_COD',  'Codes for smoking quality indicator care unsuitable for patient',  '^999012211000230109'),
    ('SMOKSTATDEC_COD','Codes indicating the patient has chosen not to give their smoking status',             '^999012251000230108');

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

-- Optional: Aggregated codes per cluster (comma-separated)
-- Note: STRING_AGG requires SQL Server 2017+
SELECT 
    cl.Cluster_ID,
    cl.Cluster_Description,
    COUNT(DISTINCT prc.SNOMED_code) AS Code_Count,
    STRING_AGG(CAST(prc.SNOMED_code AS NVARCHAR(20)), ',') WITHIN GROUP (ORDER BY prc.SNOMED_code) AS Codes_CSV
FROM @ClusterList cl
JOIN PCD_Refset_Content_V2 prc
    ON prc.Cluster_ID = cl.Cluster_ID
GROUP BY cl.Cluster_ID, cl.Cluster_Description
ORDER BY cl.Cluster_ID;
