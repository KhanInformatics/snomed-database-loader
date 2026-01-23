param(
    [string]$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_11.1.0_20251110000001",
    [string]$BonusPath = "C:\DMD\CurrentReleases\nhsbsa_dmdbonus_11.1.0_20251110000001",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "dmd"
)

$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "DM+D Complete Database Import" -ForegroundColor Cyan
Write-Host "Release 11.1.0 (November 10, 2025)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Define import order (respecting foreign key dependencies)
# UsesBonus indicates scripts that need BonusPath instead of XmlPath
$imports = @(
    @{Name="VTM (Virtual Therapeutic Moieties)"; Script="Import-VTM.ps1"; Table="vtm"; Expected=3223; UsesBonus=$false}
    @{Name="VMP (Virtual Medicinal Products)"; Script="Import-VMP.ps1"; Table="vmp"; Expected=24390; UsesBonus=$false}
    @{Name="AMP (Actual Medicinal Products)"; Script="Import-AMP.ps1"; Table="amp"; Expected=164893; UsesBonus=$false}
    @{Name="VMPP (Virtual Medicinal Product Packs)"; Script="Import-VMPP.ps1"; Table="vmpp"; Expected=36932; UsesBonus=$false}
    @{Name="AMPP (Actual Medicinal Product Packs)"; Script="Import-AMPP.ps1"; Table="ampp"; Expected=184331; UsesBonus=$false}
    @{Name="Ingredient"; Script="Import-Ingredient.ps1"; Table="ingredient"; Expected=4490; UsesBonus=$false}
    @{Name="Lookup"; Script="Import-Lookup.ps1"; Table="lookup"; Expected=3806; UsesBonus=$false}
    @{Name="VMP Ingredients"; Script="Import-VMP-Ingredients.ps1"; Table="vmp_ingredient"; Expected=26723; UsesBonus=$false}
    @{Name="VMP Drug Routes"; Script="Import-VMP-DrugRoutes.ps1"; Table="vmp_drugroute"; Expected=22600; UsesBonus=$false}
    @{Name="VMP Drug Forms"; Script="Import-VMP-DrugForms.ps1"; Table="vmp_drugform"; Expected=20869; UsesBonus=$false}
    @{Name="BNF Codes"; Script="Import-BNF.ps1"; Table="dmd_bnf"; Expected=17297; UsesBonus=$true}
    @{Name="ATC Codes"; Script="Import-ATC.ps1"; Table="dmd_atc"; Expected=20330; UsesBonus=$true}
    @{Name="GTIN (Barcodes)"; Script="Import-GTIN.ps1"; Table="gtin"; Expected=97633; UsesBonus=$true}
)

$results = @()

foreach ($import in $imports) {
    Write-Host "`n[$($imports.IndexOf($import) + 1)/$($imports.Count)] $($import.Name)" -ForegroundColor Yellow
    Write-Host "=" * 60
    
    $scriptFile = Join-Path $scriptPath $import.Script
    
    if (-not (Test-Path $scriptFile)) {
        Write-Warning "Script not found: $scriptFile - SKIPPING"
        $results += @{
            Name = $import.Name
            Status = "SKIPPED"
            Reason = "Script not found"
            Count = 0
            Duration = 0
        }
        continue
    }
    
    $importStart = Get-Date
    
    try {
        # Run the import script with appropriate path parameter
        if ($import.UsesBonus) {
            & $scriptFile -BonusPath $BonusPath -ServerInstance $ServerInstance -DatabaseName $DatabaseName
        } else {
            & $scriptFile -XmlPath $XmlPath -ServerInstance $ServerInstance -DatabaseName $DatabaseName
        }
        
        # Verify count
        $query = "SELECT COUNT(*) as cnt FROM $($import.Table)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $query -QueryTimeout 30
        $actualCount = $result.cnt
        
        $importEnd = Get-Date
        $duration = ($importEnd - $importStart).TotalSeconds
        
        $status = if ($actualCount -eq $import.Expected) { "SUCCESS" } else { "WARNING" }
        $statusColor = if ($status -eq "SUCCESS") { "Green" } else { "Yellow" }
        
        Write-Host "`n$status`: $actualCount records imported (expected: $($import.Expected))" -ForegroundColor $statusColor
        Write-Host "Duration: $([Math]::Round($duration, 2)) seconds`n"
        
        $results += @{
            Name = $import.Name
            Status = $status
            Count = $actualCount
            Expected = $import.Expected
            Duration = $duration
        }
    }
    catch {
        $importEnd = Get-Date
        $duration = ($importEnd - $importStart).TotalSeconds
        
        Write-Error "FAILED: $_"
        
        $results += @{
            Name = $import.Name
            Status = "FAILED"
            Reason = $_.Exception.Message
            Count = 0
            Duration = $duration
        }
        
        Write-Host "`nContinuing with next import...`n" -ForegroundColor Yellow
    }
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalMinutes

# Summary Report
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "Import Summary" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

foreach ($result in $results) {
    $statusColor = switch ($result.Status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "FAILED" { "Red" }
        "SKIPPED" { "Gray" }
    }
    
    $line = "$($result.Name): $($result.Status)"
    if ($result.Count) {
        $line += " - $($result.Count) records"
    }
    if ($result.Reason) {
        $line += " ($($result.Reason))"
    }
    
    Write-Host $line -ForegroundColor $statusColor
}

Write-Host "`nTotal Duration: $([Math]::Round($totalDuration, 2)) minutes" -ForegroundColor Cyan

# Final database state
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "Final Database State" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$finalQuery = @"
SELECT 'vtm' as tbl, COUNT(*) as cnt FROM vtm 
UNION ALL SELECT 'vmp', COUNT(*) FROM vmp 
UNION ALL SELECT 'amp', COUNT(*) FROM amp 
UNION ALL SELECT 'vmpp', COUNT(*) FROM vmpp 
UNION ALL SELECT 'ampp', COUNT(*) FROM ampp 
UNION ALL SELECT 'ingredient', COUNT(*) FROM ingredient 
UNION ALL SELECT 'lookup', COUNT(*) FROM lookup 
UNION ALL SELECT 'vmp_ingredient', COUNT(*) FROM vmp_ingredient 
UNION ALL SELECT 'vmp_drugroute', COUNT(*) FROM vmp_drugroute 
UNION ALL SELECT 'vmp_drugform', COUNT(*) FROM vmp_drugform 
UNION ALL SELECT 'dmd_bnf', COUNT(*) FROM dmd_bnf 
UNION ALL SELECT 'dmd_atc', COUNT(*) FROM dmd_atc 
UNION ALL SELECT 'gtin', COUNT(*) FROM gtin 
ORDER BY tbl
"@

$finalState = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $finalQuery

$finalState | Format-Table -AutoSize

$totalRecords = ($finalState | Measure-Object -Property cnt -Sum).Sum
Write-Host "Total Records: $totalRecords" -ForegroundColor Green
