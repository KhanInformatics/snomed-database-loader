-- Compare checkcodeschecked.txt with user provided list
USE SNOMEDCT;
GO

-- Create temporary tables for both lists
IF OBJECT_ID('tempdb..#CheckedList') IS NOT NULL DROP TABLE #CheckedList;
IF OBJECT_ID('tempdb..#UserList') IS NOT NULL DROP TABLE #UserList;

-- List 1: Extract codes from checkcodeschecked.txt (first part before the pipe)
CREATE TABLE #CheckedList (ConceptId NVARCHAR(18));

-- Create temp table to read the file
CREATE TABLE #RawData (Line NVARCHAR(MAX));
BULK INSERT #RawData
FROM 'o:\GitHub\snomed-database-loader\Queries\checkcodeschecked.txt'
WITH (FIELDTERMINATOR = '\n', ROWTERMINATOR = '\n', FIRSTROW = 1);

-- Extract the code part (before the first pipe)
INSERT INTO #CheckedList (ConceptId)
SELECT LEFT(Line, CHARINDEX(' |', Line) - 1)
FROM #RawData
WHERE Line LIKE '%|%' AND Line != '';

-- Clean the extracted codes
DELETE FROM #CheckedList WHERE ConceptId IS NULL OR LTRIM(RTRIM(ConceptId)) = '';
UPDATE #CheckedList SET ConceptId = LTRIM(RTRIM(ConceptId));

-- List 2: User provided list
CREATE TABLE #UserList (ConceptId NVARCHAR(18));
INSERT INTO #UserList (ConceptId) VALUES
('1005681000000107'),('1025301000000100'),('1025321000000109'),('1028551000000102'),
('10692611000001105'),('1082641000000106'),('1085871000000105'),('1098881000000103'),
('118582008'),('118586006'),('1326201000000101'),('133932002'),('160603005'),
('160604004'),('160605003'),('160606002'),('160616005'),('160617001'),
('183073003'),('225323000'),('228958009'),('230056004'),('248333004'),
('258672001'),('258683005'),('258813002'),('258896009'),('258983007'),
('259018001'),('266895004'),('266919005'),('266920004'),('266921000'),
('266922007'),('266923002'),('266924008'),('27113001'),('271636001'),
('275122004'),('275932007'),('312856000'),('364075005'),('366121000000108'),
('366171000000107'),('366211000000105'),('366241000000106'),('401067009'),
('401122004'),('506171000000109'),('523221000000100'),('523241000000107'),
('60621009'),('61086009'),('715851000000102'),('717121000000105'),
('722499006'),('75367002'),('763256006'),('763726001'),('767524001'),
('77176002'),('824421000000101'),('840391000000101'),('8517006'),
('853681000000104'),('863521000000106'),('871641000000105'),('871661000000106'),
('92421000000102'),('976631000000101'),('976651000000108'),('976671000000104'),
('976691000000100'),('976731000000106'),('976751000000104'),('976771000000108'),
('976791000000107'),('976811000000108'),('976831000000100'),('976851000000107'),
('976871000000103'),('976891000000104'),('976911000000101'),('976931000000109'),
('976951000000102'),('976971000000106');

-- Find codes in CheckedList but NOT in UserList
PRINT '=== CODES IN CHECKCODESCHECKED.TXT BUT NOT IN YOUR LIST ===';
SELECT DISTINCT c.ConceptId AS 'Missing from your list'
FROM #CheckedList c
LEFT JOIN #UserList u ON c.ConceptId = u.ConceptId
WHERE u.ConceptId IS NULL
ORDER BY c.ConceptId;

-- Find codes in UserList but NOT in CheckedList
PRINT '';
PRINT '=== CODES IN YOUR LIST BUT NOT IN CHECKCODESCHECKED.TXT ===';
SELECT DISTINCT u.ConceptId AS 'Extra in your list'
FROM #UserList u
LEFT JOIN #CheckedList c ON u.ConceptId = c.ConceptId
WHERE c.ConceptId IS NULL
ORDER BY u.ConceptId;

-- Summary counts
PRINT '';
PRINT '=== SUMMARY ===';
SELECT 
    (SELECT COUNT(DISTINCT ConceptId) FROM #CheckedList) AS 'Total in checkcodeschecked.txt',
    (SELECT COUNT(DISTINCT ConceptId) FROM #UserList) AS 'Total in your list',
    (SELECT COUNT(DISTINCT c.ConceptId) FROM #CheckedList c LEFT JOIN #UserList u ON c.ConceptId = u.ConceptId WHERE u.ConceptId IS NULL) AS 'Missing from your list',
    (SELECT COUNT(DISTINCT u.ConceptId) FROM #UserList u LEFT JOIN #CheckedList c ON u.ConceptId = c.ConceptId WHERE c.ConceptId IS NULL) AS 'Extra in your list';

-- Clean up
DROP TABLE #CheckedList;
DROP TABLE #UserList;
DROP TABLE #RawData;
