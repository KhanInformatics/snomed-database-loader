<#
.SYNOPSIS
    Compare Read v2 codes from data sharing exclusion refsets against the Albasoft list
#>

$data = Import-Excel .\DataSharingExclusions.xlsx -WorksheetName "All Exclusions"

# Get rows with Read v2 codes
$withReadV2 = $data | Where-Object { $_.ReadV2Code -and $_.ReadV2Code.ToString().Trim() -ne '' }
$uniqueReadV2 = @{}
foreach ($row in $withReadV2) {
    $code = $row.ReadV2Code.ToString().Trim()
    if (-not $uniqueReadV2.ContainsKey($code)) {
        $uniqueReadV2[$code] = $row
    }
}

Write-Host "Unique Read v2 codes from exclusion refsets: $($uniqueReadV2.Count)" -ForegroundColor Cyan

# Albasoft list (from compare-readcodes.ps1)
$albasoftRaw = Get-Content "O:\GitHub\snomed-database-loader\compare-readcodes.ps1" -Raw
# Extract the array content
if ($albasoftRaw -match '\$providedCodes\s*=\s*@\(([\s\S]*?)\)') {
    $arrayContent = $Matches[1]
    $albasoftCodes = $arrayContent -split "[,`r`n]" | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ -ne '' }
}

Write-Host "Albasoft list codes: $($albasoftCodes.Count)" -ForegroundColor Cyan

# Build lookup sets (normalised - trim trailing dots)
$albasoftSet = @{}
foreach ($c in $albasoftCodes) {
    $albasoftSet[$c] = $true
    $albasoftSet[$c.TrimEnd('.')] = $true
}

# Compare
$inBoth = @()
$onlyInRefset = @()
foreach ($code in $uniqueReadV2.Keys) {
    if ($albasoftSet.ContainsKey($code) -or $albasoftSet.ContainsKey($code.TrimEnd('.'))) {
        $inBoth += [PSCustomObject]@{
            ReadV2Code = $code
            SNOMED_ConceptID = $uniqueReadV2[$code].SNOMED_ConceptID
            Exclusion_Category = $uniqueReadV2[$code].Exclusion_Category
            Preferred_Term = $uniqueReadV2[$code].Preferred_Term
            InAlbasoft = 'YES'
        }
    } else {
        $onlyInRefset += [PSCustomObject]@{
            ReadV2Code = $code
            SNOMED_ConceptID = $uniqueReadV2[$code].SNOMED_ConceptID
            Exclusion_Category = $uniqueReadV2[$code].Exclusion_Category
            Preferred_Term = $uniqueReadV2[$code].Preferred_Term
            InAlbasoft = 'NO'
        }
    }
}

# Reverse: Albasoft codes not in refsets
$refsetSet = @{}
foreach ($code in $uniqueReadV2.Keys) {
    $refsetSet[$code] = $true
    $refsetSet[$code.TrimEnd('.')] = $true
}
$onlyInAlbasoft = $albasoftCodes | Where-Object { -not $refsetSet.ContainsKey($_) -and -not $refsetSet.ContainsKey($_.TrimEnd('.')) } | Sort-Object -Unique

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPARISON RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Read v2 codes IN BOTH (refset + Albasoft): $($inBoth.Count)" -ForegroundColor Green
Write-Host "Read v2 codes ONLY in refsets (NOT in Albasoft): $($onlyInRefset.Count)" -ForegroundColor Magenta
Write-Host "Albasoft codes NOT in any refset: $($onlyInAlbasoft.Count)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== Read v2 codes IN BOTH LISTS ===" -ForegroundColor Green
$inBoth | Sort-Object ReadV2Code | Format-Table ReadV2Code, Exclusion_Category, SNOMED_ConceptID, Preferred_Term -AutoSize

Write-Host ""
Write-Host "=== Read v2 codes ONLY in Refsets (NOT in Albasoft) ===" -ForegroundColor Magenta
$onlyInRefset | Sort-Object ReadV2Code | Format-Table ReadV2Code, Exclusion_Category, SNOMED_ConceptID, Preferred_Term -AutoSize

Write-Host ""
Write-Host "=== Albasoft codes NOT in any Refset (first 50) ===" -ForegroundColor Yellow
$onlyInAlbasoft | Select-Object -First 50
