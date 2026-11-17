-- ========================================================================
-- SNOMED CT GP Summary Data Sharing Exclusion Reference Set
-- Gender Related Issues
-- ========================================================================

USE SNOMEDCT;
GO


SELECT
    'Gender Related Issues' AS Exclusion_Category,
    CAST(s.refsetid AS VARCHAR(20)) AS RefsetID,
    CAST(rs.term AS VARCHAR(255)) AS Refset_Name,
    CAST(s.referencedcomponentid AS VARCHAR(20)) AS SNOMED_ConceptID,
    CAST(d.term AS VARCHAR(500)) AS FSN_Term,
    CAST(pt.term AS VARCHAR(500)) AS Preferred_Term,
    CAST(c.active AS VARCHAR(1)) AS ConceptIsActive
FROM curr_simplerefset_f s
-- Get refset name
LEFT JOIN curr_description_f rs
    ON rs.conceptid = s.refsetid
    AND CAST(rs.typeid AS VARCHAR(50)) = '900000000000003001'  -- FSN
    AND CAST(rs.active AS VARCHAR(1)) = '1'
-- Join to concept table
JOIN curr_concept_f c
    ON s.referencedcomponentid = c.id
-- Get FSN (Fully Specified Name)
LEFT JOIN curr_description_f d
    ON d.conceptid = s.referencedcomponentid
    AND CAST(d.typeid AS VARCHAR(50)) = '900000000000003001'  -- FSN
    AND CAST(d.active AS VARCHAR(1)) = '1'
-- Get Preferred Term
LEFT JOIN curr_description_f pt
    ON pt.conceptid = s.referencedcomponentid
    AND CAST(pt.typeid AS VARCHAR(50)) = '900000000000013009'  -- Preferred term
    AND CAST(pt.active AS VARCHAR(1)) = '1'
WHERE CAST(s.refsetid AS VARCHAR(20)) = '999004351000000109'  -- Gender related issues
AND CAST(s.active AS VARCHAR(1)) = '1'
ORDER BY Preferred_Term;

-- ========================================================================
-- Summary count
-- ========================================================================
SELECT
    'Gender Related Issues' AS Exclusion_Category,
    CAST(s.refsetid AS VARCHAR(20)) AS RefsetID,
    COUNT(DISTINCT s.referencedcomponentid) AS Total_Codes
FROM curr_simplerefset_f s
WHERE CAST(s.refsetid AS VARCHAR(20)) = '999004351000000109'
AND CAST(s.active AS VARCHAR(1)) = '1'
GROUP BY s.refsetid;
