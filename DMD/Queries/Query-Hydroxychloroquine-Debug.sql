-- Debug query to understand DMD structure for Hydroxychloroquine

USE dmd;
GO

-- Check 1: Look for Hydroxychloroquine in VTM table (Virtual Therapeutic Moiety)
PRINT 'VTMs containing "Hydroxychloroquine":';
SELECT vtmid, nm, invalid
FROM vtm
WHERE nm LIKE '%Hydroxychlor%'
ORDER BY nm;
GO

-- Check 2: Search ingredient table for similar names
PRINT '';
PRINT 'Ingredients containing "Hydroxychlor":';
SELECT isid, nm, invalid
FROM ingredient
WHERE nm LIKE '%Hydroxychlor%'
ORDER BY nm;
GO

-- Check 3: Sample of vmp_ingredient table to see data structure
PRINT '';
PRINT 'Sample of vmp_ingredient table (first 5 rows):';
SELECT TOP 5 vpid, isid
FROM vmp_ingredient;
GO

-- Check 4: If VTM exists, find VMPs for it
PRINT '';
PRINT 'VMPs linked to Hydroxychloroquine VTM:';
SELECT 
    vmp.vpid,
    vmp.nm,
    vmp.invalid,
    vmp.vtmid
FROM vmp
WHERE vtmid IN (SELECT vtmid FROM vtm WHERE nm LIKE '%Hydroxychlor%')
ORDER BY vmp.nm;
GO

-- Check 5: If VMPs exist via VTM, find AMPs
PRINT '';
PRINT 'AMPs linked to Hydroxychloroquine VMPs:';
SELECT 
    amp.apid,
    amp.nm,
    amp.invalid,
    vmp.nm as VMP_Name
FROM amp
INNER JOIN vmp ON amp.vpid = vmp.vpid
WHERE vmp.vtmid IN (SELECT vtmid FROM vtm WHERE nm LIKE '%Hydroxychlor%')
ORDER BY amp.nm;
GO

-- Check 6: Look for Hydroxychloroquine in any product name
PRINT '';
PRINT 'AMPs with Hydroxychloroquine in product name:';
SELECT apid, nm, invalid
FROM amp
WHERE nm LIKE '%Hydroxychlor%'
ORDER BY nm;
GO
