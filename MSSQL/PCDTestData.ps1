# PCDTestData.ps1 - Comprehensive Testing and Validation of PCD Refset Content Data
param(
    [string]$server = "localhost",
    [string]$database = "SNOMEDCT", 
    [string]$table = "PCD_Refset_Content_by_Output",
    [string]$sourceFile = "C:\SNOMEDCT\Downloads\20241205_PCD_Refset_Content_by_Output_V2.txt"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PCD REFSET CONTENT DATA TESTING SUITE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Invoke-TestQuery {
    param(
        [string]$Query,
        [string]$TestName,
        [switch]$ShowResults = $false
    )
    
    Write-Host "TEST: $TestName" -ForegroundColor Yellow
    Write-Host "Query: $Query" -ForegroundColor Gray
    
    try {
        $result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $Query -ErrorAction Stop
        
        if ($ShowResults -and $result) {
            $result | Format-Table -AutoSize
        }
        
        if ($result -is [array]) {
            Write-Host "Results: $($result.Count) records" -ForegroundColor Green
        } elseif ($result) {
            Write-Host "Results: 1 record" -ForegroundColor Green
        } else {
            Write-Host "No results returned" -ForegroundColor Green
        }
        
        return $result
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    
    Write-Host ""
}

# Test 1: Basic validation
Write-Host "1. BASIC TABLE VALIDATION" -ForegroundColor Magenta
Write-Host "=" * 50

$recordCount = Invoke-TestQuery -Query "SELECT COUNT(*) as TotalRecords FROM $table" -TestName "Total Record Count"
if ($recordCount) {
    $totalRecords = $recordCount.TotalRecords
    Write-Host "Total Records in Database: $totalRecords" -ForegroundColor Green
}

# Test 2: Schema validation
Write-Host "2. TABLE SCHEMA VALIDATION" -ForegroundColor Magenta
Write-Host "=" * 50

$schemaQuery = "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$table' ORDER BY ORDINAL_POSITION"
Invoke-TestQuery -Query $schemaQuery -TestName "Table Schema" -ShowResults

# Test 3: NULL validation
Write-Host "3. NULL VALUE VALIDATION" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT COUNT(*) as NullOutputID FROM $table WHERE Output_ID IS NULL" -TestName "NULL Output_ID Count"
Invoke-TestQuery -Query "SELECT COUNT(*) as NullClusterID FROM $table WHERE Cluster_ID IS NULL" -TestName "NULL Cluster_ID Count" 
Invoke-TestQuery -Query "SELECT COUNT(*) as NullSNOMEDCode FROM $table WHERE SNOMED_code IS NULL" -TestName "NULL SNOMED_code Count"
Invoke-TestQuery -Query "SELECT COUNT(*) as NullPCDRefsetID FROM $table WHERE PCD_Refset_ID IS NULL" -TestName "NULL PCD_Refset_ID Count"

# Test 4: Empty string validation
Write-Host "4. EMPTY STRING VALIDATION" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT COUNT(*) as EmptyOutputID FROM $table WHERE Output_ID = ''" -TestName "Empty Output_ID Count"
Invoke-TestQuery -Query "SELECT COUNT(*) as EmptyClusterID FROM $table WHERE Cluster_ID = ''" -TestName "Empty Cluster_ID Count"
Invoke-TestQuery -Query "SELECT COUNT(*) as EmptySNOMEDCode FROM $table WHERE SNOMED_code = ''" -TestName "Empty SNOMED_code Count"
Invoke-TestQuery -Query "SELECT COUNT(*) as EmptyPCDRefsetID FROM $table WHERE PCD_Refset_ID = ''" -TestName "Empty PCD_Refset_ID Count"

# Test 5: Numeric validation
Write-Host "5. NUMERIC FIELD VALIDATION" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT COUNT(*) as InvalidSNOMEDCode FROM $table WHERE ISNUMERIC(SNOMED_code) = 0" -TestName "Non-numeric SNOMED_code Count"
Invoke-TestQuery -Query "SELECT COUNT(*) as InvalidPCDRefsetID FROM $table WHERE ISNUMERIC(PCD_Refset_ID) = 0" -TestName "Non-numeric PCD_Refset_ID Count"

# Test 6: Length analysis
Write-Host "6. DATA LENGTH ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT MIN(LEN(Output_ID)) as MinLen, MAX(LEN(Output_ID)) as MaxLen, AVG(LEN(Output_ID)) as AvgLen FROM $table" -TestName "Output_ID Length Stats" -ShowResults
Invoke-TestQuery -Query "SELECT MIN(LEN(SNOMED_code)) as MinLen, MAX(LEN(SNOMED_code)) as MaxLen, AVG(LEN(SNOMED_code)) as AvgLen FROM $table" -TestName "SNOMED_code Length Stats" -ShowResults
Invoke-TestQuery -Query "SELECT MIN(LEN(PCD_Refset_ID)) as MinLen, MAX(LEN(PCD_Refset_ID)) as MaxLen, AVG(LEN(PCD_Refset_ID)) as AvgLen FROM $table" -TestName "PCD_Refset_ID Length Stats" -ShowResults

# Test 7: Duplicate analysis
Write-Host "7. DUPLICATE ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

$duplicateQuery = "SELECT COUNT(*) as DuplicateKeys FROM (SELECT Output_ID, SNOMED_code, COUNT(*) as cnt FROM $table GROUP BY Output_ID, SNOMED_code HAVING COUNT(*) > 1) duplicates"
Invoke-TestQuery -Query $duplicateQuery -TestName "Duplicate Primary Key Combinations"

# Test 8: Cluster analysis
Write-Host "8. CLUSTER ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT COUNT(DISTINCT Cluster_ID) as UniqueClusters, COUNT(*) as TotalRecords FROM $table" -TestName "Cluster Distribution" -ShowResults

$topClustersQuery = "SELECT TOP 10 Cluster_ID, Cluster_Description, COUNT(*) as RecordCount FROM $table GROUP BY Cluster_ID, Cluster_Description ORDER BY COUNT(*) DESC"
Invoke-TestQuery -Query $topClustersQuery -TestName "Top 10 Clusters by Record Count" -ShowResults

# Test 9: SNOMED analysis
Write-Host "9. SNOMED CODE ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT COUNT(DISTINCT SNOMED_code) as UniqueSNOMEDCodes, COUNT(*) as TotalRecords FROM $table" -TestName "SNOMED Code Uniqueness" -ShowResults

# Test 10: PCD Refset analysis
Write-Host "10. PCD REFSET ID ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT COUNT(DISTINCT PCD_Refset_ID) as UniquePCDRefsetIDs FROM $table" -TestName "PCD Refset ID Uniqueness" -ShowResults

$topPCDQuery = "SELECT TOP 10 PCD_Refset_ID, COUNT(*) as UsageCount FROM $table GROUP BY PCD_Refset_ID ORDER BY COUNT(*) DESC"
Invoke-TestQuery -Query $topPCDQuery -TestName "Most Used PCD Refset IDs" -ShowResults

# Test 11: Data quality
Write-Host "11. DATA QUALITY ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

$shortDescQuery = "SELECT COUNT(*) as ShortDescriptions FROM $table WHERE LEN(SNOMED_code_description) " + "< 10"
Invoke-TestQuery -Query $shortDescQuery -TestName "Records with short descriptions"

$longDescQuery = "SELECT COUNT(*) as LongDescriptions FROM $table WHERE LEN(SNOMED_code_description) " + "> 200"
Invoke-TestQuery -Query $longDescQuery -TestName "Records with long descriptions"

# Test 12: Sample data
Write-Host "12. SAMPLE DATA ANALYSIS" -ForegroundColor Magenta
Write-Host "=" * 50

Invoke-TestQuery -Query "SELECT TOP 5 * FROM $table ORDER BY Output_ID, SNOMED_code" -TestName "First 5 Records" -ShowResults

# Test 13: Source file comparison
Write-Host "13. SOURCE FILE COMPARISON" -ForegroundColor Magenta
Write-Host "=" * 50

if (Test-Path $sourceFile) {
    $fileContent = Get-Content $sourceFile
    $fileLineCount = ($fileContent | Measure-Object).Count - 1
    
    Write-Host "Source file lines (excluding header): $fileLineCount" -ForegroundColor Green
    Write-Host "Database records: $totalRecords" -ForegroundColor Green
    
    if ($fileLineCount -eq $totalRecords) {
        Write-Host "Record counts match perfectly!" -ForegroundColor Green
    } else {
        Write-Host "Record count mismatch: $($fileLineCount - $totalRecords)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Source file not found: $sourceFile" -ForegroundColor Yellow
}

# Final summary
Write-Host "14. FINAL SUMMARY" -ForegroundColor Magenta
Write-Host "=" * 50

Write-Host "Testing completed successfully!" -ForegroundColor Green
Write-Host "Database: $database" -ForegroundColor Cyan
Write-Host "Table: $table" -ForegroundColor Cyan
Write-Host "Total Records: $totalRecords" -ForegroundColor Cyan
Write-Host "Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "END OF PCD REFSET CONTENT DATA TESTING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
