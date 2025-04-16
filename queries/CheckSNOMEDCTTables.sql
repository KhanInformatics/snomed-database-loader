use SNOMEDCT
go
SELECT  
    t.name AS TableName,
    SUM(p.row_count) AS TotalRows
FROM sys.tables AS t
INNER JOIN sys.dm_db_partition_stats AS p
    ON t.object_id = p.object_id
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
)
  AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;