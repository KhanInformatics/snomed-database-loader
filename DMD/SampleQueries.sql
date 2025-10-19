-- Sample DM+D Database Queries
-- This shows how to query the imported SNOMED CT Drug Extension data

-- Query 1: Show all imported drug products with their SNOMED concept IDs
SELECT 
    'AMP (Actual Medical Product)' as ProductType,
    a.apid as ProductID,
    a.nm as ProductName,
    ds.snomed_conceptid as SNOMEDConceptID
FROM amp a
JOIN dmd_snomed ds ON a.apid = ds.dmd_id
ORDER BY a.nm;

-- Query 2: Search for specific medications (example: Tramadol)
SELECT 
    a.apid as ProductID,
    a.nm as ProductName
FROM amp a
WHERE a.nm LIKE '%Tramadol%'
ORDER BY a.nm;

-- Query 3: Search for products from specific manufacturers (example: Boots)
SELECT 
    a.apid as ProductID,
    a.nm as ProductName
FROM amp a
WHERE a.nm LIKE '%Boots%'
ORDER BY a.nm;

-- Query 4: Count products by strength pattern
SELECT 
    CASE 
        WHEN nm LIKE '%mg%' THEN 'Milligram products'
        WHEN nm LIKE '%microgram%' THEN 'Microgram products'
        WHEN nm LIKE '%ml%' THEN 'Liquid products'
        ELSE 'Other products'
    END as ProductCategory,
    COUNT(*) as ProductCount
FROM amp
GROUP BY CASE 
        WHEN nm LIKE '%mg%' THEN 'Milligram products'
        WHEN nm LIKE '%microgram%' THEN 'Microgram products'
        WHEN nm LIKE '%ml%' THEN 'Liquid products'
        ELSE 'Other products'
    END;

-- Query 5: Database summary statistics
SELECT 
    'Total AMPs (Actual Medical Products)' as Statistic,
    COUNT(*) as Value
FROM amp
UNION ALL
SELECT 
    'Active AMPs',
    COUNT(*)
FROM amp
WHERE invalid = 0
UNION ALL
SELECT 
    'SNOMED CT Mappings',
    COUNT(*)
FROM dmd_snomed;