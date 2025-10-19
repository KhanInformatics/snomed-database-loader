-- Advanced DM+D Analysis Queries
-- More complex queries for advanced DM+D data analysis

USE dmd;
GO

-- =====================================================
-- THERAPEUTIC ANALYSIS
-- =====================================================

-- 1. Therapeutic coverage - VTMs with most product variations
SELECT TOP 20
    t.vtmid,
    t.nm as therapeutic_moiety,
    COUNT(DISTINCT v.vpid) as vmp_count,
    COUNT(DISTINCT a.apid) as amp_count,
    COUNT(DISTINCT vp.vppid) as pack_variations,
    COUNT(DISTINCT ap.appid) as commercial_packs
FROM vtm t
LEFT JOIN vmp v ON t.vtmid = v.vtmid AND v.invalid = 0
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0  
LEFT JOIN vmpp vp ON v.vpid = vp.vpid AND vp.invalid = 0
LEFT JOIN ampp ap ON vp.vppid = ap.vppid AND ap.invalid = 0
WHERE t.invalid = 0
GROUP BY t.vtmid, t.nm
ORDER BY vmp_count DESC, amp_count DESC;

-- 2. Combination products analysis
SELECT TOP 20
    v.vpid,
    v.nm as product_name,
    COUNT(vi.isid) as ingredient_count,
    STRING_AGG(CAST(vi.isid as VARCHAR(20)), ', ') as ingredient_ids
FROM vmp v
JOIN vmp_ingredient vi ON v.vpid = vi.vpid
WHERE v.invalid = 0
GROUP BY v.vpid, v.nm
HAVING COUNT(vi.isid) > 1  -- Only combination products
ORDER BY ingredient_count DESC;

-- 3. Route of administration analysis  
SELECT 
    l.desc_val as administration_route,
    COUNT(DISTINCT vr.vpid) as vmp_count,
    STRING_AGG(LEFT(v.nm, 40), '; ') as sample_products
FROM vmp_drugroute vr
JOIN lookup l ON vr.routecd = l.cd AND l.cdtype = 'ROUTE' 
JOIN vmp v ON vr.vpid = v.vpid
WHERE v.invalid = 0
GROUP BY l.desc_val
ORDER BY vmp_count DESC;

-- 4. Pharmaceutical form analysis
SELECT 
    l.desc_val as pharmaceutical_form,
    COUNT(DISTINCT vf.vpid) as vmp_count,
    STRING_AGG(LEFT(v.nm, 40), '; ') as sample_products  
FROM vmp_drugform vf
JOIN lookup l ON vf.formcd = l.cd AND l.cdtype = 'FORM'
JOIN vmp v ON vf.vpid = v.vpid  
WHERE v.invalid = 0
GROUP BY l.desc_val
ORDER BY vmp_count DESC;

-- =====================================================
-- MARKET ANALYSIS
-- =====================================================

-- 5. Generic vs branded product analysis
SELECT 
    product_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM (
    SELECT 
        CASE 
            WHEN a.nm LIKE v.nm + '%' THEN 'Generic/Similar'
            WHEN LEN(a.nm) > LEN(v.nm) + 10 THEN 'Branded'  
            ELSE 'Other'
        END as product_type
    FROM amp a
    JOIN vmp v ON a.vpid = v.vpid
    WHERE a.invalid = 0 AND v.invalid = 0
) classification
GROUP BY product_type
ORDER BY count DESC;

-- 6. Supplier market share (top suppliers by product count)
SELECT TOP 15
    COALESCE(l.desc_val, 'Unknown Supplier') as supplier,
    COUNT(DISTINCT a.apid) as unique_products,
    COUNT(DISTINCT ap.appid) as total_pack_sizes,
    ROUND(COUNT(DISTINCT a.apid) * 100.0 / SUM(COUNT(DISTINCT a.apid)) OVER(), 2) as market_share_percent
FROM amp a
LEFT JOIN lookup l ON a.suppcd = l.cd AND l.cdtype = 'SUPPLIER'
LEFT JOIN ampp ap ON a.apid = ap.apid AND ap.invalid = 0
WHERE a.invalid = 0
GROUP BY COALESCE(l.desc_val, 'Unknown Supplier')
ORDER BY unique_products DESC;

