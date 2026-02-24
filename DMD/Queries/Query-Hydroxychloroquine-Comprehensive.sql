-- Comprehensive query for Hydroxychloroquine products in DMD
-- Searches by VTM (Virtual Therapeutic Moiety) ID: 776273003
-- Active Ingredient SNOMED ID: 373540008

USE dmd;
GO

-- ==============================================================
-- PART 1: All Hydroxychloroquine Products (AMPs)
-- ==============================================================
PRINT 'All Hydroxychloroquine Products (AMPs):';
PRINT '=====================================================';
SELECT 
    amp.apid as [AMP_ID],
    amp.nm as [Product_Name],
    CASE WHEN amp.invalid = 0 THEN 'Active' ELSE 'Inactive' END as [Status],
    vmp.nm as [Generic_Product_VMP]
FROM amp
INNER JOIN vmp ON amp.vpid = vmp.vpid
INNER JOIN vtm ON vmp.vtmid = vtm.vtmid
WHERE vtm.vtmid = '776273003'  -- Hydroxychloroquine VTM
ORDER BY amp.nm;
GO

-- ==============================================================
-- PART 2: Branded Products Only
-- ==============================================================
PRINT '';
PRINT 'Branded Hydroxychloroquine Products:';
PRINT '=====================================================';
SELECT 
    amp.apid as [AMP_ID],
    amp.nm as [Product_Name],
    CASE WHEN amp.invalid = 0 THEN 'Active' ELSE 'Inactive' END as [Status]
FROM amp
INNER JOIN vmp ON amp.vpid = vmp.vpid
INNER JOIN vtm ON vmp.vtmid = vtm.vtmid
WHERE vtm.vtmid = '776273003'
    AND amp.nm NOT LIKE 'Hydroxychloroquine %'  -- Exclude generic names
ORDER BY amp.nm;
GO

-- ==============================================================
-- PART 3: Products by Formulation Type
-- ==============================================================
PRINT '';
PRINT 'Products by Formulation:';
PRINT '=====================================================';
SELECT 
    CASE 
        WHEN amp.nm LIKE '%tablets%' THEN 'Tablet'
        WHEN amp.nm LIKE '%oral solution%' THEN 'Oral Solution'
        WHEN amp.nm LIKE '%oral suspension%' THEN 'Oral Suspension'
        ELSE 'Other'
    END as [Formulation],
    COUNT(*) as [Count]
FROM amp
INNER JOIN vmp ON amp.vpid = vmp.vpid
WHERE vmp.vtmid = '776273003'
GROUP BY 
    CASE 
        WHEN amp.nm LIKE '%tablets%' THEN 'Tablet'
        WHEN amp.nm LIKE '%oral solution%' THEN 'Oral Solution'
        WHEN amp.nm LIKE '%oral suspension%' THEN 'Oral Suspension'
        ELSE 'Other'
    END
ORDER BY [Count] DESC;
GO

-- ==============================================================
-- PART 4: Tablet Strengths
-- ==============================================================
PRINT '';
PRINT 'Hydroxychloroquine Tablet Strengths:';
PRINT '=====================================================';
SELECT DISTINCT
    CASE 
        WHEN amp.nm LIKE '%200mg%' THEN '200mg'
        WHEN amp.nm LIKE '%300mg%' THEN '300mg'
        ELSE 'Other'
    END as [Strength],
    COUNT(*) as [Number_of_Products]
FROM amp
INNER JOIN vmp ON amp.vpid = vmp.vpid
WHERE vmp.vtmid = '776273003'
    AND amp.nm LIKE '%tablets%'
GROUP BY 
    CASE 
        WHEN amp.nm LIKE '%200mg%' THEN '200mg'
        WHEN amp.nm LIKE '%300mg%' THEN '300mg'
        ELSE 'Other'
    END
ORDER BY [Strength];
GO

-- ==============================================================
-- PART 5: Virtual Medical Products (VMPs)
-- ==============================================================
PRINT '';
PRINT 'Virtual Medical Products (Generic Concepts):';
PRINT '=====================================================';
SELECT 
    vmp.vpid as [VMP_ID],
    vmp.nm as [Generic_Product],
    CASE WHEN vmp.invalid = 0 THEN 'Active' ELSE 'Inactive' END as [Status],
    vtm.nm as [VTM_Name]
FROM vmp
INNER JOIN vtm ON vmp.vtmid = vtm.vtmid
WHERE vtm.vtmid = '776273003'
ORDER BY vmp.nm;
GO

-- ==============================================================
-- PART 6: Product Packs (AMPPs) if any
-- ==============================================================
PRINT '';
PRINT 'Hydroxychloroquine Product Packs (AMPPs):';
PRINT '=====================================================';
SELECT 
    ampp.appid as [AMPP_ID],
    ampp.nm as [Pack_Name],
    amp.nm as [Product_Name],
    CASE WHEN ampp.invalid = 0 THEN 'Active' ELSE 'Inactive' END as [Status]
FROM ampp
INNER JOIN amp ON ampp.apid = amp.apid
INNER JOIN vmp ON amp.vpid = vmp.vpid
WHERE vmp.vtmid = '776273003'
ORDER BY ampp.nm;
GO
