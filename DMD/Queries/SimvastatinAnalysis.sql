-- Simvastatin Product Analysis
-- Compares products containing ONLY simvastatin vs combination products with simvastatin
-- Uses VMP-ingredient relationships to determine single vs multi-ingredient products

USE dmd;
GO

-- =====================================================
-- PART 1: Find ALL Simvastatin Ingredient IDs
-- =====================================================

-- Create temp table to store all simvastatin-related ingredient IDs
IF OBJECT_ID('tempdb..#SimvastatinIngredients') IS NOT NULL DROP TABLE #SimvastatinIngredients;
CREATE TABLE #SimvastatinIngredients (isid BIGINT);

-- Insert all simvastatin-related ingredients
INSERT INTO #SimvastatinIngredients
SELECT isid
FROM ingredient
WHERE nm LIKE '%Simvastatin%';

-- Display the ingredients we found
SELECT 
    i.isid,
    i.nm as ingredient_name
FROM ingredient i
INNER JOIN #SimvastatinIngredients s ON i.isid = s.isid
ORDER BY i.nm;

-- =====================================================
-- PART 2: Simvastatin ONLY Products (Single Ingredient)
-- =====================================================

PRINT '';
PRINT '===== SIMVASTATIN ONLY (Single Ingredient Products) =====';
PRINT '';

WITH SimvastatinOnlyVMPs AS (
    -- Get VMPs where simvastatin is the ONLY ingredient
    SELECT 
        v.vpid,
        v.nm as vmp_name,
        v.pres_f as prescribable,
        COUNT(vi.isid) as ingredient_count
    FROM vmp v
    LEFT JOIN vmp_ingredient vi ON v.vpid = vi.vpid
    WHERE EXISTS (
        SELECT 1 
        FROM vmp_ingredient vi_check
        INNER JOIN #SimvastatinIngredients s ON vi_check.isid = s.isid
        WHERE vi_check.vpid = v.vpid
    )
      AND v.invalid = 0
    GROUP BY v.vpid, v.nm, v.pres_f
    HAVING COUNT(vi.isid) = 1  -- Exactly one ingredient
)
SELECT 
    'VMP' as product_type,
    v.vpid as product_id,
    v.vmp_name,
    CASE WHEN v.prescribable = 1 THEN 'Yes' ELSE 'No' END as prescribable,
    v.ingredient_count,
    COUNT(DISTINCT a.apid) as actual_products_count,
    STRING_AGG(CAST(LEFT(a.nm, 60) AS NVARCHAR(MAX)), '; ') as sample_amps
FROM SimvastatinOnlyVMPs v
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
GROUP BY v.vpid, v.vmp_name, v.prescribable, v.ingredient_count
ORDER BY v.vmp_name;

-- Summary statistics for simvastatin-only products
SELECT 
    'SUMMARY: Simvastatin ONLY Products' as summary_type,
    COUNT(DISTINCT v.vpid) as vmp_count,
    COUNT(DISTINCT a.apid) as amp_count,
    COUNT(DISTINCT CASE WHEN v.prescribable = 1 THEN v.vpid END) as prescribable_vmp_count
FROM (
    SELECT 
        v.vpid,
        v.nm,
        v.pres_f as prescribable,
        COUNT(vi.isid) as ingredient_count
    FROM vmp v
    LEFT JOIN vmp_ingredient vi ON v.vpid = vi.vpid
    WHERE EXISTS (
        SELECT 1 
        FROM vmp_ingredient vi_check
        INNER JOIN #SimvastatinIngredients s ON vi_check.isid = s.isid
        WHERE vi_check.vpid = v.vpid
    )
      AND v.invalid = 0
    GROUP BY v.vpid, v.nm, v.pres_f
    HAVING COUNT(vi.isid) = 1
) v
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0;

-- =====================================================
-- PART 3: Simvastatin COMBINATION Products
-- =====================================================

PRINT '';
PRINT '===== SIMVASTATIN COMBINATIONS (Multi-Ingredient Products) =====';
PRINT '';

