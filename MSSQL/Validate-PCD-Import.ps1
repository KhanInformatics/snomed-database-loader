# PowerShell script for comprehensive testing and validation of PCD data imports
# This script validates the accuracy and completeness of imported PCD files

$server = "localhost"           # SQL Server instance
$database = "SNOMEDCT"          # Database name

# Source file paths
$sourceFiles = @{
    "PCD_Refset_Content_by_Output" = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_by_Output_V2.txt"
    "PCD_Refset_Content_V2" = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_V2.txt"
    "PCD_Ruleset_Full_Name_Mappings_V2" = "C:\SNOMEDCT\Downloads\20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt"
    "PCD_Service_Full_Name_Mappings_V2" = "C:\SNOMEDCT\Downloads\20250521_PCD_Service_Full_Name_Mappings_V2.txt"
    "PCD_Output_Descriptions_V2" = "C:\SNOMEDCT\Downloads\20250521_PCD_Output_Descriptions_V2.txt"
}

# Table names
$tables = @{
    "PCD_Refset_Content_by_Output" = "PCD_Refset_Content_by_Output"
    "PCD_Refset_Content_V2" = "PCD_Refset_Content_V2"
    "PCD_Ruleset_Full_Name_Mappings_V2" = "PCD_Ruleset_Full_Name_Mappings_V2"
    "PCD_Service_Full_Name_Mappings_V2" = "PCD_Service_Full_Name_Mappings_V2"
    "PCD_Output_Descriptions_V2" = "PCD_Output_Descriptions_V2"
}

Write-Host "===== PCD Data Import Validation Report =====" -ForegroundColor Green
Write-Host "Generated: $(Get-Date)" -ForegroundColor Green
Write-Host "Server: $server" -ForegroundColor Green
Write-Host "Database: $database" -ForegroundColor Green
Write-Host ""

$validationResults = @{}

# Function to validate a single table
function Validate-Table {
    param(
        [string]$TableName,
        [string]$SourceFile,
        [hashtable]$ExpectedStructure
    )
    
    Write-Host "Validating: $TableName" -ForegroundColor Yellow
    Write-Host "Source File: $SourceFile" -ForegroundColor Gray
    
    $result = @{
        TableName = $TableName
        SourceFile = $SourceFile
        SourceExists = $false
        SourceLineCount = 0
        TableExists = $false
        TableRecordCount = 0
        MatchesExpected = $false
        SampleValidation = @{}
        DataQuality = @{}
        Issues = @()
    }
    
    # Check if source file exists
    if (Test-Path $SourceFile) {
        $result.SourceExists = $true
        $lines = Get-Content $SourceFile
        $result.SourceLineCount = $lines.Count - 1  # Subtract header row
        Write-Host "  Source file exists: $($lines.Count) total lines, $($result.SourceLineCount) data lines" -ForegroundColor Green
        
        # Show first few lines for structure analysis
        Write-Host "  First 3 lines (including header):" -ForegroundColor Gray
        for ($i = 0; $i -lt [Math]::Min(3, $lines.Count); $i++) {
            Write-Host "    Line $($i + 1): $($lines[$i])" -ForegroundColor Gray
        }
    } else {
        $result.Issues += "Source file not found: $SourceFile"
        Write-Host "  ERROR: Source file not found" -ForegroundColor Red
        return $result
    }
    
    # Check if table exists and get record count
    try {
        $query = "SELECT COUNT(*) as RecordCount FROM $TableName"
        $tableResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
        $result.TableExists = $true
        $result.TableRecordCount = $tableResult.RecordCount
        Write-Host "  Table exists: $($result.TableRecordCount) records" -ForegroundColor Green
    }
    catch {
        $result.Issues += "Table not found or inaccessible: $TableName"
        Write-Host "  ERROR: Table not found or inaccessible" -ForegroundColor Red
        return $result
    }
    
    # Compare counts
    $countDifference = [Math]::Abs($result.SourceLineCount - $result.TableRecordCount)
    $percentageDiff = if ($result.SourceLineCount -gt 0) { ($countDifference / $result.SourceLineCount) * 100 } else { 0 }
    
    if ($countDifference -eq 0) {
        Write-Host "  ✓ Record counts match exactly" -ForegroundColor Green
        $result.MatchesExpected = $true    } elseif ($percentageDiff -le 5) {
        $warningText = "Record counts differ by $countDifference records ($([Math]::Round($percentageDiff, 2))%)"
        Write-Host "  ⚠ $warningText" -ForegroundColor Yellow
        $result.Issues += "Record count difference: Source=$($result.SourceLineCount), Table=$($result.TableRecordCount)"
    } else {
        $errorText = "Significant record count difference: $countDifference records ($([Math]::Round($percentageDiff, 2))%)"
        Write-Host "  ✗ $errorText" -ForegroundColor Red
        $result.Issues += "Significant record count difference: Source=$($result.SourceLineCount), Table=$($result.TableRecordCount)"
    }
    
    # Sample validation - compare random records
    if ($result.TableRecordCount -gt 0 -and $result.SourceLineCount -gt 0) {
        Write-Host "  Performing sample validation..." -ForegroundColor Gray
        $result.SampleValidation = Validate-SampleRecords -TableName $TableName -SourceFile $SourceFile -SampleSize 10
    }
    
    # Data quality checks
    Write-Host "  Performing data quality checks..." -ForegroundColor Gray
    $result.DataQuality = Get-DataQualityMetrics -TableName $TableName
    
    Write-Host ""
    return $result
}

