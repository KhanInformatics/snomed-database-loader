-- DM+D Sample Queries
-- These queries demonstrate how to explore and work with DM+D data

USE dmd;
GO

-- =====================================================
-- BASIC ENTITY EXPLORATION
-- =====================================================

-- 1. Overview of all entities in the database
SELECT 
    'VTM (Virtual Therapeutic Moiety)' as Entity_Type,
    COUNT(*) as Total_Count,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Count
FROM vtm
UNION ALL
SELECT 
    'VMP (Virtual Medical Product)',
    COUNT(*),
    COUNT(CASE WHEN invalid = 0 THEN 1 END)
FROM vmp
UNION ALL
SELECT 
    'AMP (Actual Medical Product)', 
    COUNT(*),
    COUNT(CASE WHEN invalid = 0 THEN 1 END)
FROM amp
UNION ALL
SELECT 
    'VMPP (Virtual Medical Product Pack)',
    COUNT(*),
    COUNT(CASE WHEN invalid = 0 THEN 1 END) 
FROM vmpp
UNION ALL
SELECT 
    'AMPP (Actual Medical Product Pack)',
    COUNT(*),
    COUNT(CASE WHEN invalid = 0 THEN 1 END)
FROM ampp;

-- 2. Sample VTMs (therapeutic ingredients)
SELECT TOP 20
    vtmid,
    nm as vtm_name,
    abbrevnm as abbreviation
FROM vtm 
WHERE invalid = 0 
  AND nm IS NOT NULL
ORDER BY nm;

-- 3. Sample VMPs with their VTM parent
SELECT TOP 20
    v.vpid,
    v.nm as vmp_name,
    t.nm as vtm_name,
    v.basiscd,
    v.pres_f as prescribable
FROM vmp v
LEFT JOIN vtm t ON v.vtmid = t.vtmid
WHERE v.invalid = 0
  AND v.nm IS NOT NULL
ORDER BY v.nm;

-- =====================================================
-- HIERARCHY EXPLORATION  
-- =====================================================

-- 4. Complete hierarchy for a specific VTM (example: Paracetamol)
-- Replace 'Paracetamol' with any VTM name of interest
WITH ParacetamolHierarchy AS (
    SELECT vtmid, nm as vtm_name
    FROM vtm 
    WHERE nm LIKE '%Paracetamol%' AND invalid = 0
)
SELECT 
    'VTM' as Level,
    CAST(ph.vtmid as VARCHAR(20)) as ID,
    ph.vtm_name as Name,
    NULL as Parent_Name
FROM ParacetamolHierarchy ph

UNION ALL

SELECT 
    'VMP' as Level,
    CAST(v.vpid as VARCHAR(20)) as ID,
    v.nm as Name,
    ph.vtm_name as Parent_Name
FROM ParacetamolHierarchy ph
JOIN vmp v ON ph.vtmid = v.vtmid
WHERE v.invalid = 0

UNION ALL

SELECT 
    'AMP' as Level,
    CAST(a.apid as VARCHAR(20)) as ID, 
    a.nm as Name,
    v.nm as Parent_Name
FROM ParacetamolHierarchy ph
JOIN vmp v ON ph.vtmid = v.vtmid  
JOIN amp a ON v.vpid = a.vpid
WHERE v.invalid = 0 AND a.invalid = 0

ORDER BY Level, Name;

-- 5. Pack sizes for products (VMPP and AMPP relationships)
SELECT TOP 20
    v.nm as vmp_name,
    vp.nm as vmpp_name,
    vp.qtyval as pack_quantity,
    l.desc_val as quantity_unit,
    COUNT(ap.appid) as actual_packs_available
FROM vmp v
JOIN vmpp vp ON v.vpid = vp.vpid
LEFT JOIN lookup l ON vp.qty_uomcd = l.cd AND l.cdtype = 'UNIT_OF_MEASURE'
LEFT JOIN ampp ap ON vp.vppid = ap.vppid AND ap.invalid = 0
WHERE v.invalid = 0 AND vp.invalid = 0
GROUP BY v.nm, vp.nm, vp.qtyval, l.desc_val
ORDER BY v.nm, vp.qtyval;

-- =====================================================
-- PRESCRIBING AND CLINICAL QUERIES
-- =====================================================

-- 6. Prescribable products (VMPs marked as prescribable)
SELECT TOP 50
    v.vpid,
    v.nm as product_name,
    t.nm as active_ingredient,
    CASE WHEN v.pres_f = 1 THEN 'Yes' ELSE 'No' END as prescribable,
    CASE WHEN v.sug_f = 1 THEN 'Yes' ELSE 'No' END as sugar_free
FROM vmp v
LEFT JOIN vtm t ON v.vtmid = t.vtmid  
WHERE v.invalid = 0 
  AND v.pres_f = 1  -- Only prescribable products
ORDER BY v.nm;

-- 7. Products with special characteristics
SELECT 
    characteristic,
    COUNT(*) as product_count,
    STRING_AGG(LEFT(nm, 50), '; ') as sample_products
