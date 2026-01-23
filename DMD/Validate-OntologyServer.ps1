<#
.SYNOPSIS
    Validates DMD database entries against the SNOMED CT ontology server.

.DESCRIPTION
    Takes random samples from DMD tables and validates them against the 
    IHTSDO Snowstorm FHIR terminology server to verify:
    1. The SNOMED CT codes exist in the international edition
    2. The concepts are active (not retired)
    
.PARAMETER SamplesPerTable
    Number of random samples to validate per table. Default is 10.

.PARAMETER ServerInstance
    SQL Server instance. Default is "SILENTPRIORY\SQLEXPRESS"

.PARAMETER Database
    Database name. Default is "dmd"

.PARAMETER FhirServer
    FHIR terminology server URL. Default is IHTSDO Snowstorm.

.EXAMPLE
    .\Validate-OntologyServer.ps1 -SamplesPerTable 20
#>

param(
    [int]$SamplesPerTable = 10,
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [string]$FhirServer = "https://snowstorm.ihtsdotools.org/fhir"
)

# Function to lookup a SNOMED CT code via FHIR
function Get-SnomedLookup {
    param(
        [string]$Code,
        [string]$FhirServer
    )
    
    $url = "$FhirServer/CodeSystem/`$lookup?system=http://snomed.info/sct&code=$Code"
    
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -Headers @{Accept="application/fhir+json"} -UseBasicParsing -TimeoutSec 30
        $content = [System.Text.Encoding]::UTF8.GetString($response.Content)
        $json = $content | ConvertFrom-Json
        
        $result = @{
            Found = $true
            Code = $Code
            Display = ""
            Inactive = $false
            Version = ""
        }
        
        foreach ($param in $json.parameter) {
            switch ($param.name) {
                "display" { $result.Display = $param.valueString }
                "inactive" { $result.Inactive = $param.valueBoolean }
                "version" { $result.Version = $param.valueString }
            }
        }
        
        return $result
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            return @{
                Found = $false
                Code = $Code
                Error = "Code not found in ontology server"
            }
        }
        else {
            return @{
                Found = $false
                Code = $Code
                Error = $_.Exception.Message
            }
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
Write-Host "   DMD Ontology Server Validation" -ForegroundColor White
Write-Host "   FHIR Server: $FhirServer" -ForegroundColor Gray
Write-Host "   Samples per table: $SamplesPerTable" -ForegroundColor Gray
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

# Test connectivity first
Write-Host "Testing ontology server connectivity..." -ForegroundColor Yellow
$testResult = Get-SnomedLookup -Code "322236009" -FhirServer $FhirServer
if ($testResult.Found) {
    Write-Host "[OK] Ontology server accessible (test code: 322236009 = $($testResult.Display))" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[FAIL] Cannot reach ontology server: $($testResult.Error)" -ForegroundColor Red
    exit 1
}

# Summary statistics
$totalChecked = 0
$totalFound = 0
$totalNotFound = 0
$totalInactive = 0
$totalErrors = 0
$allResults = @()

foreach ($tableInfo in $tablesToValidate) {
    $table = $tableInfo.Table
    $idCol = $tableInfo.IdColumn
    $nameCol = $tableInfo.NameColumn
    
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Validating: $($table.ToUpper())" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    # Get random samples from database
    $query = "SELECT TOP $SamplesPerTable $idCol, $nameCol FROM $table ORDER BY NEWID()"
    
    try {
        $samples = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query -TrustServerCertificate
    }
    catch {
        Write-Host "  [FAIL] Database query failed: $_" -ForegroundColor Red
        continue
    }
    
    $tableFound = 0
    $tableNotFound = 0
    $tableInactive = 0
    $tableErrors = 0
    
    foreach ($sample in $samples) {
        $code = $sample.$idCol
        $dbName = $sample.$nameCol
        $totalChecked++
        
        # Rate limiting - be gentle with public server
        Start-Sleep -Milliseconds 250
        
        $lookup = Get-SnomedLookup -Code $code -FhirServer $FhirServer
        
        if ($lookup.Found) {
            $totalFound++
            $tableFound++
            
            if ($lookup.Inactive) {
                $totalInactive++
                $tableInactive++
                Write-Host "  [INACTIVE] $code" -ForegroundColor Yellow
                Write-Host "      DB Name:   $dbName" -ForegroundColor Gray
                Write-Host "      FHIR Name: $($lookup.Display)" -ForegroundColor Gray
                
                $allResults += @{
                    Table = $table
                    Code = $code
                    Status = "INACTIVE"
                    DbName = $dbName
                    FhirName = $lookup.Display
                }
            }
            else {
                Write-Host "  [VALID] $code" -ForegroundColor Green
                Write-Host "      DB Name:   $dbName" -ForegroundColor Gray
                Write-Host "      FHIR Name: $($lookup.Display)" -ForegroundColor Gray
                
                $allResults += @{
                    Table = $table
                    Code = $code
                    Status = "VALID"
                    DbName = $dbName
                    FhirName = $lookup.Display
                }
            }
        }
        else {
            if ($lookup.Error -eq "Code not found in ontology server") {
                $totalNotFound++
                $tableNotFound++
                Write-Host "  [NOT FOUND] $code" -ForegroundColor Red
                Write-Host "      DB Name: $dbName" -ForegroundColor Gray
                Write-Host "      Note: May be UK extension code (not in international edition)" -ForegroundColor DarkYellow
                
                $allResults += @{
                    Table = $table
                    Code = $code
                    Status = "NOT_FOUND"
                    DbName = $dbName
                    Note = "May be UK extension"
                }
            }
            else {
                $totalErrors++
                $tableErrors++
                Write-Host "  [ERROR] $code - $($lookup.Error)" -ForegroundColor Magenta
                
                $allResults += @{
                    Table = $table
                    Code = $code
                    Status = "ERROR"
                    Error = $lookup.Error
                }
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
    Write-Host "  Note: 'Not Found' codes are likely UK Extension codes that exist in NHS dm+d" -ForegroundColor DarkYellow
    Write-Host "        but not in the SNOMED CT International Edition." -ForegroundColor DarkYellow
    Write-Host "        This is EXPECTED for UK-specific products like branded AMPs." -ForegroundColor DarkYellow
}

if ($totalInactive -gt 0) {
    Write-Host ""
    Write-Host "  Warning: Inactive codes found. These may need review." -ForegroundColor Yellow
}

$validRate = 0
if ($totalChecked -gt 0) {
    $validRate = [math]::Round(($totalFound / $totalChecked) * 100, 2)
}
Write-Host ""
Write-Host "  Validation Rate: $validRate percent codes found in ontology server" -ForegroundColor Cyan
Write-Host ""
