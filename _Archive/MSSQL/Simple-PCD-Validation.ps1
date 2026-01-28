# Simple PCD Data Import Validation Script
# This script validates the accuracy and completeness of imported PCD files

$server = "localhost"           # SQL Server instance
$database = "SNOMEDCT"          # Database name

Write-Host "===== PCD Data Import Validation Report =====" -ForegroundColor Green
Write-Host "Generated: $(Get-Date)" -ForegroundColor Green
Write-Host "Server: $server" -ForegroundColor Green
Write-Host "Database: $database" -ForegroundColor Green
Write-Host ""

# Source file paths and corresponding tables
$validationTargets = @(
    @{
        SourceFile = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_by_Output_V2.txt"
        TableName = "PCD_Refset_Content_by_Output"
        Description = "PCD Refset Content by Output"
    },
    @{
        SourceFile = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_V2.txt"
        TableName = "PCD_Refset_Content_V2"
        Description = "PCD Refset Content"
    },
    @{
        SourceFile = "C:\SNOMEDCT\Downloads\20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt"
        TableName = "PCD_Ruleset_Full_Name_Mappings_V2"
        Description = "PCD Ruleset Mappings"
    },
    @{
        SourceFile = "C:\SNOMEDCT\Downloads\20250521_PCD_Service_Full_Name_Mappings_V2.txt"
        TableName = "PCD_Service_Full_Name_Mappings_V2"
        Description = "PCD Service Mappings"
    },
    @{
        SourceFile = "C:\SNOMEDCT\Downloads\20250521_PCD_Output_Descriptions_V2.txt"
        TableName = "PCD_Output_Descriptions_V2"
        Description = "PCD Output Descriptions"
    }
)

$totalValidated = 0
$successfulImports = 0
$issuesFound = @()

