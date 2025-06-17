---

## Useful SNOMEDCT SQL Queries

Below are useful queries you can copy‑and‑paste directly into SSMS (or another SQL client). They assume the data has already been loaded into the **SNOMEDCT** database and that the standard table names from `create_snomed_tables.sql` are in use.

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
```

## Primary Care Domain (PCD) Queries

The following queries work with the PCD tables created by the `Load-PCD-Refset-Content.ps1` script.

### 1. Check PCD Table Record Counts

Verify that PCD data has been loaded correctly:

```sql
USE SNOMEDCT;
GO
SELECT  
    t.name AS TableName,
    SUM(p.row_count) AS TotalRows
FROM sys.tables AS t
JOIN sys.dm_db_partition_stats AS p ON t.object_id = p.object_id
WHERE t.name IN (
    'PCD_Refset_Content_by_Output',
    'PCD_Refset_Content_V2',
    'PCD_Ruleset_Full_Name_Mappings_V2',
    'PCD_Service_Full_Name_Mappings_V2',
    'PCD_Output_Descriptions_V2'
) AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;
```

### 2. Find SNOMED Codes for a Specific Clinical Area

Find all SNOMED codes related to a specific ruleset (e.g., Asthma):

```sql
USE SNOMEDCT;
GO
DECLARE @RulesetName NVARCHAR(100) = 'Asthma';

SELECT 
    prc.Output_ID,
    prc.SNOMED_Code,
    prc.Output_Description,
    prm.Ruleset_Full_Name,
    prc.PCD_Refset_ID,
    prc.Cluster
FROM PCD_Refset_Content_by_Output prc
LEFT JOIN PCD_Ruleset_Full_Name_Mappings_V2 prm 
    ON CHARINDEX(prm.Ruleset_ID, prc.Output_ID) > 0
WHERE prm.Ruleset_Full_Name LIKE '%' + @RulesetName + '%'
ORDER BY prc.Output_ID, prc.SNOMED_Code;
```

### 3. List All Available Clinical Areas and Programmes

Show all rulesets and their full names:

```sql
USE SNOMEDCT;
GO
SELECT 
    Ruleset_ID,
    Ruleset_Short_Name,
    Ruleset_Full_Name
FROM PCD_Ruleset_Full_Name_Mappings_V2
ORDER BY Ruleset_Full_Name;
```

### 4. Find PCD Outputs by Service Type

List all outputs for a specific service type (e.g., Core Contract):

```sql
USE SNOMEDCT;
GO
DECLARE @ServiceType NVARCHAR(50) = 'Core Contract';

SELECT DISTINCT
    pod.Output_ID,
    pod.Output_Description,
    pod.Output_Type,
    psm.Service_Full_Name
FROM PCD_Output_Descriptions_V2 pod
LEFT JOIN PCD_Service_Full_Name_Mappings_V2 psm 
    ON pod.Output_ID LIKE psm.Service_ID + '%'
WHERE psm.Service_Full_Name LIKE '%' + @ServiceType + '%'
ORDER BY pod.Output_ID;
```

### 5. Comprehensive PCD Data Overview

Get a summary of PCD data with counts by service type:

```sql
USE SNOMEDCT;
GO
SELECT 
    psm.Service_ID,
    psm.Service_Full_Name,
    COUNT(DISTINCT pod.Output_ID) as OutputCount,
    COUNT(DISTINCT prc.SNOMED_Code) as SnomedCodeCount
FROM PCD_Service_Full_Name_Mappings_V2 psm
LEFT JOIN PCD_Output_Descriptions_V2 pod 
    ON pod.Output_ID LIKE psm.Service_ID + '%'
LEFT JOIN PCD_Refset_Content_by_Output prc 
    ON prc.Output_ID = pod.Output_ID
GROUP BY psm.Service_ID, psm.Service_Full_Name
ORDER BY psm.Service_ID;
```

### 6. Find SNOMED Terms for PCD Concepts

Link PCD SNOMED codes to their descriptions from the main SNOMED CT tables:

```sql
USE SNOMEDCT;
GO
DECLARE @OutputID NVARCHAR(50) = 'ALCMI30'; -- Example output ID

SELECT 
    prc.Output_ID,
    prc.SNOMED_Code,
    prc.Output_Description as PCD_Description,
    d.term as SNOMED_FSN,
    c.active as SNOMED_Active
FROM PCD_Refset_Content_by_Output prc
LEFT JOIN curr_concept_f c ON prc.SNOMED_Code = c.id
LEFT JOIN curr_description_f d ON d.conceptid = c.id
    AND d.typeid = '900000000000003001'  -- FSN type
    AND d.active = '1'
WHERE prc.Output_ID = @OutputID
ORDER BY prc.SNOMED_Code;
```
