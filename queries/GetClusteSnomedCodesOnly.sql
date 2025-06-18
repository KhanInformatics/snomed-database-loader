-- =================================================================
-- Get SNOMED Codes by Cluster or Refset from PCD_Refset_Content_V2
-- =================================================================
-- Simple script to retrieve SNOMED codes for a specific cluster
-- or refset from PCD_Refset_Content_V2 table.
--
-- The table now has 6 columns:
-- - Cluster_ID: Cluster identifier (e.g., 'AST_COD')
-- - Cluster_Description: Human-readable cluster name
-- - SNOMED_code: The SNOMED CT code
-- - SNOMED_code_description: Description of the SNOMED code
-- - PCD_Refset_ID: Reference set identifier
-- - Service_and_Ruleset: Service and ruleset information
-- =================================================================

USE SNOMEDCT;
GO

-- =================================================================
-- Query 1: Get SNOMED Codes by Cluster ID (e.g., AST_COD)
-- =================================================================
DECLARE @ClusterID NVARCHAR(50) = 'AST_COD';

SELECT DISTINCT 
    SNOMED_code
FROM PCD_Refset_Content_V2
WHERE Cluster_ID = @ClusterID
ORDER BY SNOMED_code;

-- =================================================================
-- Query 2: Get SNOMED Codes with Context by Cluster ID
-- =================================================================
SELECT DISTINCT 
    Cluster_ID,
    Cluster_Description,
    SNOMED_code,
    SNOMED_code_description,
    PCD_Refset_ID,
    Service_and_Ruleset
FROM PCD_Refset_Content_V2
WHERE Cluster_ID = @ClusterID
ORDER BY SNOMED_code;

-- =================================================================
-- Query 3: Count of Codes by Cluster
-- =================================================================
SELECT 
    Cluster_ID,
    Cluster_Description,
    COUNT(DISTINCT SNOMED_code) AS Total_Codes
FROM PCD_Refset_Content_V2
WHERE Cluster_ID = @ClusterID
GROUP BY Cluster_ID, Cluster_Description;

-- =================================================================
-- Query 4: CSV Export Format - SNOMED Codes Only
-- =================================================================
/*
SELECT DISTINCT 
    SNOMED_code + ','
FROM PCD_Refset_Content_V2
WHERE Cluster_ID = @ClusterID
ORDER BY SNOMED_code;
*/

-- =================================================================
-- Query 5: List All Available Clusters
-- =================================================================
SELECT DISTINCT 
    Cluster_ID,
    Cluster_Description,
    COUNT(DISTINCT SNOMED_code) AS Code_Count
FROM PCD_Refset_Content_V2
GROUP BY Cluster_ID, Cluster_Description
ORDER BY Cluster_ID;

-- =================================================================
-- Query 5: Check Available Refset IDs (for reference)
-- =================================================================
/*
SELECT DISTINCT 
    PCD_Refset_ID
FROM PCD_Refset_Content_V2
ORDER BY PCD_Refset_ID;
*/

-- =================================================================
-- Usage Examples:
-- =================================================================
-- To get codes for other conditions, change the LIKE patterns:
-- '%DIA%' and '%diabetes%'     -- Diabetes codes
-- '%HYP%' and '%hypertension%' -- Hypertension codes  
-- '%CHD%' and '%heart%'        -- Coronary Heart Disease codes
-- '%VAC%' and '%vaccination%'  -- Vaccination codes
-- =================================================================

PRINT 'AST_COD SNOMED codes retrieved from PCD_Refset_Content_V2';
PRINT 'Query 1: Clean list of asthma codes only';
PRINT 'Query 2: Codes with descriptions';
PRINT 'Query 3: Total count of unique codes';
