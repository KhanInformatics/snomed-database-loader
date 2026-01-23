-- Query to find all VTMs and VMPs where the active ingredient is Ciclosporin
-- This query searches for Ciclosporin (and common spelling variations) as an ingredient

USE dmd;
GO

-- =====================================================
-- PART 1: Find Ciclosporin Ingredient IDs
-- =====================================================

-- Find all ingredient IDs that contain Ciclosporin (including spelling variations)
SELECT 
    isid,
    nm as ingredient_name,
    invalid
FROM ingredient
WHERE nm LIKE '%Ciclosporin%' 
   OR nm LIKE '%Cyclosporin%'  -- Alternative spelling
   OR nm LIKE '%Ciclosporine%'
   OR nm LIKE '%Cyclosporine%'
ORDER BY nm;

PRINT '';
PRINT '===== VTMs (Virtual Therapeutic Moieties) containing Ciclosporin =====';
PRINT '';

-- =====================================================
-- PART 2: VTMs containing Ciclosporin
-- =====================================================

-- Get all VTMs that contain Ciclosporin
SELECT 
    vtm.vtmid,
    vtm.nm as vtm_name,
    vtm.abbrevnm as abbreviated_name,
    CASE WHEN vtm.invalid = 1 THEN 'Inactive' ELSE 'Active' END as status
FROM vtm
WHERE vtm.nm LIKE '%Ciclosporin%' 
   OR vtm.nm LIKE '%Cyclosporin%'
   OR vtm.nm LIKE '%Ciclosporine%'
   OR vtm.nm LIKE '%Cyclosporine%'
ORDER BY vtm.nm;

PRINT '';
PRINT '===== VMPs (Virtual Medicinal Products) containing Ciclosporin =====';
PRINT '';

-- =====================================================
-- PART 3: VMPs containing Ciclosporin as ingredient
-- =====================================================

-- Get all VMPs where Ciclosporin is an active ingredient
-- This joins through the ingredient table to find the actual ingredient relationships
SELECT 
    vmp.vpid as vmp_id,
    vmp.nm as vmp_name,
    vtm.vtmid as vtm_id,
    vtm.nm as vtm_name,
    CASE WHEN vmp.pres_f = 1 THEN 'Yes' ELSE 'No' END as prescribable,
    CASE WHEN vmp.invalid = 1 THEN 'Inactive' ELSE 'Active' END as status,
    vmp_ingredient.strnt_nmrtr_val as strength_numerator,
    vmp_ingredient.strnt_nmrtr_uomcd as strength_numerator_unit,
    vmp_ingredient.strnt_dnmtr_val as strength_denominator,
    vmp_ingredient.strnt_dnmtr_uomcd as strength_denominator_unit,
    ingredient.nm as ingredient_name
FROM vmp
INNER JOIN vmp_ingredient ON vmp.vpid = vmp_ingredient.vpid
INNER JOIN ingredient ON vmp_ingredient.isid = ingredient.isid
LEFT JOIN vtm ON vmp.vtmid = vtm.vtmid
WHERE ingredient.nm LIKE '%Ciclosporin%' 
   OR ingredient.nm LIKE '%Cyclosporin%'
   OR ingredient.nm LIKE '%Ciclosporine%'
   OR ingredient.nm LIKE '%Cyclosporine%'
ORDER BY vmp.nm;

PRINT '';
PRINT '===== Summary Statistics =====';
PRINT '';

-- =====================================================
-- PART 4: Summary Statistics
-- =====================================================

-- Count of active VTMs
SELECT 
    'Active VTMs containing Ciclosporin' as category,
    COUNT(*) as count
FROM vtm
WHERE (vtm.nm LIKE '%Ciclosporin%' 
    OR vtm.nm LIKE '%Cyclosporin%'
    OR vtm.nm LIKE '%Ciclosporine%'
    OR vtm.nm LIKE '%Cyclosporine%')
  AND vtm.invalid = 0

UNION ALL

-- Count of active VMPs
SELECT 
    'Active VMPs containing Ciclosporin' as category,
    COUNT(DISTINCT vmp.vpid) as count
FROM vmp
INNER JOIN vmp_ingredient ON vmp.vpid = vmp_ingredient.vpid
INNER JOIN ingredient ON vmp_ingredient.isid = ingredient.isid
WHERE (ingredient.nm LIKE '%Ciclosporin%' 
    OR ingredient.nm LIKE '%Cyclosporin%'
    OR ingredient.nm LIKE '%Ciclosporine%'
    OR ingredient.nm LIKE '%Cyclosporine%')
  AND vmp.invalid = 0

UNION ALL

-- Count of prescribable VMPs
SELECT 
    'Prescribable VMPs containing Ciclosporin' as category,
    COUNT(DISTINCT vmp.vpid) as count
FROM vmp
INNER JOIN vmp_ingredient ON vmp.vpid = vmp_ingredient.vpid
INNER JOIN ingredient ON vmp_ingredient.isid = ingredient.isid
WHERE (ingredient.nm LIKE '%Ciclosporin%' 
    OR ingredient.nm LIKE '%Cyclosporin%'
    OR ingredient.nm LIKE '%Ciclosporine%'
    OR ingredient.nm LIKE '%Cyclosporine%')
  AND vmp.invalid = 0
  AND vmp.pres_f = 1;

PRINT '';
PRINT '===== VMPs grouped by route of administration =====';
PRINT '';

-- =====================================================
-- PART 5: VMPs by Route of Administration
-- =====================================================

-- Get VMPs grouped by route (optional - only if route data exists)
SELECT 
    vmp_drugroute.routecd as route_code,
    COUNT(DISTINCT vmp.vpid) as vmp_count,
    STRING_AGG(CAST(LEFT(vmp.nm, 60) AS NVARCHAR(MAX)), '; ') as sample_vmps
FROM vmp
INNER JOIN vmp_ingredient ON vmp.vpid = vmp_ingredient.vpid
INNER JOIN ingredient ON vmp_ingredient.isid = ingredient.isid
LEFT JOIN vmp_drugroute ON vmp.vpid = vmp_drugroute.vpid
WHERE (ingredient.nm LIKE '%Ciclosporin%' 
    OR ingredient.nm LIKE '%Cyclosporin%'
    OR ingredient.nm LIKE '%Ciclosporine%'
    OR ingredient.nm LIKE '%Cyclosporine%')
  AND vmp.invalid = 0
GROUP BY vmp_drugroute.routecd
ORDER BY vmp_count DESC;

PRINT '';
PRINT 'Query completed.';
