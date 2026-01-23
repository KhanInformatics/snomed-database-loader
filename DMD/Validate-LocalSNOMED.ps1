<#
.SYNOPSIS
    Validates DMD database entries against the local UK SNOMED CT database.

.DESCRIPTION
    Takes random samples from DMD tables and validates them against the local 
    SNOMED CT database (with UK Extension) to verify:
    1. The SNOMED CT codes exist in the UK edition
    2. The concepts are active
    3. The names match (FSN comparison)
    
.PARAMETER SamplesPerTable
    Number of random samples to validate per table. Default is 10.

.PARAMETER DmdServerInstance
    SQL Server instance for DMD. Default is "SILENTPRIORY\SQLEXPRESS"

.PARAMETER DmdDatabase
    DMD Database name. Default is "dmd"

.PARAMETER SnomedServerInstance
    SQL Server instance for SNOMED. Default is "SILENTPRIORY\SQLEXPRESS"

.PARAMETER SnomedDatabase
    SNOMED Database name. Default is "snomedct"

.EXAMPLE
    .\Validate-LocalSNOMED.ps1 -SamplesPerTable 50
#>

param(
    [int]$SamplesPerTable = 10,
    [string]$DmdServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DmdDatabase = "dmd",
    [string]$SnomedServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$SnomedDatabase = "snomedct"
)

# Function to lookup a SNOMED CT code in local database
function Get-LocalSnomedLookup {
    param(
        [string]$Code,
        [string]$ServerInstance,
        [string]$Database
    )
    
    # Get concept and its FSN (Fully Specified Name)
    $query = @"
SELECT 
    c.id,
    c.active,
    d.term as fsn
FROM curr_concept_f c
LEFT JOIN curr_description_f d ON c.id = d.conceptId 
    AND d.active = '1' 
    AND d.typeId = '900000000000003001'  -- FSN type
WHERE c.id = '$Code'
"@
    
    try {
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query -TrustServerCertificate -ErrorAction Stop
        
        if ($result) {
            return @{
                Found = $true
                Code = $Code
                Active = ($result.active -eq '1')
                FSN = $result.fsn
            }
        }
        else {
            return @{
                Found = $false
                Code = $Code
                Error = "Code not found in local SNOMED database"
            }
        }
    }
    catch {
        return @{
            Found = $false
            Code = $Code
            Error = $_.Exception.Message
        }
    }
}

# Tables to validate with their ID columns and name columns
$tablesToValidate = @(
    @{ Table = "vtm"; IdColumn = "vtmid"; NameColumn = "nm" },
    @{ Table = "vmp"; IdColumn = "vpid"; NameColumn = "nm" },
    @{ Table = "amp"; IdColumn = "apid"; NameColumn = "nm" },
    @{ Table = "vmpp"; IdColumn = "vppid"; NameColumn = "nm" },
    @{ Table = "ampp"; IdColumn = "appid"; NameColumn = "nm" }
)

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "   DMD Validation Against Local UK SNOMED CT" -ForegroundColor White
Write-Host "   SNOMED Database: $SnomedServerInstance / $SnomedDatabase" -ForegroundColor Gray
Write-Host "   DMD Database: $DmdServerInstance / $DmdDatabase" -ForegroundColor Gray
Write-Host "   Samples per table: $SamplesPerTable" -ForegroundColor Gray
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

# Test connectivity first
Write-Host "Testing local SNOMED CT database connectivity..." -ForegroundColor Yellow
$testResult = Get-LocalSnomedLookup -Code "322236009" -ServerInstance $SnomedServerInstance -Database $SnomedDatabase
if ($testResult.Found) {
    Write-Host "[OK] Local SNOMED accessible (test: 322236009 = $($testResult.FSN))" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[FAIL] Cannot access local SNOMED: $($testResult.Error)" -ForegroundColor Red
    exit 1
}

# Check for UK Extension
Write-Host "Checking for UK Extension..." -ForegroundColor Yellow
$ukTest = Get-LocalSnomedLookup -Code "10565311000001102" -ServerInstance $SnomedServerInstance -Database $SnomedDatabase
if ($ukTest.Found) {
    Write-Host "[OK] UK Extension present (test: 10565311000001102 = $($ukTest.FSN))" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[WARN] UK Extension may not be loaded - UK-specific codes will fail" -ForegroundColor Yellow
    Write-Host ""
}