foreach ($target in $validationTargets) {
    $sourceFile = $target.SourceFile
    $tableName = $target.TableName
    $description = $target.Description
    
    Write-Host "Validating: $description" -ForegroundColor Yellow
    Write-Host "Source File: $sourceFile" -ForegroundColor Gray
    Write-Host "Table: $tableName" -ForegroundColor Gray
    
    $totalValidated++
    
    # Check if source file exists
    if (-not (Test-Path $sourceFile)) {
        Write-Host "  ERROR: Source file not found" -ForegroundColor Red
        $issuesFound += "Source file not found: $sourceFile"
        Write-Host ""
        continue
    }
    
    # Get source file line count
    $lines = Get-Content $sourceFile
    $sourceLineCount = $lines.Count - 1  # Subtract header row
    Write-Host "  Source file: $($lines.Count) total lines, $sourceLineCount data lines" -ForegroundColor Green
    
    # Show first few lines for structure analysis
    Write-Host "  First 3 lines:" -ForegroundColor Gray
    for ($i = 0; $i -lt [Math]::Min(3, $lines.Count); $i++) {
        $lineText = $lines[$i]
        if ($lineText.Length -gt 100) {
            $lineText = $lineText.Substring(0, 100) + "..."
        }
        Write-Host "    Line $($i + 1): $lineText" -ForegroundColor Gray
    }
    
    # Check if table exists and get record count
    try {
        $query = "SELECT COUNT(*) as RecordCount FROM $tableName"
        $tableResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
        $tableRecordCount = $tableResult.RecordCount
        Write-Host "  Table exists: $tableRecordCount records" -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR: Table not found or inaccessible" -ForegroundColor Red
        $issuesFound += "Table not found: $tableName"
        Write-Host ""
        continue
    }
    
    # Compare counts
    $countDifference = [Math]::Abs($sourceLineCount - $tableRecordCount)
    
    if ($countDifference -eq 0) {
        Write-Host "  ✓ Record counts match exactly" -ForegroundColor Green
        $successfulImports++
    } elseif ($sourceLineCount -gt 0) {
        $percentageDiff = ($countDifference / $sourceLineCount) * 100
        if ($percentageDiff -le 5) {
            Write-Host "  ⚠ Minor record count difference: $countDifference records" -ForegroundColor Yellow
            $issuesFound += "Minor count difference in ${tableName}: Source=$sourceLineCount, Table=$tableRecordCount"
        } else {
            Write-Host "  ✗ Significant record count difference: $countDifference records" -ForegroundColor Red
            $issuesFound += "Significant count difference in ${tableName}: Source=$sourceLineCount, Table=$tableRecordCount"
        }
    } else {
        Write-Host "  ✗ Source file appears empty" -ForegroundColor Red
        $issuesFound += "Empty source file: $sourceFile"
    }
    
    # Get basic data quality metrics
    try {
        switch ($tableName) {
            "PCD_Refset_Content_by_Output" {
                $qualityQuery = "SELECT COUNT(DISTINCT Output_ID) as UniqueOutputs, COUNT(DISTINCT SNOMED_code) as UniqueSnomed FROM $tableName"
            }
            "PCD_Refset_Content_V2" {
                $qualityQuery = "SELECT COUNT(DISTINCT SNOMED_code) as UniqueSnomed, COUNT(DISTINCT PCD_Refset_ID) as UniqueRefsets FROM $tableName"
            }
            default {
                $qualityQuery = "SELECT COUNT(*) as TotalRecords FROM $tableName"
            }
        }
        
        $qualityResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $qualityQuery
        Write-Host "  Data quality metrics:" -ForegroundColor Gray
        $qualityResult.psobject.properties | ForEach-Object {
            Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Warning: Could not retrieve data quality metrics" -ForegroundColor Yellow
    }
    
    # Sample record validation
    if ($tableRecordCount -gt 0 -and $sourceLineCount -gt 0) {
        Write-Host "  Performing sample validation..." -ForegroundColor Gray
        
        try {
            $sampleLines = $lines | Select-Object -Skip 1 | Get-Random -Count ([Math]::Min(5, $sourceLineCount))
            $matchedSamples = 0
            $totalSamples = 0
            
            foreach ($line in $sampleLines) {
                $fields = $line -split "`t"
                $totalSamples++
                
                # Simple existence check based on first field
                if ($fields.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($fields[0])) {
                    $firstField = $fields[0] -replace "'", "''"
                    $checkQuery = "SELECT COUNT(*) as Found FROM $tableName WHERE "                    switch ($tableName) {
                        "PCD_Refset_Content_by_Output" { 
                            $checkQuery += "Output_ID = '$firstField'" 
                        }
                        "PCD_Refset_Content_V2" { 
                            $checkQuery += "SNOMED_code = '$firstField'" 
                        }
                        "PCD_Ruleset_Full_Name_Mappings_V2" { 
                            $checkQuery += "Ruleset_ID = '$firstField'" 
                        }
                        "PCD_Service_Full_Name_Mappings_V2" { 
                            $checkQuery += "Service_ID = '$firstField'" 
                        }
                        "PCD_Output_Descriptions_V2" { 
                            $checkQuery += "Output_ID = '$firstField'" 
                        }
                    }
                    
                    $checkResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $checkQuery
                    if ($checkResult.Found -gt 0) {
                        $matchedSamples++
                    }
                }
            }
            
            if ($totalSamples -gt 0) {
                Write-Host "    Sample validation: $matchedSamples/$totalSamples records found" -ForegroundColor $(if ($matchedSamples -eq $totalSamples) { "Green" } elseif ($matchedSamples -gt 0) { "Yellow" } else { "Red" })
            }
        }
        catch {
            Write-Host "    Sample validation failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

# Summary report
Write-Host "===== VALIDATION SUMMARY =====" -ForegroundColor Green
Write-Host ""
Write-Host "Total Tables Validated: $totalValidated" -ForegroundColor White
Write-Host "Successful Imports: $successfulImports" -ForegroundColor Green
Write-Host "Tables with Issues: $($totalValidated - $successfulImports)" -ForegroundColor $(if ($totalValidated -eq $successfulImports) { "Green" } else { "Red" })
Write-Host ""

if ($issuesFound.Count -gt 0) {
    Write-Host "ISSUES FOUND:" -ForegroundColor Red
    foreach ($issue in $issuesFound) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan
if ($successfulImports -eq $totalValidated) {
    Write-Host "  - All imports appear successful ✓" -ForegroundColor Green
} else {
    Write-Host "  - Review import process for tables with issues" -ForegroundColor Yellow
    Write-Host "  - Check file paths and formats" -ForegroundColor Yellow
    Write-Host "  - Verify database connectivity and permissions" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Validation completed: $(Get-Date)" -ForegroundColor Green
