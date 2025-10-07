-- Test script to verify checkcodes.txt file and content
USE SNOMEDCT;
GO

-- Test if we can read the checkcodes.txt file
CREATE TABLE #TestConcepts (
    ConceptId NVARCHAR(18)
);

BEGIN TRY
    BULK INSERT #TestConcepts
    FROM 'o:\GitHub\snomed-database-loader\Queries\checkcodes.txt'
    WITH (
        FIELDTERMINATOR = '\n',
        ROWTERMINATOR = '\n',
        FIRSTROW = 1
    );
    
    DECLARE @count INT;
    SELECT @count = COUNT(*) FROM #TestConcepts;
    
    PRINT 'SUCCESS: Found ' + CAST(@count AS VARCHAR(10)) + ' codes in checkcodes.txt';
    
    -- Show first 5 codes
    SELECT TOP 5 'Code: ' + ConceptId AS SampleCodes FROM #TestConcepts;
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: Could not read checkcodes.txt file';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Make sure the file exists at: o:\GitHub\snomed-database-loader\Queries\checkcodes.txt';
END CATCH

DROP TABLE #TestConcepts;
