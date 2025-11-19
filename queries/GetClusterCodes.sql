-- =================================================================
-- Get SNOMED Codes for Medication Review Clusters
-- =================================================================
-- This query retrieves all SNOMED codes associated with medication
-- review clusters from the Primary Care Domain (PCD) reference sets.
-- =================================================================

USE SNOMEDCT;
GO

-- Medication Review Cluster IDs
DECLARE @ClusterIDs TABLE (Cluster_ID NVARCHAR(50));

INSERT INTO @ClusterIDs VALUES
    ('MEDRVW_COD'),           -- Medication review codes
    ('DEMMEDRVW_COD'),        -- Dementia medication review codes
    ('HFMEDRVW_COD'),         -- Heart failure medication review codes
    ('STRUCTMEDRVW_COD'),     -- Structured medication review codes
    ('MEDRVWDEC_COD'),        -- Medication review declined
    ('STRMEDRWVDEC_COD');     -- Structured medication review declined

-- =================================================================
-- User's Check List
-- =================================================================
DECLARE @UserCheckCodes TABLE (Code BIGINT);

INSERT INTO @UserCheckCodes VALUES
    (922731000000106),(769063007),(394720003),(718017007),(810241000000107),
    (473219007),(473223004),(428911000124108),(712761000000103),(394724007),
    (938551000000108),(413974004),(394725008),(279681000000105),(772741000000105),
    (792951000000100),(473234001),(473235000),(401062003),(473230005),
    (473224005),(473220001),(473226007),(381351000000107),(381261000000101),
    (381231000000106),(381321000000102),(381291000000107),(1103191000000105),(473233007),
    (473225006),(473232002),(753951000000101),(1079381000000109),(803361000000109),
    (93311000000106),(88551000000109),(391156007),(395005007),(413143000),
    (473227003),(473228008),(287031000000100),(965871000000101),(1811000124107),
    (1841000124106),(870661000000100),(1831000124101),(473221002),(473231009),
    (858091000000102),(1156698007),(1089291000000107),(182836005),(1106111000000108),
    (1239511000000100),(415693003),(6021000124103),
    (314530002),(1127441000000107),(719327002),(719328007),(961831000000100),
    (961861000000105),(719478008),(719329004),(719326006),(526431000000106),
    (526421000000109);

-- =================================================================
-- Query: Unique Medication Review SNOMED Codes per Cluster
-- =================================================================
SELECT DISTINCT
    pcd.Cluster_ID,
    pcd.Cluster_Description,
    pcd.SNOMED_code,
    pcd.SNOMED_code_description,
    pcd.PCD_Refset_ID,
    CASE 
        WHEN ucc.Code IS NOT NULL THEN 'YES' 
        ELSE 'NO' 
    END AS In_User_List
FROM PCD_Refset_Content_by_Output pcd
LEFT JOIN @UserCheckCodes ucc ON pcd.SNOMED_code = ucc.Code
WHERE pcd.Cluster_ID IN (SELECT Cluster_ID FROM @ClusterIDs)
ORDER BY pcd.Cluster_ID, pcd.SNOMED_code;

-- =================================================================
-- Check: How many codes from a specific list exist in clusters
-- =================================================================
DECLARE @CheckCodes TABLE (Code BIGINT);

INSERT INTO @CheckCodes VALUES
    (922731000000106),(769063007),(394720003),(718017007),(810241000000107),
    (473219007),(473223004),(428911000124108),(712761000000103),(394724007),
    (938551000000108),(413974004),(394725008),(279681000000105),(772741000000105),
    (792951000000100),(473234001),(473235000),(401062003),(473230005),
    (473224005),(473220001),(473226007),(381351000000107),(381261000000101),
    (381231000000106),(381321000000102),(381291000000107),(1103191000000105),(473233007),
    (473225006),(473232002),(753951000000101),(1079381000000109),(803361000000109),
    (93311000000106),(88551000000109),(391156007),(395005007),(413143000),
    (473227003),(473228008),(287031000000100),(965871000000101),(1811000124107),
    (1841000124106),(870661000000100),(1831000124101),(473221002),(473231009),
    (858091000000102),(1156698007),(1089291000000107),(182836005),(1106111000000108),
    (1239511000000100),(415693003),(6021000124103);

SELECT 
    COUNT(DISTINCT cc.Code) AS Codes_In_List,
    COUNT(DISTINCT pcd.SNOMED_code) AS Codes_In_Clusters,
    COUNT(DISTINCT CASE WHEN pcd.SNOMED_code IS NOT NULL THEN cc.Code END) AS Matching_Codes
FROM @CheckCodes cc
LEFT JOIN PCD_Refset_Content_by_Output pcd 
    ON cc.Code = pcd.SNOMED_code
    AND pcd.Cluster_ID IN (SELECT Cluster_ID FROM @ClusterIDs);

-- Show which codes match
SELECT 
    cc.Code AS Provided_Code,
    pcd.SNOMED_code,
    pcd.SNOMED_code_description,
    pcd.Cluster_ID,
    CASE WHEN pcd.SNOMED_code IS NULL THEN 'NOT FOUND' ELSE 'FOUND' END AS Status
FROM @CheckCodes cc
LEFT JOIN (
    SELECT DISTINCT SNOMED_code, SNOMED_code_description, Cluster_ID
    FROM PCD_Refset_Content_by_Output
    WHERE Cluster_ID IN (SELECT Cluster_ID FROM @ClusterIDs)
) pcd ON cc.Code = pcd.SNOMED_code
ORDER BY Status DESC, cc.Code;
