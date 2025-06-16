USE SNOMEDCT;
GO

DECLARE @RefsetId NVARCHAR(18) = '999026651000230100';
SELECT
    s.refsetid                                 AS RefsetId,
    c2.active                                  AS RefsetIsActive,
    d2.term                                    AS RefsetName,
    s.referencedcomponentid                    AS ConceptId,
    c.active                                   AS ConceptIsActive,
    d.term                                     AS FSN
FROM curr_simplerefset_f AS s
JOIN curr_concept_f       AS c  ON s.referencedcomponentid = c.id
LEFT JOIN curr_description_f AS d  ON d.conceptid = c.id
    AND d.typeid = '900000000000003001'
    AND d.active = '1'
JOIN curr_concept_f       AS c2 ON s.refsetid = c2.id
LEFT JOIN curr_description_f AS d2 ON d2.conceptid = c2.id
    AND d2.typeid = '900000000000003001'
    AND d2.active = '1'
WHERE s.refsetid = @RefsetId
  AND s.active   = '1';

  