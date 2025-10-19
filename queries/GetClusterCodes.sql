-- =================================================================
-- Get SNOMED Codes for a Specific PCD Cluster
-- =================================================================
-- This query retrieves all SNOMED codes associated with a specific 
-- cluster from the Primary Care Domain (PCD) reference sets.
--
-- Target Table: PCD_Refset_Content_by_Output (recommended)
-- - Contains cluster information (Cluster_ID, Cluster_Description)
-- - Maps clusters to SNOMED codes and outputs
-- - Provides comprehensive cluster-to-code relationships
-- =================================================================

USE SNOMEDCT;
GO

-- Example: Get all codes for AST_COD cluster (Asthma codes)
DECLARE @ClusterID NVARCHAR(50) = 'ALC_COD';

-- =================================================================
-- Query 1: Basic Cluster Code List with Output Descriptions
-- =================================================================
SELECT 
    pcd.Cluster_ID,
    pcd.Cluster_Description,
    pcd.SNOMED_code,
    pcd.SNOMED_code_description,
    pcd.Output_ID,
    pod.Output_Description,
    pod.Output_Type,
    pcd.PCD_Refset_ID
FROM PCD_Refset_Content_by_Output pcd
LEFT JOIN PCD_Output_Descriptions_V2 pod ON pcd.Output_ID = pod.Output_ID
WHERE pcd.Cluster_ID = @ClusterID
ORDER BY pcd.SNOMED_code, pcd.Output_ID;