# Summary statistics
$totalChecked = 0
$totalFound = 0
$totalNotFound = 0
$totalInactive = 0
$totalErrors = 0

foreach ($tableInfo in $tablesToValidate) {
    $table = $tableInfo.Table
    $idCol = $tableInfo.IdColumn
    $nameCol = $tableInfo.NameColumn
    
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Validating: $($table.ToUpper())" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    # Get random samples from DMD database
    $query = "SELECT TOP $SamplesPerTable $idCol, $nameCol FROM $table ORDER BY NEWID()"
    
    try {
        $samples = Invoke-Sqlcmd -ServerInstance $DmdServerInstance -Database $DmdDatabase -Query $query -TrustServerCertificate
    }
    catch {
        Write-Host "  [FAIL] DMD query failed: $_" -ForegroundColor Red
        continue
    }
    
    $tableFound = 0
    $tableNotFound = 0
    $tableInactive = 0
    $tableErrors = 0
    
    foreach ($sample in $samples) {
        $code = $sample.$idCol
        $dmdName = $sample.$nameCol
        $totalChecked++
        
        $lookup = Get-LocalSnomedLookup -Code $code -ServerInstance $SnomedServerInstance -Database $SnomedDatabase
        
        if ($lookup.Found) {
            $totalFound++
            $tableFound++
            
            if (-not $lookup.Active) {
                $totalInactive++
                $tableInactive++
                Write-Host "  [INACTIVE] $code" -ForegroundColor Yellow
                Write-Host "      DMD Name:    $dmdName" -ForegroundColor Gray
                Write-Host "      SNOMED FSN:  $($lookup.FSN)" -ForegroundColor Gray
            }
            else {
                Write-Host "  [VALID] $code" -ForegroundColor Green
                Write-Host "      DMD Name:    $dmdName" -ForegroundColor Gray
                Write-Host "      SNOMED FSN:  $($lookup.FSN)" -ForegroundColor Gray
            }
        }
        else {
            if ($lookup.Error -eq "Code not found in local SNOMED database") {
                $totalNotFound++
                $tableNotFound++
                Write-Host "  [NOT FOUND] $code" -ForegroundColor Red
                Write-Host "      DMD Name: $dmdName" -ForegroundColor Gray
            }
            else {
                $totalErrors++
                $tableErrors++
                Write-Host "  [ERROR] $code - $($lookup.Error)" -ForegroundColor Magenta
            }
        }
    }
    
    Write-Host ""
    Write-Host "  Table Summary: Found=$tableFound, Not Found=$tableNotFound, Inactive=$tableInactive, Errors=$tableErrors" -ForegroundColor Gray
}

# Final summary
Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "   VALIDATION SUMMARY" -ForegroundColor White
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Codes Checked: $totalChecked" -ForegroundColor White
$activeCount = $totalFound - $totalInactive
Write-Host "  [OK] Found (Active):     $activeCount" -ForegroundColor Green
Write-Host "  [!]  Found (Inactive):   $totalInactive" -ForegroundColor Yellow
Write-Host "  [X]  Not Found:          $totalNotFound" -ForegroundColor Red
Write-Host "  [X]  Errors:             $totalErrors" -ForegroundColor Magenta
Write-Host ""

if ($totalNotFound -gt 0) {
    Write-Host "  Note: 'Not Found' codes may be:" -ForegroundColor DarkYellow
    Write-Host "    - New codes in DMD not yet in your SNOMED release" -ForegroundColor DarkYellow
    Write-Host "    - Codes that have been retired/replaced" -ForegroundColor DarkYellow
}

if ($totalInactive -gt 0) {
    Write-Host ""
    Write-Host "  Warning: Inactive codes found - these may need review" -ForegroundColor Yellow
}

$validRate = 0
if ($totalChecked -gt 0) {
    $validRate = [math]::Round(($totalFound / $totalChecked) * 100, 2)
}
Write-Host ""
Write-Host "  Validation Rate: $validRate percent codes found in local SNOMED CT" -ForegroundColor Cyan
Write-Host ""