WITH SimvastatinCombinationVMPs AS (
    -- Get VMPs where simvastatin is ONE OF multiple ingredients
    SELECT 
        v.vpid,
        v.nm as vmp_name,
        v.pres_f as prescribable,
        COUNT(vi.isid) as ingredient_count
    FROM vmp v
    INNER JOIN vmp_ingredient vi ON v.vpid = vi.vpid
    WHERE v.invalid = 0
    GROUP BY v.vpid, v.nm, v.pres_f
    HAVING COUNT(vi.isid) > 1  -- Multiple ingredients
),
SimvastatinCombinations AS (
    -- Filter to only those combinations that include simvastatin as an ingredient
    SELECT DISTINCT sc.vpid
    FROM SimvastatinCombinationVMPs sc
    INNER JOIN vmp_ingredient vi ON sc.vpid = vi.vpid
    INNER JOIN #SimvastatinIngredients s ON vi.isid = s.isid
)
SELECT 
    'VMP' as product_type,
    v.vpid as product_id,
    v.vmp_name,
    CASE WHEN v.prescribable = 1 THEN 'Yes' ELSE 'No' END as prescribable,
    v.ingredient_count,
    -- List all ingredients for this combination
    (
        SELECT STRING_AGG(CAST(i2.nm AS NVARCHAR(MAX)), ' + ')
        FROM vmp_ingredient vi2
        INNER JOIN ingredient i2 ON vi2.isid = i2.isid
        WHERE vi2.vpid = v.vpid
    ) as all_ingredients,
    COUNT(DISTINCT a.apid) as actual_products_count,
    STRING_AGG(CAST(LEFT(a.nm, 60) AS NVARCHAR(MAX)), '; ') as sample_amps
FROM SimvastatinCombinationVMPs v
INNER JOIN SimvastatinCombinations sc ON v.vpid = sc.vpid
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
GROUP BY v.vpid, v.vmp_name, v.prescribable, v.ingredient_count
ORDER BY v.vmp_name;

-- Summary statistics for combination products
WITH SimvastatinCombinationVMPs2 AS (
    SELECT 
        v.vpid,
        v.nm as vmp_name,
        v.pres_f as prescribable,
        COUNT(vi.isid) as ingredient_count
    FROM vmp v
    INNER JOIN vmp_ingredient vi ON v.vpid = vi.vpid
    WHERE v.invalid = 0
    GROUP BY v.vpid, v.nm, v.pres_f
    HAVING COUNT(vi.isid) > 1
),
SimvastatinCombinations2 AS (
    SELECT DISTINCT sc.vpid
    FROM SimvastatinCombinationVMPs2 sc
    INNER JOIN vmp_ingredient vi ON sc.vpid = vi.vpid
    INNER JOIN #SimvastatinIngredients s ON vi.isid = s.isid
)
SELECT 
    'SUMMARY: Simvastatin COMBINATION Products' as summary_type,
    COUNT(DISTINCT v.vpid) as vmp_count,
    COUNT(DISTINCT a.apid) as amp_count,
    COUNT(DISTINCT CASE WHEN v.prescribable = 1 THEN v.vpid END) as prescribable_vmp_count
FROM SimvastatinCombinationVMPs2 v
INNER JOIN SimvastatinCombinations2 combos ON v.vpid = combos.vpid
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0;

-- =====================================================
-- PART 4: ALL Simvastatin Products (Combined View)
-- =====================================================

PRINT '';
PRINT '===== ALL SIMVASTATIN PRODUCTS (Single + Combination) =====';
PRINT '';

WITH AllSimvastatinVMPs AS (
    -- Get ALL VMPs containing simvastatin with their total ingredient count
    SELECT 
        v.vpid,
        v.nm as vmp_name,
        v.pres_f as prescribable,
        COUNT(vi_all.isid) as total_ingredient_count,
        CASE 
            WHEN COUNT(vi_all.isid) = 1 THEN 'Single'
            ELSE 'Combination'
        END as product_category,
        (
            SELECT STRING_AGG(CAST(i_list.nm AS NVARCHAR(MAX)), ' + ')
            FROM vmp_ingredient vi_list
            INNER JOIN ingredient i_list ON vi_list.isid = i_list.isid
            WHERE vi_list.vpid = v.vpid
        ) as ingredient_list
    FROM vmp v
    INNER JOIN vmp_ingredient vi ON v.vpid = vi.vpid
    INNER JOIN #SimvastatinIngredients s ON vi.isid = s.isid
    LEFT JOIN vmp_ingredient vi_all ON v.vpid = vi_all.vpid  -- Count ALL ingredients
    WHERE v.invalid = 0
    GROUP BY v.vpid, v.nm, v.pres_f
)
SELECT 
    av.product_category,
    av.vpid as product_id,
    av.vmp_name,
    av.ingredient_list,
    CASE WHEN av.prescribable = 1 THEN 'Yes' ELSE 'No' END as prescribable,
    av.total_ingredient_count as ingredient_count,
    COUNT(DISTINCT a.apid) as actual_products_count
