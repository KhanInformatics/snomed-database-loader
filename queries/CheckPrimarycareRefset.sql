USE SNOMEDCT
GO

-- ========================================================================
-- PRIMARY CARE DOMAIN (PCD) CLUSTERS
-- ========================================================================
-- Example PCD clusters (from PCD_Refset_Content_V2 table):
-- VITKANTAGCON_COD - Vitamin K antagonist contraindicated codes
-- VITKANTAGDEC_COD - Codes indicating patient declined Vitamin K antagonist
--
-- Note: For actual drug products, use the Drug Extension Reference Sets below
-- ========================================================================

-- Query PCD clusters:
DECLARE @ClusterID NVARCHAR(50) = 'VITKANTAGCON_COD';

SELECT DISTINCT 
    SNOMED_code,
    SNOMED_code_description,
    PCD_Refset_ID,
    Cluster_Description
FROM PCD_Refset_Content_V2
WHERE Cluster_ID = @ClusterID
ORDER BY SNOMED_code;

-- ========================================================================
-- DRUG EXTENSION REFERENCE SETS
-- ========================================================================
-- Example Drug Extension Refsets (from curr_simplerefset_f table):
-- 93141000001109 - Network Contract DES - oral vitamin K antagonists
-- 999000851000001109 - Enhanced services - Diabetic drugs
-- 999000951000001101 - Enhanced services - Antipsychotic drugs
-- 154181000001101 - Network Contract DES - oral NSAIDs
--
-- Query Drug Extension Reference Set (uncomment to use):
/*
DECLARE @RefsetID VARCHAR(20) = '93141000001109';

SELECT
    s.referencedcomponentid AS ConceptId,
    c.active AS ConceptIsActive,
    d.term AS DrugName_FSN,
    pt.term AS DrugName_Preferred
FROM curr_simplerefset_f s
JOIN curr_concept_f c ON s.referencedcomponentid = c.id
LEFT JOIN curr_description_f d 
    ON d.conceptid = c.id
    AND d.typeid IN ('900000000000003001', '999000851000001109')
    AND d.active = '1'
LEFT JOIN curr_description_f pt
    ON pt.conceptid = c.id  
    AND pt.typeid = '900000000000013009'
    AND pt.active = '1'
WHERE s.refsetid = @RefsetID
  AND s.active = '1'
ORDER BY d.term;
*/