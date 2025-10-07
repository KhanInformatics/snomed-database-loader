-- Select a SNOMED CT database
USE snomedct;
GO

-- This query retrieves active concepts in a specific reference set,
-- along with metadata about both the concepts and the reference set itself
SELECT
    s.refsetid,                         -- ID of the reference set
    c2.active AS [RefsetIsActive],      -- Whether the reference set is active (1) or inactive (0)
    d2.term AS [RefsetName],            -- The Fully Specified Name of the reference set
    s.referencedcomponentid AS [ConceptId],  -- The ID of the concept that is a member of the reference set
    c.active AS [ConceptIsActive],      -- Whether the concept is active (1) or inactive (0)
    d.term AS [FSN],                    -- The Fully Specified Name of the concept
    pt.term AS [PreferredTerm]          -- The Preferred Term of the concept
FROM curr_simplerefset_f s              -- Simple reference set table containing member relationships
JOIN curr_concept_f c                   -- Join to concept table to get concept metadata
    ON s.referencedcomponentid = c.id
LEFT JOIN curr_description_f d          -- Join to description table to get concept names (FSN)
    ON d.conceptid = c.id
    AND d.typeid IN ('900000000000003001', '999000851000001109')  -- Standard or UK FSN type ID
    AND d.active = '1'                   -- Only active descriptions
LEFT JOIN curr_description_f pt         -- Join to description table to get any available term
    ON pt.conceptid = c.id
    AND pt.typeid IN ('900000000000013009', '900000000000003001')  -- Synonym or FSN type
    AND pt.active = '1'                  -- Only active descriptions
JOIN curr_concept_f c2                  -- Join to concept table again to get refset metadata
    ON s.refsetid = c2.id
LEFT JOIN curr_description_f d2         -- Join to description table again to get refset name
    ON d2.conceptid = c2.id
    AND d2.typeid = '900000000000003001' -- Type ID for Fully Specified Name (FSN)
    AND d2.active = '1'                  -- Only active descriptions
WHERE s.refsetid = '999004851000230104'  -- Specific reference set being queried
  AND s.active = '1';                    -- Only active members of the reference set
