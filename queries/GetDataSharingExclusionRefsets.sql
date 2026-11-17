-- ========================================================================
-- SNOMED CT GP Summary Data Sharing Exclusion Reference Sets
-- ========================================================================
-- Extract all codes from the 4 data sharing exclusion reference sets
-- ========================================================================

USE SNOMEDCT;
GO


-- Combined query for all 4 exclusion reference sets
SELECT
    CASE s.refsetid
        WHEN '999004361000000107' THEN 'Termination of Pregnancy'
        WHEN '999004351000000109' THEN 'Gender Related Issues'
        WHEN '999004371000000100' THEN 'Assisted Fertilisation'
        WHEN '999004381000000103' THEN 'Sexually Transmitted Disease'
    END AS Exclusion_Category,
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
WHERE CAST(s.refsetid AS VARCHAR(20)) IN (
    '999004361000000107',  -- Termination of pregnancy
    '999004351000000109',  -- Gender related issues
    '999004371000000100',  -- Assisted fertilisation
    '999004381000000103'   -- Sexually transmitted disease
)
AND CAST(s.active AS VARCHAR(1)) = '1'
ORDER BY 
    Exclusion_Category,
    Preferred_Term;

-- ========================================================================
-- Summary counts by category
-- ========================================================================
SELECT
    CASE s.refsetid
        WHEN '999004361000000107' THEN 'Termination of Pregnancy'
        WHEN '999004351000000109' THEN 'Gender Related Issues'
        WHEN '999004371000000100' THEN 'Assisted Fertilisation'
        WHEN '999004381000000103' THEN 'Sexually Transmitted Disease'
    END AS Exclusion_Category,
    CAST(s.refsetid AS VARCHAR(20)) AS RefsetID,
    COUNT(DISTINCT s.referencedcomponentid) AS Total_Codes
FROM curr_simplerefset_f s
WHERE CAST(s.refsetid AS VARCHAR(20)) IN (
    '999004361000000107',
    '999004351000000109',
    '999004371000000100',
    '999004381000000103'
)
AND CAST(s.active AS VARCHAR(1)) = '1'
GROUP BY s.refsetid
ORDER BY Exclusion_Category;
