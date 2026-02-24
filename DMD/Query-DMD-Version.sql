-- Query to find DMD version information

USE dmd;
GO

-- Check for version/metadata tables
PRINT 'Available tables in DMD database:';
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO

-- Look for any version or metadata information
PRINT '';
PRINT 'Checking for version/metadata tables:';
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%version%' 
   OR TABLE_NAME LIKE '%metadata%'
   OR TABLE_NAME LIKE '%info%'
   OR TABLE_NAME LIKE '%release%';
GO

-- Check if there's a lookup table with version info
PRINT '';
PRINT 'Checking lookup table for version information:';
SELECT type, cd, descr
FROM lookup
WHERE type LIKE '%version%' 
   OR type LIKE '%release%'
   OR descr LIKE '%version%'
   OR descr LIKE '%release%'
ORDER BY type, cd;
GO

-- Check database creation/modification date as a proxy
PRINT '';
PRINT 'Database information:';
SELECT 
    name as DatabaseName,
    create_date as CreatedDate,
    compatibility_level as CompatibilityLevel
FROM sys.databases
WHERE name = 'dmd';
GO

-- Check the most recent update dates in key tables
PRINT '';
PRINT 'Most recent data in key tables (based on date fields):';

-- VTM dates
SELECT TOP 5
    'VTM' as TableName,
    vtmid,
    nm,
    vtmiddt as Date
FROM vtm
WHERE vtmiddt IS NOT NULL
ORDER BY vtmiddt DESC;

-- VMP dates
SELECT TOP 5
    'VMP' as TableName,
    vpid,
    nm,
    vpiddt as Date
FROM vmp
WHERE vpiddt IS NOT NULL
ORDER BY vpiddt DESC;
GO