# Function to validate sample records
function Validate-SampleRecords {
    param(
        [string]$TableName,
        [string]$SourceFile,
        [int]$SampleSize = 10
    )
    
    $sampleResult = @{
        SampleSize = $SampleSize
        MatchedRecords = 0
        MismatchedRecords = 0
        Details = @()
    }
    
    try {
        $lines = Get-Content $SourceFile | Select-Object -Skip 1  # Skip header
        $sampleLines = $lines | Get-Random -Count ([Math]::Min($SampleSize, $lines.Count))
        
        foreach ($line in $sampleLines) {
            $fields = $line -split "`t"
            
            # Table-specific validation logic
            switch ($TableName) {
                "PCD_Refset_Content_by_Output" {
                    if ($fields.Count -ge 6) {                        $query = @"
SELECT COUNT(*) as FoundCount FROM $TableName 
WHERE Output_ID = '$($fields[0] -replace "'", "''")' 
AND SNOMED_code = '$($fields[3] -replace "'", "''")'
"@
                        $dbResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
                        if ($dbResult.FoundCount -gt 0) {
                            $sampleResult.MatchedRecords++
                        } else {
                            $sampleResult.MismatchedRecords++
                            $sampleResult.Details += "Missing record: Output_ID=$($fields[0]), SNOMED_code=$($fields[3])"
                        }
                    }
                }
                "PCD_Refset_Content_V2" {
                    if ($fields.Count -ge 4) {                        $query = @"
SELECT COUNT(*) as FoundCount FROM $TableName 
WHERE SNOMED_code = '$($fields[0] -replace "'", "''")' 
AND PCD_Refset_ID = '$($fields[2] -replace "'", "''")'
"@
                        $dbResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
                        if ($dbResult.FoundCount -gt 0) {
                            $sampleResult.MatchedRecords++
                        } else {
                            $sampleResult.MismatchedRecords++
                            $sampleResult.Details += "Missing record: SNOMED_code=$($fields[0]), PCD_Refset_ID=$($fields[2])"
                        }
                    }
                }
                "PCD_Ruleset_Full_Name_Mappings_V2" {
                    if ($fields.Count -ge 1 -and ![string]::IsNullOrWhiteSpace($fields[0])) {                        $query = @"
SELECT COUNT(*) as FoundCount FROM $TableName 
WHERE Ruleset_ID = '$($fields[0] -replace "'", "''")'
"@
                        $dbResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
                        if ($dbResult.FoundCount -gt 0) {
                            $sampleResult.MatchedRecords++
                        } else {
                            $sampleResult.MismatchedRecords++
                            $sampleResult.Details += "Missing record: Ruleset_ID=$($fields[0])"
                        }
                    }
                }
                "PCD_Service_Full_Name_Mappings_V2" {
                    if ($fields.Count -ge 1 -and ![string]::IsNullOrWhiteSpace($fields[0])) {                        $query = @"
SELECT COUNT(*) as FoundCount FROM $TableName 
WHERE Service_ID = '$($fields[0] -replace "'", "''")'
"@
                        $dbResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
                        if ($dbResult.FoundCount -gt 0) {
                            $sampleResult.MatchedRecords++
                        } else {
                            $sampleResult.MismatchedRecords++
                            $sampleResult.Details += "Missing record: Service_ID=$($fields[0])"
                        }
                    }
                }
                "PCD_Output_Descriptions_V2" {
                    if ($fields.Count -ge 1 -and ![string]::IsNullOrWhiteSpace($fields[0])) {                        $query = @"
SELECT COUNT(*) as FoundCount FROM $TableName 
WHERE Output_ID = '$($fields[0] -replace "'", "''")'
"@
                        $dbResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
                        if ($dbResult.FoundCount -gt 0) {
                            $sampleResult.MatchedRecords++
                        } else {
                            $sampleResult.MismatchedRecords++
                            $sampleResult.Details += "Missing record: Output_ID=$($fields[0])"
                        }
                    }
                }
            }
        }
        
        $matchPercentage = if ($sampleResult.MatchedRecords + $sampleResult.MismatchedRecords -gt 0) { 
            ($sampleResult.MatchedRecords / ($sampleResult.MatchedRecords + $sampleResult.MismatchedRecords)) * 100 
        } else { 0 }
        
        $percentText = "$([Math]::Round($matchPercentage, 1))%"
        Write-Host "    Sample validation: $($sampleResult.MatchedRecords) matched, $($sampleResult.MismatchedRecords) mismatched ($percentText)" -ForegroundColor $(if ($matchPercentage -ge 90) { "Green" } elseif ($matchPercentage -ge 70) { "Yellow" } else { "Red" })
        
    }
    catch {
        Write-Host "    Error during sample validation: $($_.Exception.Message)" -ForegroundColor Red
        $sampleResult.Details += "Sample validation error: $($_.Exception.Message)"
    }
    
    return $sampleResult
}

