-- Sample Queries for UK Query Table and History Substitution Table
-- These queries demonstrate common use cases for the enhanced transitive closure

USE snomedct;
GO

-- =============================================================================
-- QUERY TABLE: Finding Descendants (Subtypes)
-- =============================================================================

-- Find all types of Diabetes (including through inactive concept paths)
-- This returns MORE results than a standard transitive closure because it
-- includes paths through historically inactivated concepts
SELECT COUNT(DISTINCT subtypeId) AS diabetes_types
FROM uk_query_table
WHERE supertypeId = '73211009';  -- Diabetes mellitus

-- Find all types of Pneumonia
SELECT DISTINCT qt.subtypeId, d.term
FROM uk_query_table qt
JOIN curr_description_f d ON qt.subtypeId = d.conceptid
WHERE qt.supertypeId = '233604007'  -- Pneumonia
  AND d.active = '1'
  AND d.typeid = '900000000000003001'  -- FSN
ORDER BY d.term;

-- =============================================================================
-- QUERY TABLE: Finding Ancestors (Supertypes)  
-- =============================================================================

-- Find all ancestors of a specific concept
-- Useful for classification and "is-a" checking
SELECT DISTINCT qt.supertypeId, d.term
FROM uk_query_table qt
JOIN curr_description_f d ON qt.supertypeId = d.conceptid
WHERE qt.subtypeId = '22298006'  -- Myocardial infarction
  AND d.active = '1'
  AND d.typeid = '900000000000003001'  -- FSN
ORDER BY d.term;

-- =============================================================================
-- QUERY TABLE: Subsumption Testing
-- =============================================================================

-- Check if concept A is a subtype of concept B
-- "Is Pneumonia a type of Disease?"
SELECT CASE 
    WHEN EXISTS (
        SELECT 1 FROM uk_query_table 
        WHERE supertypeId = '64572001'   -- Disease
          AND subtypeId = '233604007'    -- Pneumonia
    ) THEN 'YES - Pneumonia IS-A Disease'
    ELSE 'NO'
END AS subsumption_test;

-- =============================================================================
-- QUERY TABLE: Provenance (Understanding the Path)
-- =============================================================================

-- The provenance column indicates how the relationship was derived:
-- 0 = Direct from active relationships
-- >0 = Derived through history substitution (value = number of substitution hops)

-- Find relationships that required history substitution
SELECT supertypeId, subtypeId, provenance
FROM uk_query_table
WHERE provenance > 0
ORDER BY provenance DESC;

-- =============================================================================
-- HISTORY SUBSTITUTION: Finding Replacements for Inactive Concepts
-- =============================================================================

-- Find the recommended replacement for an inactive concept
SELECT 
    oldConceptId,
    oldConceptFSN,
    newConceptId,
    newConceptFSN,
    isAmbiguous,
    iterations
FROM uk_history_substitution
WHERE oldConceptId = '105000';  -- Example inactive concept

-- Find all substitutions that are ambiguous (multiple possible replacements)
SELECT 
    oldConceptId,
    oldConceptFSN,
    newConceptId,
    newConceptFSN
FROM uk_history_substitution
WHERE isAmbiguous = 1
ORDER BY oldConceptFSN;

-- =============================================================================
-- PRACTICAL EXAMPLE: Query with Inactive Concept Handling
-- =============================================================================

-- Scenario: You have patient data with old/inactive SNOMED codes
-- and need to find all patients with a type of diabetes

-- Step 1: Get all diabetes subtypes (including via inactive paths)
-- Step 2: Also include any inactive codes that map to diabetes types

WITH DiabetesTypes AS (
    -- All active subtypes of Diabetes
    SELECT DISTINCT subtypeId AS conceptId
    FROM uk_query_table
    WHERE supertypeId = '73211009'
    
    UNION
    
    -- Add inactive codes that substitute to diabetes types
    SELECT DISTINCT hs.oldConceptId AS conceptId
    FROM uk_history_substitution hs
    INNER JOIN uk_query_table qt ON hs.newConceptId = qt.subtypeId
    WHERE qt.supertypeId = '73211009'
)
SELECT COUNT(*) AS total_diabetes_codes_including_historical
FROM DiabetesTypes;

-- =============================================================================
-- STATISTICS AND VERIFICATION
-- =============================================================================

-- Table row counts
SELECT 'uk_query_table' AS table_name, COUNT(*) AS row_count FROM uk_query_table
UNION ALL
SELECT 'uk_history_substitution', COUNT(*) FROM uk_history_substitution;

-- Distribution of provenance values
SELECT 
    provenance,
    COUNT(*) AS count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS percentage
FROM uk_query_table
GROUP BY provenance
ORDER BY provenance;

-- Top concepts with most substitutions
SELECT TOP 10
    newConceptId,
    newConceptFSN,
    COUNT(*) AS substitution_count
FROM uk_history_substitution
GROUP BY newConceptId, newConceptFSN
ORDER BY substitution_count DESC;
