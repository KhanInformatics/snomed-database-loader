-- ========================================================================
-- SNOMED CT Drug Products Query - UK Drug Extension
-- ========================================================================
-- Get actual drug/medicine products from UK Drug Extension refsets
-- ========================================================================

USE SNOMEDCT;
GO

-- ========================================================================
-- IMPORTANT NOTE:
-- The cluster code "DIRECTORANTICOAGDRUG_COD" does not exist in the current data.
-- Use Drug Extension Refset ID instead for actual drug products.
-- For anticoagulants, use: 93141000001109 (vitamin K antagonists)
-- ========================================================================

DECLARE @DrugRefsetID VARCHAR(20) = '93141000001109';  -- Vitamin K antagonist drugs

SELECT
    CAST(rs.term AS VARCHAR(150)) AS Refset_Name,
    CAST(s.referencedcomponentid AS VARCHAR(20)) AS Drug_ConceptID,
    CAST(d.term AS VARCHAR(255)) AS Drug_Product_Name
FROM curr_simplerefset_f s
-- Get refset name
LEFT JOIN curr_description_f rs
    ON rs.conceptid = s.refsetid
    AND CAST(rs.typeid AS VARCHAR(50)) = '900000000000003001'
    AND CAST(rs.active AS VARCHAR(1)) = '1'
-- Get drug product name (FSN)
LEFT JOIN curr_description_f d 
    ON d.conceptid = s.referencedcomponentid
    AND CAST(d.typeid AS VARCHAR(50)) IN ('900000000000003001', '999000851000001109')
    AND CAST(d.active AS VARCHAR(1)) = '1'
-- Join to ensure concept is active
JOIN curr_concept_f c
    ON s.referencedcomponentid = c.id
    AND CAST(c.active AS VARCHAR(1)) = '1'
WHERE CAST(s.refsetid AS VARCHAR(20)) = @DrugRefsetID
  AND CAST(s.active AS VARCHAR(1)) = '1'
  AND d.term IS NOT NULL  -- Only return products with names
ORDER BY Drug_Product_Name;

-- ========================================================================
-- AVAILABLE DRUG EXTENSION REFSET IDs (Change @DrugRefsetID above):
-- ========================================================================
-- 93141000001109   - Oral vitamin K antagonists (warfarin, acenocoumarol, etc.)
-- 154181000001101  - Oral NSAIDs
-- 999000851000001109 - Diabetic drugs
-- 999000861000001107 - Immunosuppressant drugs
-- 999000951000001101 - Antipsychotic drugs
-- 999000431000001102 - Controlled drugs schedule 1-3
--
-- To find more refsets:
-- SELECT DISTINCT CAST(s.refsetid AS VARCHAR(20)), CAST(d.term AS VARCHAR(200)) AS RefsetName
-- FROM curr_simplerefset_f s
-- LEFT JOIN curr_description_f d ON d.conceptid = s.refsetid 
--   AND CAST(d.typeid AS VARCHAR(50)) = '900000000000003001'
-- WHERE CAST(d.term AS VARCHAR(200)) LIKE '%drug%' 
--   OR CAST(d.term AS VARCHAR(200)) LIKE '%medicine%'
-- ORDER BY RefsetName;
-- ========================================================================

-- ========================================================================
-- OPTION 2: DRUG EXTENSION REFSETS (for actual drug products)
-- ========================================================================
-- Use Drug Extension refset ID when you want actual medicine/product codes
-- Uncomment to use:
/*
DECLARE @DrugRefsetID VARCHAR(20) = '93141000001109';  -- Vitamin K antagonists

SELECT
    CAST(rs_d.term AS VARCHAR(200)) AS RefsetName,
    CAST(s.referencedcomponentid AS VARCHAR(20)) AS ConceptId,
    CAST(d.term AS VARCHAR(255)) AS DrugProduct_FSN,
    CAST(pt.term AS VARCHAR(255)) AS DrugProduct_Preferred
FROM curr_simplerefset_f s
JOIN curr_description_f rs_d
    ON rs_d.conceptid = s.refsetid
    AND CAST(rs_d.typeid AS VARCHAR(50)) = '900000000000003001'
    AND CAST(rs_d.active AS VARCHAR(1)) = '1'
JOIN curr_concept_f c 
    ON s.referencedcomponentid = c.id
    AND CAST(c.active AS VARCHAR(1)) = '1'
LEFT JOIN curr_description_f d 
    ON d.conceptid = c.id
    AND CAST(d.typeid AS VARCHAR(50)) IN ('900000000000003001', '999000851000001109')
    AND CAST(d.active AS VARCHAR(1)) = '1'
LEFT JOIN curr_description_f pt
    ON pt.conceptid = c.id  
    AND CAST(pt.typeid AS VARCHAR(50)) = '900000000000013009'
    AND CAST(pt.active AS VARCHAR(1)) = '1'
WHERE CAST(s.refsetid AS VARCHAR(20)) = @DrugRefsetID
  AND CAST(s.active AS VARCHAR(1)) = '1'
ORDER BY CAST(d.term AS VARCHAR(255));
*/

-- ========================================================================
-- AVAILABLE PCD CLUSTER CODES (Examples):
-- ========================================================================
-- Anticoagulants:
--   ORANTICOAG_COD - Oral anticoagulant prophylaxis codes
--   DOACCON_COD - Direct oral anticoagulant (DOAC) contraindicated
--   DOACDEC_COD - Patient declined DOAC
--   ORANTICOAGDEC_COD - Patient declined oral anticoagulant
--
-- Vitamin K Antagonists:
--   VITKANTAGCON_COD - Vitamin K antagonist contraindicated
--   VITKANTAGDEC_COD - Patient declined vitamin K antagonist
--
-- Other Drugs:
--   MMRVVACDRUG_COD - MMRV vaccine codes
--
-- To find more cluster codes:
-- SELECT DISTINCT Cluster_ID, CAST(Cluster_Description AS VARCHAR(150))
-- FROM PCD_Refset_Content_V2 
-- WHERE Cluster_ID LIKE '%DRUG%' OR CAST(Cluster_Description AS VARCHAR(200)) LIKE '%drug%'
-- ORDER BY Cluster_ID;
-- ========================================================================

-- ========================================================================
-- AVAILABLE DRUG EXTENSION REFSET IDs:
-- ========================================================================
-- 93141000001109   - Network Contract DES - oral vitamin K antagonists
-- 154181000001101  - Network Contract DES - oral NSAIDs
-- 999000851000001109 - Enhanced services - Diabetic drugs
-- 999000861000001107 - Enhanced services - Immunosuppressant drugs
-- 999000951000001101 - Enhanced services - Antipsychotic drugs
-- ========================================================================
