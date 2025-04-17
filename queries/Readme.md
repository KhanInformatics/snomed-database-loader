
---

## Useful SQL Queries

Below are two ready‑made queries you can copy‑and‑paste directly into SSMS (or another SQL client). They assume the data has already been loaded into the **SNOMEDCT** database and that the standard table names from `create_snomed_tables.sql` are in use.

### 1  Check the row counts of the current snapshot tables

Quickly verify that each **curr_\*** table contains data after an import:

```sql
USE SNOMEDCT;
GO
SELECT  
    t.name  AS TableName,
    SUM(p.row_count) AS TotalRows
FROM sys.tables            AS t
JOIN sys.dm_db_partition_stats AS p ON t.object_id = p.object_id
WHERE t.name IN (
    'curr_concept_f',
    'curr_description_f',
    'curr_textdefinition_f',
    'curr_relationship_f',
    'curr_stated_relationship_f',
    'curr_langrefset_f',
    'curr_associationrefset_f',
    'curr_attributevaluerefset_f',
    'curr_simplerefset_f',
    'curr_simplemaprefset_f',
    'curr_extendedmaprefset_f'
) AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;
```

### 2  List active members of a reference set (with metadata)

Replace the **`@RefsetId`** variable with any refset you’re interested in (example shown uses the UK “GP subset” ID `999011611000230101`). The query returns each active concept in the refset plus the Fully Specified Name (FSN) of both the concept and the refset itself.

```sql
DECLARE @RefsetId NVARCHAR(18) = '999011611000230101';

USE SNOMEDCT;
GO
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