FROM (
    SELECT 
        nm,
        CASE 
            WHEN sug_f = 1 THEN 'Sugar-free'
            WHEN glu_f = 1 THEN 'Gluten-free'  
            WHEN cfc_f = 1 THEN 'CFC-free'
            ELSE 'Standard'
        END as characteristic
    FROM vmp 
    WHERE invalid = 0 
      AND (sug_f = 1 OR glu_f = 1 OR cfc_f = 1)
) characteristics
GROUP BY characteristic
ORDER BY product_count DESC;

-- =====================================================
-- SUPPLIER AND COMMERCIAL QUERIES
-- =====================================================

-- 8. Products by supplier (using AMP supplier codes)
SELECT TOP 20
    l.desc_val as supplier_name,
    COUNT(a.apid) as product_count,
    STRING_AGG(LEFT(a.nm, 40), '; ') as sample_products
FROM amp a
JOIN lookup l ON a.suppcd = l.cd AND l.cdtype = 'SUPPLIER'
WHERE a.invalid = 0
  AND a.suppcd IS NOT NULL
GROUP BY l.desc_val
ORDER BY product_count DESC;

-- 9. Licensing authorities  
SELECT 
    l.desc_val as licensing_authority,
    COUNT(a.apid) as licensed_products
FROM amp a
JOIN lookup l ON a.lic_authcd = l.cd AND l.cdtype = 'LICENSING_AUTHORITY'
WHERE a.invalid = 0
  AND a.lic_authcd IS NOT NULL  
GROUP BY l.desc_val
ORDER BY licensed_products DESC;

-- =====================================================
-- SUPPLEMENTARY DATA QUERIES (BNF, ATC)
-- =====================================================

-- 10. BNF classifications (if supplementary data loaded)
SELECT TOP 20
    b.bnf_code,
    COUNT(DISTINCT b.vpid) as vmp_count,
    STRING_AGG(LEFT(v.nm, 30), '; ') as sample_vmps
FROM dmd_bnf b
JOIN vmp v ON b.vpid = v.vpid
WHERE v.invalid = 0
GROUP BY b.bnf_code
ORDER BY vmp_count DESC;

-- 11. ATC classifications (if supplementary data loaded)  
SELECT TOP 20
    a.atc_code,
    COUNT(DISTINCT a.vpid) as vmp_count,
    STRING_AGG(LEFT(v.nm, 30), '; ') as sample_vmps
FROM dmd_atc a
JOIN vmp v ON a.vpid = v.vpid  
WHERE v.invalid = 0
GROUP BY a.atc_code
ORDER BY vmp_count DESC;

-- =====================================================
-- DATA QUALITY AND ANALYSIS QUERIES
-- =====================================================

-- 12. Products with longest names (potential data quality issues)
SELECT TOP 10
    'VMP' as type,
    vpid as id,
    LEN(nm) as name_length,
    LEFT(nm, 100) as name_sample
FROM vmp 
WHERE invalid = 0
UNION ALL
SELECT TOP 10
    'AMP' as type,
    apid as id,
    LEN(nm) as name_length, 
    LEFT(nm, 100) as name_sample
FROM amp
WHERE invalid = 0
ORDER BY name_length DESC;

-- 13. Lookup table coverage analysis
SELECT 
    cdtype as lookup_type,
    COUNT(*) as total_values,
    COUNT(DISTINCT cd) as unique_codes,
    MIN(cd) as min_code,
    MAX(cd) as max_code,
    STRING_AGG(LEFT(desc_val, 20), '; ') as sample_descriptions
FROM lookup
GROUP BY cdtype
ORDER BY cdtype;

-- =====================================================
-- SEARCH AND FILTERING HELPERS
-- =====================================================

-- 14. Search for products containing specific terms
-- Example: Search for insulin products
DECLARE @SearchTerm NVARCHAR(100) = 'insulin';

SELECT 
    'VTM' as level,
    vtmid as id,
    nm as name
FROM vtm 
WHERE nm LIKE '%' + @SearchTerm + '%' AND invalid = 0
UNION ALL
SELECT 
    'VMP' as level,
    vpid as id, 
    nm as name
FROM vmp
WHERE nm LIKE '%' + @SearchTerm + '%' AND invalid = 0
UNION ALL  
SELECT
    'AMP' as level,
    apid as id,
    nm as name  
FROM amp
WHERE nm LIKE '%' + @SearchTerm + '%' AND invalid = 0
ORDER BY level, name;

-- 15. Recently added or modified products (if date fields populated)
SELECT TOP 20
    'VMP' as type,
    vpid as id,
    nm as name,
    nmdt as name_date
FROM vmp
WHERE invalid = 0 
  AND nmdt IS NOT NULL
UNION ALL
SELECT TOP 20
    'AMP' as type, 
    apid as id,
    nm as name,
    nmdt as name_date
FROM amp  
WHERE invalid = 0
  AND nmdt IS NOT NULL
ORDER BY name_date DESC;