-- 7. Pack size distribution analysis  
SELECT 
    pack_size_category,
    COUNT(*) as pack_count,
    AVG(qtyval) as avg_quantity,
    MIN(qtyval) as min_quantity,
    MAX(qtyval) as max_quantity
FROM (
    SELECT 
        qtyval,
        CASE 
            WHEN qtyval <= 10 THEN 'Small (≤10)'
            WHEN qtyval <= 30 THEN 'Medium (11-30)'
            WHEN qtyval <= 100 THEN 'Large (31-100)'  
            WHEN qtyval > 100 THEN 'Extra Large (>100)'
            ELSE 'Unknown'
        END as pack_size_category
    FROM vmpp
    WHERE invalid = 0 AND qtyval IS NOT NULL AND qtyval > 0
) pack_analysis
GROUP BY pack_size_category
ORDER BY avg_quantity;

-- =====================================================
-- CLINICAL DECISION SUPPORT
-- =====================================================

-- 8. Sugar-free alternatives finder
-- For each VTM that has sugar-free options, show both regular and sugar-free VMPs
SELECT 
    t.nm as therapeutic_moiety,
    v.nm as product_name,
    CASE WHEN v.sug_f = 1 THEN 'Sugar-free' ELSE 'Regular' END as formulation,
    COUNT(a.apid) as available_amps
FROM vtm t
JOIN vmp v ON t.vtmid = v.vtmid
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
WHERE t.vtmid IN (
    -- VTMs that have at least one sugar-free option
    SELECT DISTINCT v2.vtmid 
    FROM vmp v2 
    WHERE v2.sug_f = 1 AND v2.invalid = 0
)
AND v.invalid = 0
GROUP BY t.nm, v.nm, v.sug_f
ORDER BY t.nm, v.sug_f DESC;

-- 9. Controlled drug analysis (prescription status)
SELECT 
    l.desc_val as prescription_status,
    COUNT(DISTINCT v.vpid) as vmp_count,
    COUNT(DISTINCT a.apid) as amp_count,
    STRING_AGG(LEFT(v.nm, 30), '; ') as sample_products
FROM vmp v  
LEFT JOIN lookup l ON v.pres_statcd = l.cd AND l.cdtype = 'PRESCRIPTION_STATUS'
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
WHERE v.invalid = 0 AND v.pres_statcd IS NOT NULL
GROUP BY l.desc_val
ORDER BY vmp_count DESC;

-- 10. Cross-reference with BNF chapters (if supplementary data available)
SELECT 
    LEFT(b.bnf_code, 2) as bnf_chapter,
    COUNT(DISTINCT b.vpid) as vmp_count,
    COUNT(DISTINCT a.apid) as amp_count,
    STRING_AGG(LEFT(v.nm, 25), '; ') as sample_vmps
FROM dmd_bnf b
JOIN vmp v ON b.vpid = v.vpid  
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
WHERE v.invalid = 0
GROUP BY LEFT(b.bnf_code, 2)  
ORDER BY bnf_chapter;

-- =====================================================
-- DATA COMPLETENESS ANALYSIS
-- =====================================================

-- 11. Data completeness scorecard
SELECT 
    'VTM Names' as data_element,
    COUNT(*) as total_records,
    COUNT(CASE WHEN nm IS NOT NULL AND LEN(nm) > 0 THEN 1 END) as populated_records,
    ROUND(COUNT(CASE WHEN nm IS NOT NULL AND LEN(nm) > 0 THEN 1 END) * 100.0 / COUNT(*), 2) as completeness_percent
FROM vtm WHERE invalid = 0

UNION ALL

