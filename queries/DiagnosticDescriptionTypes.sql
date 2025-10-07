-- Diagnostic query to identify available description types in your SNOMED CT database
-- This will help identify the correct type IDs for FSN and synonyms

USE snomedct;
GO

-- Show all description types and their usage counts
SELECT 
    d.typeid,
    c.id as ConceptId,
    desc_type.term as DescriptionType,
    COUNT(*) as UsageCount
FROM curr_description_f d
JOIN curr_concept_f c ON d.typeid = c.id
LEFT JOIN curr_description_f desc_type ON desc_type.conceptid = c.id 
    AND desc_type.typeid IN ('900000000000003001', '999000851000001109')
    AND desc_type.active = '1'
WHERE d.active = '1'
GROUP BY d.typeid, c.id, desc_type.term
ORDER BY UsageCount DESC;

-- Alternative simpler query to just show type IDs
SELECT DISTINCT 
    typeid,
    COUNT(*) as Count
FROM curr_description_f 
WHERE active = '1'
GROUP BY typeid
ORDER BY Count DESC;
