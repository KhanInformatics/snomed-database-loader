-- Query to find all DMD products with Hydroxychloroquine (373540008) as active ingredient
-- This searches across VTMs, VMPs, and AMPs to provide comprehensive results

USE dmd;
GO

-- Part 1: Check if the ingredient exists
PRINT 'Searching for Hydroxychloroquine ingredient...';
SELECT 
    isid,
    nm as IngredientName,
    invalid as IsInvalid
FROM ingredient
WHERE isid = '373540008';
GO

-- Part 2: Find all Virtual Medical Products (VMPs) containing Hydroxychloroquine
PRINT '';
PRINT 'Virtual Medical Products (VMPs) containing Hydroxychloroquine:';
PRINT '================================================================';
SELECT DISTINCT
    vmp.vpid as VMP_ID,
    vmp.nm as VMP_Name,
    vmp.invalid as IsInvalid,
    vtm.vtmid as VTM_ID,
    vtm.nm as VTM_Name,
    ing.strnt_nmrtr_val as StrengthNumerator,
    ing.strnt_nmrtr_uomcd as StrengthNumeratorUnit,
    ing.strnt_dnmtr_val as StrengthDenominator,
    ing.strnt_dnmtr_uomcd as StrengthDenominatorUnit
FROM vmp_ingredient ing
INNER JOIN vmp ON ing.vpid = vmp.vpid
LEFT JOIN vtm ON vmp.vtmid = vtm.vtmid
WHERE ing.isid = '373540008'
ORDER BY vmp.nm;
GO

-- Part 3: Find all Actual Medical Products (AMPs) - the actual branded/generic products
PRINT '';
PRINT 'Actual Medical Products (AMPs) containing Hydroxychloroquine:';
PRINT '================================================================';
SELECT DISTINCT
    amp.apid as AMP_ID,
    amp.nm as AMP_ProductName,
    amp.invalid as IsInvalid,
    vmp.vpid as VMP_ID,
    vmp.nm as VMP_Name,
    vtm.nm as VTM_Name,
    ing.strnt_nmrtr_val as StrengthNumerator,
    ing.strnt_nmrtr_uomcd as StrengthNumeratorUnit
FROM vmp_ingredient ing
INNER JOIN vmp ON ing.vpid = vmp.vpid
INNER JOIN amp ON vmp.vpid = amp.vpid
LEFT JOIN vtm ON vmp.vtmid = vtm.vtmid
WHERE ing.isid = '373540008'
ORDER BY amp.nm;
GO

-- Part 4: Count summary
PRINT '';
PRINT 'Summary:';
PRINT '========';
SELECT 
    'Total VMPs' as ProductType,
    COUNT(DISTINCT vmp.vpid) as Count
FROM vmp_ingredient ing
INNER JOIN vmp ON ing.vpid = vmp.vpid
WHERE ing.isid = '373540008'
UNION ALL
SELECT 
    'Total AMPs',
    COUNT(DISTINCT amp.apid)
FROM vmp_ingredient ing
INNER JOIN vmp ON ing.vpid = vmp.vpid
INNER JOIN amp ON vmp.vpid = amp.vpid
WHERE ing.isid = '373540008'
UNION ALL
SELECT 
    'Active VMPs',
    COUNT(DISTINCT vmp.vpid)
FROM vmp_ingredient ing
INNER JOIN vmp ON ing.vpid = vmp.vpid
WHERE ing.isid = '373540008' AND vmp.invalid = 0
UNION ALL
SELECT 
    'Active AMPs',
    COUNT(DISTINCT amp.apid)
FROM vmp_ingredient ing
INNER JOIN vmp ON ing.vpid = vmp.vpid
INNER JOIN amp ON vmp.vpid = amp.vpid
WHERE ing.isid = '373540008' AND amp.invalid = 0;
GO