SELECT 
    'VMP Prescribing Status',
    COUNT(*),
    COUNT(CASE WHEN pres_statcd IS NOT NULL THEN 1 END),
    ROUND(COUNT(CASE WHEN pres_statcd IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2)
FROM vmp WHERE invalid = 0

UNION ALL

SELECT 
    'AMP Supplier Codes', 
    COUNT(*),
    COUNT(CASE WHEN suppcd IS NOT NULL THEN 1 END),
    ROUND(COUNT(CASE WHEN suppcd IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2)  
FROM amp WHERE invalid = 0

UNION ALL

SELECT 
    'VMPP Pack Quantities',
    COUNT(*), 
    COUNT(CASE WHEN qtyval IS NOT NULL AND qtyval > 0 THEN 1 END),
    ROUND(COUNT(CASE WHEN qtyval IS NOT NULL AND qtyval > 0 THEN 1 END) * 100.0 / COUNT(*), 2)
FROM vmpp WHERE invalid = 0

ORDER BY completeness_percent DESC;

-- 12. Orphaned records analysis (records without valid parents)
SELECT 
    'VMPs without VTM' as issue_type,
    COUNT(*) as count
FROM vmp v
LEFT JOIN vtm t ON v.vtmid = t.vtmid
WHERE v.invalid = 0 AND v.vtmid IS NOT NULL AND t.vtmid IS NULL

UNION ALL

SELECT 
    'AMPs without VMP',
    COUNT(*)  
FROM amp a
LEFT JOIN vmp v ON a.vpid = v.vpid
WHERE a.invalid = 0 AND a.vpid IS NOT NULL AND v.vpid IS NULL

UNION ALL

SELECT
    'VMPPs without VMP', 
    COUNT(*)
FROM vmpp vp
LEFT JOIN vmp v ON vp.vpid = v.vpid  
WHERE vp.invalid = 0 AND vp.vpid IS NOT NULL AND v.vpid IS NULL

UNION ALL

SELECT
    'AMPPs without VMPP',
    COUNT(*)
FROM ampp ap  
LEFT JOIN vmpp vp ON ap.vppid = vp.vppid
WHERE ap.invalid = 0 AND ap.vppid IS NOT NULL AND vp.vppid IS NULL

ORDER BY count DESC;

-- =====================================================
-- TEMPORAL ANALYSIS (if date fields are populated)  
-- =====================================================

-- 13. Product lifecycle analysis  
SELECT 
    YEAR(nmdt) as year_added,
    COUNT(*) as products_added,
    STRING_AGG(LEFT(nm, 30), '; ') as sample_products
FROM vmp
WHERE invalid = 0 
  AND nmdt IS NOT NULL
  AND nmdt >= '2020-01-01'  -- Adjust date range as needed
GROUP BY YEAR(nmdt)
ORDER BY year_added DESC;

-- 14. Recently invalidated products
SELECT TOP 20
    'VMP' as type,
    vpid as id,
    nm as name,  
    nmdt as last_modified
FROM vmp
WHERE invalid = 1 AND nmdt IS NOT NULL
UNION ALL
SELECT TOP 20  
    'AMP' as type,
    apid as id,
    nm as name,
    nmdt as last_modified  
FROM amp  
WHERE invalid = 1 AND nmdt IS NOT NULL
ORDER BY last_modified DESC;

-- 15. Lookup code usage frequency
SELECT TOP 20
    l.cdtype,
    l.cd,
    l.desc_val,
    usage_count,
    RANK() OVER (PARTITION BY l.cdtype ORDER BY usage_count DESC) as rank_in_category
FROM lookup l
CROSS APPLY (
    SELECT COUNT(*) as usage_count FROM (
        SELECT basiscd as code FROM vmp WHERE basiscd = l.cd
        UNION ALL
        SELECT pres_statcd FROM vmp WHERE pres_statcd = l.cd  
        UNION ALL
        SELECT suppcd FROM amp WHERE suppcd = l.cd
        UNION ALL  
        SELECT lic_authcd FROM amp WHERE lic_authcd = l.cd
        UNION ALL
        SELECT qty_uomcd FROM vmpp WHERE qty_uomcd = l.cd
        UNION ALL
        SELECT legal_catcd FROM ampp WHERE legal_catcd = l.cd
    ) usage
) usage_calc
WHERE usage_count > 0
ORDER BY l.cdtype, usage_count DESC;