FROM AllSimvastatinVMPs av
LEFT JOIN amp a ON av.vpid = a.vpid AND a.invalid = 0
GROUP BY av.product_category, av.vpid, av.vmp_name, av.ingredient_list, av.prescribable, av.total_ingredient_count
ORDER BY av.product_category, av.vmp_name;

-- =====================================================
-- PART 5: Grand Summary with Comparison
-- =====================================================

PRINT '';
PRINT '===== GRAND SUMMARY =====';
PRINT '';

SELECT 
    category,
    vmp_count,
    amp_count,
    prescribable_vmp_count,
    CAST(ROUND(100.0 * vmp_count / SUM(vmp_count) OVER (), 1) AS DECIMAL(5,1)) as vmp_percentage,
    CAST(ROUND(100.0 * amp_count / SUM(amp_count) OVER (), 1) AS DECIMAL(5,1)) as amp_percentage
FROM (
    -- Single ingredient count
    SELECT 
        'Simvastatin ONLY' as category,
        COUNT(DISTINCT v.vpid) as vmp_count,
        COUNT(DISTINCT a.apid) as amp_count,
        COUNT(DISTINCT CASE WHEN v.prescribable = 1 THEN v.vpid END) as prescribable_vmp_count
    FROM (
        SELECT 
            v.vpid,
            v.pres_f as prescribable
        FROM vmp v
        INNER JOIN vmp_ingredient vi ON v.vpid = vi.vpid
        INNER JOIN #SimvastatinIngredients simv ON vi.isid = simv.isid
        WHERE v.invalid = 0
        GROUP BY v.vpid, v.pres_f
        HAVING COUNT(vi.isid) = 1
    ) v
    LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
    
    UNION ALL
    
    -- Combination products count
    SELECT 
        'Simvastatin COMBINATION' as category,
        COUNT(DISTINCT v.vpid) as vmp_count,
        COUNT(DISTINCT a.apid) as amp_count,
        COUNT(DISTINCT CASE WHEN v.prescribable = 1 THEN v.vpid END) as prescribable_vmp_count
    FROM (
        SELECT 
            v.vpid,
            v.pres_f as prescribable
        FROM vmp v
        INNER JOIN vmp_ingredient vi ON v.vpid = vi.vpid
        WHERE v.invalid = 0
        GROUP BY v.vpid, v.pres_f
        HAVING COUNT(vi.isid) > 1
    ) v
    INNER JOIN (
        SELECT DISTINCT vi.vpid
        FROM vmp_ingredient vi
        INNER JOIN #SimvastatinIngredients s ON vi.isid = s.isid
    ) simv ON v.vpid = simv.vpid
    LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
) summary
ORDER BY category;

-- =====================================================
-- PART 6: Most Common Combination Partners
-- =====================================================

PRINT '';
PRINT '===== MOST COMMON SIMVASTATIN COMBINATION PARTNERS =====';
PRINT '';

SELECT 
    i.nm as partner_ingredient,
    COUNT(DISTINCT v.vpid) as vmp_count,
    STRING_AGG(CAST(LEFT(v.nm, 50) AS NVARCHAR(MAX)), '; ') as sample_products
FROM vmp v
INNER JOIN vmp_ingredient vi ON v.vpid = vi.vpid
INNER JOIN ingredient i ON vi.isid = i.isid
WHERE v.vpid IN (
    -- Get VMPs that contain simvastatin as an ingredient
    SELECT DISTINCT vi2.vpid
    FROM vmp_ingredient vi2
    INNER JOIN #SimvastatinIngredients s ON vi2.isid = s.isid
)
  AND NOT EXISTS (
    -- Exclude simvastatin ingredients themselves
    SELECT 1 FROM #SimvastatinIngredients s WHERE s.isid = i.isid
  )
  AND v.invalid = 0
  AND EXISTS (
    -- Only include VMPs that have multiple ingredients (combinations)
    SELECT 1
    FROM vmp_ingredient vi_check
    WHERE vi_check.vpid = v.vpid
    GROUP BY vi_check.vpid
    HAVING COUNT(vi_check.isid) > 1
  )
GROUP BY i.nm, i.isid
ORDER BY vmp_count DESC, i.nm;

-- Clean up temp table
DROP TABLE #SimvastatinIngredients;
