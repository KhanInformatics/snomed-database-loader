USE SNOMEDCT;
GO

-- Enable xp_cmdshell (requires administrator privileges)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO

-- Query to get SNOMED concept IDs and terms - REGULAR TABLE VERSION
-- This version uses regular tables that BCP can access

-- Clean up any existing tables
IF OBJECT_ID('dbo.TempConcepts') IS NOT NULL DROP TABLE dbo.TempConcepts;
IF OBJECT_ID('dbo.TempConceptsOrdered') IS NOT NULL DROP TABLE dbo.TempConceptsOrdered;
IF OBJECT_ID('dbo.OutputResults') IS NOT NULL DROP TABLE dbo.OutputResults;

-- Create regular table to hold the concept IDs with original order
CREATE TABLE dbo.TempConcepts (ConceptId NVARCHAR(18));

-- Bulk insert from the text file (load into single column first)
BULK INSERT dbo.TempConcepts
FROM 'o:\GitHub\snomed-database-loader\Queries\checkcodes.txt'
WITH (FIELDTERMINATOR = '\n', ROWTERMINATOR = '\n', FIRSTROW = 1);

-- Remove any empty rows or whitespace
DELETE FROM dbo.TempConcepts WHERE ConceptId IS NULL OR LTRIM(RTRIM(ConceptId)) = '';
UPDATE dbo.TempConcepts SET ConceptId = LTRIM(RTRIM(ConceptId));

-- Create a new table with row numbers to preserve order
CREATE TABLE dbo.TempConceptsOrdered (
    RowNum INT IDENTITY(1,1),
    ConceptId NVARCHAR(18)
);

-- Insert data with preserved order
INSERT INTO dbo.TempConceptsOrdered (ConceptId)
SELECT ConceptId FROM dbo.TempConcepts;

-- Create results table with the formatted output in original order
SELECT 
    cl.RowNum,
    cl.ConceptId + ' |' + COALESCE(CAST(d.term AS NVARCHAR(MAX)), 'No description found') + '|' AS FormattedOutput
INTO dbo.OutputResults
FROM dbo.TempConceptsOrdered cl
LEFT JOIN curr_concept_f c ON cl.ConceptId = c.id
LEFT JOIN curr_description_f d ON d.conceptid = c.id 
    AND d.typeid = '900000000000003001' AND d.active = '1';

-- Export to file using BCP with regular table
DECLARE @cmd NVARCHAR(4000);
DECLARE @filePath NVARCHAR(500) = 'o:\GitHub\snomed-database-loader\Queries\checkcodeschecked.txt';
DECLARE @serverName NVARCHAR(100) = @@SERVERNAME;

-- Build BCP command using regular table in original order
SET @cmd = 'bcp "SELECT FormattedOutput FROM SNOMEDCT.dbo.OutputResults ORDER BY RowNum" queryout "' + @filePath + '" -c -T -S "' + @serverName + '"';

-- Execute the export
PRINT 'Exporting to: ' + @filePath;
EXEC xp_cmdshell @cmd;

-- Display summary and verification
DECLARE @rowCount INT;
SELECT @rowCount = COUNT(*) FROM dbo.OutputResults;
PRINT 'Export completed. ' + CAST(@rowCount AS VARCHAR(10)) + ' rows exported to checkcodeschecked.txt';

-- Display first 5 results for verification in original order
PRINT 'Sample results (in original order):';
SELECT TOP 5 FormattedOutput FROM dbo.OutputResults ORDER BY RowNum;

-- Clean up regular tables
DROP TABLE dbo.OutputResults;
DROP TABLE dbo.TempConceptsOrdered;
DROP TABLE dbo.TempConcepts;

PRINT 'Process completed successfully!';
