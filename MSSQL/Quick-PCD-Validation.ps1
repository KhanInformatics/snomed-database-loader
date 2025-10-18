 v   # PCD Data Import Validation Script
$server = "localhost"
$database = "SNOMEDCT"

Write-Host "PCD Data Import Validation Report" -ForegroundColor Green
Write-Host "Generated: $(Get-Date)" -ForegroundColor Green
Write-Host ""

# Define validation targets
$targets = @(
    @{ File = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_by_Output_V2.txt"; Table = "PCD_Refset_Content_by_Output" },
    @{ File = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_V2.txt"; Table = "PCD_Refset_Content_V2" },
    @{ File = "C:\SNOMEDCT\Downloads\20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt"; Table = "PCD_Ruleset_Full_Name_Mappings_V2" },
    @{ File = "C:\SNOMEDCT\Downloads\20250521_PCD_Service_Full_Name_Mappings_V2.txt"; Table = "PCD_Service_Full_Name_Mappings_V2" },
    @{ File = "C:\SNOMEDCT\Downloads\20250521_PCD_Output_Descriptions_V2.txt"; Table = "PCD_Output_Descriptions_V2" }
)

$successCount = 0
$issueCount = 0

foreach ($target in $targets) {
    $sourceFile = $target.File
    $tableName = $target.Table
    
    Write-Host "Validating: $tableName" -ForegroundColor Yellow
    
    # Check source file
    if (Test-Path $sourceFile) {
        $lines = Get-Content $sourceFile
        $sourceCount = $lines.Count - 1
        Write-Host "  Source: $sourceCount records" -ForegroundColor Green
        
        # Show sample of first line after header
        if ($lines.Count -gt 1) {
            $sampleLine = $lines[1]
            if ($sampleLine.Length -gt 80) {
                $sampleLine = $sampleLine.Substring(0, 80) + "..."
            }
            Write-Host "  Sample: $sampleLine" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ERROR: Source file not found" -ForegroundColor Red
        $issueCount++
        continue
    }
    
    # Check table
    try {
        $query = "SELECT COUNT(*) as RecordCount FROM $tableName"
        $result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
        $tableCount = $result.RecordCount
        Write-Host "  Table: $tableCount records" -ForegroundColor Green
        
        # Compare counts
        $diff = [Math]::Abs($sourceCount - $tableCount)
        if ($diff -eq 0) {
            Write-Host "  Status: Perfect match" -ForegroundColor Green
            $successCount++
        } elseif ($diff -le 10) {
            Write-Host "  Status: Minor difference ($diff records)" -ForegroundColor Yellow
            $successCount++
        } else {
            Write-Host "  Status: Significant difference ($diff records)" -ForegroundColor Red
            $issueCount++
        }
    }
    catch {
        Write-Host "  ERROR: Table not accessible" -ForegroundColor Red
        $issueCount++
    }
    
    Write-Host ""
}

Write-Host "SUMMARY:" -ForegroundColor Green
Write-Host "  Successful: $successCount" -ForegroundColor Green
Write-Host "  Issues: $issueCount" -ForegroundColor $(if ($issueCount -eq 0) { "Green" } else { "Red" })

if ($issueCount -eq 0) {
    Write-Host "All validations passed!" -ForegroundColor Green
} else {
    Write-Host "Some issues found - review import process" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Validation completed: $(Get-Date)" -ForegroundColor Green
