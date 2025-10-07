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
DECLARE @ClusterID NVARCHAR(50) = 'AST_COD';

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

-- =================================================================
-- Query 2: Enhanced with SNOMED CT Term Validation and Output Details
-- Links PCD codes to main SNOMED CT tables for validation
-- =================================================================
SELECT 
    pcd.Cluster_ID,
    pcd.Cluster_Description,
    pcd.SNOMED_code,
    pcd.SNOMED_code_description AS PCD_Description,
    d.term AS SNOMED_FSN,
    c.active AS SNOMED_Active,
    pcd.Output_ID,
    pod.Output_Description,
    pod.Output_Type,
    pcd.PCD_Refset_ID,
    CASE 
        WHEN c.id IS NULL THEN 'Code not found in SNOMED CT'
        WHEN c.active = '0' THEN 'Inactive in SNOMED CT'
        ELSE 'Valid and Active'
    END AS Validation_Status
FROM PCD_Refset_Content_by_Output pcd
LEFT JOIN PCD_Output_Descriptions_V2 pod ON pcd.Output_ID = pod.Output_ID
LEFT JOIN curr_concept_f c ON pcd.SNOMED_code = c.id
LEFT JOIN curr_description_f d ON d.conceptid = c.id
    AND d.typeid = '900000000000003001'  -- FSN type
    AND d.active = '1'
WHERE pcd.Cluster_ID = @ClusterID
ORDER BY pcd.SNOMED_code, pcd.Output_ID;

-- =================================================================
-- Query 3: Cluster Summary Statistics
-- Provides overview of cluster content
-- =================================================================
SELECT 
    Cluster_ID,
    Cluster_Description,
    COUNT(DISTINCT SNOMED_code) AS Total_SNOMED_Codes,
    COUNT(DISTINCT Output_ID) AS Total_Outputs,
    COUNT(DISTINCT PCD_Refset_ID) AS Total_Refsets,
    COUNT(*) AS Total_Records
FROM PCD_Refset_Content_by_Output
WHERE Cluster_ID = @ClusterID
GROUP BY Cluster_ID, Cluster_Description;

-- =================================================================
-- Query 4: Find All Available Clusters
-- Use this to discover what clusters are available
-- =================================================================
-- Uncomment the following to see all available clusters:
/*
SELECT 
    Cluster_ID,
    Cluster_Description,
    COUNT(*) AS Code_Count,
    COUNT(CASE WHEN Output_ID IS NOT NULL THEN 1 END) AS Output_Count
FROM PCD_Refset_Content_by_Output
GROUP BY Cluster_ID, Cluster_Description
ORDER BY Cluster_ID;
*/

-- =================================================================
-- Query 5: Codes with Output Context
-- Shows which outputs each code is associated with
-- =================================================================
SELECT 
    pcd.Cluster_ID,
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

-- =================================================================
-- Alternative Query using PCD_Refset_Content_V2
-- (if you prefer the alternative table structure)
-- =================================================================
/*
-- Note: PCD_Refset_Content_V2 doesn't have direct cluster information
-- but you can search by description patterns
SELECT 
    SNOMED_code,
    SNOMED_code_description,
    PCD_Refset_ID,
    PCD_Refset_Description
FROM PCD_Refset_Content_V2
WHERE PCD_Refset_Description LIKE '%asthma%'  -- Example for asthma-related codes
   OR SNOMED_code_description LIKE '%asthma%'
ORDER BY SNOMED_code;
*/

-- =================================================================
-- Usage Examples:
-- =================================================================
-- To use with different clusters, change the @ClusterID value:
-- DECLARE @ClusterID NVARCHAR(50) = 'DIA_COD';    -- Diabetes codes
-- DECLARE @ClusterID NVARCHAR(50) = 'HYP_COD';    -- Hypertension codes
-- DECLARE @ClusterID NVARCHAR(50) = 'CHD_COD';    -- Coronary Heart Disease codes
-- DECLARE @ClusterID NVARCHAR(50) = '6IN1001';    -- 6-in-1 vaccination codes
-- =================================================================

PRINT 'Query completed for cluster: ' + @ClusterID;