# Function to get data quality metrics
function Get-DataQualityMetrics {
    param([string]$TableName)
    
    $metrics = @{}
    
    try {
        switch ($TableName) {
            "PCD_Refset_Content_by_Output" {                $query = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT Output_ID) as UniqueOutputIds,
    COUNT(DISTINCT SNOMED_code) as UniqueSnomedCodes,
    COUNT(DISTINCT PCD_Refset_ID) as UniquePcdRefsetIds,
    COUNT(DISTINCT Cluster_ID) as UniqueClusters,
    SUM(CASE WHEN LEN(SNOMED_code) = 0 THEN 1 ELSE 0 END) as EmptySnomedCodes,
    SUM(CASE WHEN LEN(Output_ID) = 0 THEN 1 ELSE 0 END) as EmptyOutputIds
FROM $TableName
"@
            }
            "PCD_Refset_Content_V2" {                $query = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT SNOMED_code) as UniqueSnomedCodes,
    COUNT(DISTINCT PCD_Refset_ID) as UniquePcdRefsetIds,
    SUM(CASE WHEN LEN(SNOMED_code) = 0 THEN 1 ELSE 0 END) as EmptySnomedCodes,
    SUM(CASE WHEN LEN(PCD_Refset_ID) = 0 THEN 1 ELSE 0 END) as EmptyRefsetIds
FROM $TableName
"@
            }
            default {
                $query = "SELECT COUNT(*) as TotalRecords FROM $TableName"
            }
        }
        
        $result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
        
        # Convert result to hashtable
        $result.psobject.properties | ForEach-Object {
            $metrics[$_.Name] = $_.Value
        }
        
        # Display metrics
        $metrics.GetEnumerator() | ForEach-Object {
            Write-Host "    $($_.Key): $($_.Value)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "    Error getting data quality metrics: $($_.Exception.Message)" -ForegroundColor Red
        $metrics["Error"] = $_.Exception.Message
    }
    
    return $metrics
}

# Main validation loop
foreach ($tableKey in $tables.Keys) {
    $tableName = $tables[$tableKey]
    $sourceFile = $sourceFiles[$tableKey]
    
    $validationResults[$tableKey] = Validate-Table -TableName $tableName -SourceFile $sourceFile
}

# Summary report
Write-Host "===== VALIDATION SUMMARY =====" -ForegroundColor Green
Write-Host ""

$totalTables = $validationResults.Count
$successfulTables = ($validationResults.Values | Where-Object { $_.MatchesExpected -and $_.Issues.Count -eq 0 }).Count
$tablesWithIssues = ($validationResults.Values | Where-Object { $_.Issues.Count -gt 0 }).Count

Write-Host "Total Tables Validated: $totalTables" -ForegroundColor White
Write-Host "Successful Imports: $successfulTables" -ForegroundColor Green
Write-Host "Tables with Issues: $tablesWithIssues" -ForegroundColor $(if ($tablesWithIssues -eq 0) { "Green" } else { "Red" })
Write-Host ""

# Detailed issues
if ($tablesWithIssues -gt 0) {
    Write-Host "ISSUES FOUND:" -ForegroundColor Red
    foreach ($result in $validationResults.Values) {
        if ($result.Issues.Count -gt 0) {
            Write-Host "  Table: $($result.TableName)" -ForegroundColor Yellow
            foreach ($issue in $result.Issues) {
                Write-Host "    - $issue" -ForegroundColor Red
            }
        }
    }
    Write-Host ""
}

# Recommendations
Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan
foreach ($result in $validationResults.Values) {
    if ($result.TableRecordCount -eq 0 -and $result.SourceLineCount -gt 0) {
        Write-Host "  - Re-run import for $($result.TableName) - no records imported" -ForegroundColor Yellow
    }
    elseif ($result.Issues.Count -gt 0) {
        Write-Host "  - Review import process for $($result.TableName)" -ForegroundColor Yellow
    }
    elseif ($result.MatchesExpected) {
        Write-Host "  - $($result.TableName) import successful ✓" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Validation completed: $(Get-Date)" -ForegroundColor Green
