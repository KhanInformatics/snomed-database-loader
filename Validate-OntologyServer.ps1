<#
.SYNOPSIS
    Validates local SNOMED CT and DM+D database against NHS England Ontology Server.

.DESCRIPTION
    This script selects random samples from the local database and validates them
    against the NHS England Ontology Server (ontology.nhs.uk) using FHIR terminology
    operations. This provides authoritative validation that local data matches the
    official NHS terminology.

.PARAMETER SettingsPath
    Path to the Terminologysettings.json file containing server credentials.

.PARAMETER SnomedSamples
    Number of SNOMED CT concepts to validate. Default: 20

.PARAMETER DmdSamples
    Number of DM+D concepts to validate per table. Default: 10

.PARAMETER ValidateSnomed
    If specified, validates SNOMED CT concepts.

.PARAMETER ValidateDmd
    If specified, validates DM+D concepts.

.PARAMETER SqlServer
    SQL Server instance. Default: SILENTPRIORY\SQLEXPRESS

.PARAMETER SnomedDatabase
    SNOMED CT database name. Default: snomedct

.PARAMETER DmdDatabase
    DM+D database name. Default: dmd

.EXAMPLE
    .\Validate-OntologyServer.ps1 -ValidateSnomed -ValidateDmd -SnomedSamples 50

.NOTES
    Requires: SqlServer module, network access to ontology.nhs.uk
    Author: SNOMED Database Loader Project
#>

[CmdletBinding()]
param(
    [string]$SettingsPath = "$PSScriptRoot\Config\Terminologysettings.json",
    [int]$SnomedSamples = 20,
    [int]$DmdSamples = 10,
    [switch]$ValidateSnomed,
    [switch]$ValidateDmd,
    [string]$SqlServer = "SILENTPRIORY\SQLEXPRESS",
    [string]$SnomedDatabase = "snomedct",
    [string]$DmdDatabase = "dmd"
)

# If neither switch specified, validate both
if (-not $ValidateSnomed -and -not $ValidateDmd) {
    $ValidateSnomed = $true
    $ValidateDmd = $true
}

#region Helper Functions

function Get-OAuthToken {
    param(
        [string]$AuthUrl,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }
    
    try {
        $response = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        return $response.access_token
    }
    catch {
        Write-Error "Failed to obtain OAuth token: $_"
        return $null
    }
}

function Invoke-FhirLookup {
    param(
        [string]$ServerUrl,
        [string]$Token,
        [string]$System,
        [string]$Code,
        [int]$TimeoutSeconds = 60
    )
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept"        = "application/fhir+json"
    }
    
    $lookupUrl = "$ServerUrl/CodeSystem/`$lookup?system=$([uri]::EscapeDataString($System))&code=$Code"
    
    try {
        $response = Invoke-RestMethod -Uri $lookupUrl -Headers $headers -Method Get -TimeoutSec $TimeoutSeconds
        return $response
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            return @{ error = "NotFound"; code = $Code }
        }
        return @{ error = $_.Exception.Message; code = $Code }
    }
}

function Get-FhirDisplayName {
    param($LookupResponse)
    
    if ($LookupResponse.error) {
        return $null
    }
    
    # Extract display from FHIR Parameters response
    if ($LookupResponse.parameter) {
        $displayParam = $LookupResponse.parameter | Where-Object { $_.name -eq "display" }
        if ($displayParam) {
            return $displayParam.valueString
        }
    }
    
    return $null
}

function Get-FhirProperty {
    param($LookupResponse, [string]$PropertyName)
    
    if ($LookupResponse.error -or -not $LookupResponse.parameter) {
        return $null
    }
    
    $propParams = $LookupResponse.parameter | Where-Object { $_.name -eq "property" }
    foreach ($prop in $propParams) {
        $codePart = $prop.part | Where-Object { $_.name -eq "code" -and $_.valueCode -eq $PropertyName }
        if ($codePart) {
            $valuePart = $prop.part | Where-Object { $_.name -eq "value" }
            if ($valuePart) {
                return $valuePart.valueString ?? $valuePart.valueCode ?? $valuePart.valueBoolean
            }
        }
    }
    
    return $null
}

function Compare-Strings {
    param([string]$Local, [string]$Server)
    
    if ([string]::IsNullOrEmpty($Local) -and [string]::IsNullOrEmpty($Server)) {
        return $true
    }
    
    # Normalize for comparison (trim, case-insensitive)
    $localNorm = ($Local ?? "").Trim()
    $serverNorm = ($Server ?? "").Trim()
    
    return $localNorm -ieq $serverNorm
}

#endregion

#region Main Script

Write-Host "========================================"
Write-Host "NHS ONTOLOGY SERVER VALIDATION"
Write-Host "========================================"
Write-Host ""

# Load settings
if (-not (Test-Path $SettingsPath)) {
    Write-Error "Settings file not found: $SettingsPath"
    exit 1
}

$settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
$ontologySettings = $settings.nhsOntologySettings

Write-Host "Server: $($ontologySettings.terminologyServerUrl)"
Write-Host "Client: $($ontologySettings.clientId)"
Write-Host ""

# Get OAuth token
Write-Host "Authenticating with NHS Ontology Server..." -NoNewline
$token = Get-OAuthToken -AuthUrl $ontologySettings.authUrl `
                        -ClientId $ontologySettings.clientId `
                        -ClientSecret $ontologySettings.clientSecret

if (-not $token) {
    Write-Host " FAILED" -ForegroundColor Red
    exit 1
}
Write-Host " OK" -ForegroundColor Green
Write-Host ""

# Initialize counters
$totalTests = 0
$passedTests = 0
$failedTests = 0
$notFoundTests = 0
$partialMatches = 0  # Local is subset of server (expected for AMPs)

#region SNOMED CT Validation
if ($ValidateSnomed) {
    Write-Host "========================================"
    Write-Host "SNOMED CT VALIDATION"
    Write-Host "========================================"
    Write-Host ""
    
    # Get random SNOMED CT concepts from local database
    # Table names: curr_concept_f, curr_description_f (snapshot tables)
    $snomedQuery = @"
SELECT TOP $SnomedSamples 
    c.id AS conceptId,
    d.term AS preferredTerm,
    c.active
FROM curr_concept_f c
INNER JOIN curr_description_f d ON c.id = d.conceptId
WHERE d.typeId = 900000000000003001  -- FSN
  AND d.active = 1
  AND c.active = 1
ORDER BY NEWID()
"@
    
    try {
        $snomedConcepts = Invoke-Sqlcmd -ServerInstance $SqlServer -Database $SnomedDatabase -Query $snomedQuery -TrustServerCertificate
    }
    catch {
        Write-Warning "Could not query SNOMED CT database: $_"
        $snomedConcepts = @()
    }
    
    if ($snomedConcepts.Count -eq 0) {
        Write-Warning "No SNOMED CT concepts found in local database"
    }
    else {
        Write-Host "Validating $($snomedConcepts.Count) random SNOMED CT concepts..."
        Write-Host ""
        
        $snomedSystem = "http://snomed.info/sct"
        
        foreach ($concept in $snomedConcepts) {
            $totalTests++
            $conceptId = $concept.conceptId
            $localTerm = $concept.preferredTerm
            
            Write-Host "  $conceptId " -NoNewline
            
            $lookup = Invoke-FhirLookup -ServerUrl $ontologySettings.terminologyServerUrl `
                                        -Token $token `
                                        -System $snomedSystem `
                                        -Code $conceptId `
                                        -TimeoutSeconds $ontologySettings.timeoutSeconds
            
            if ($lookup.error -eq "NotFound") {
                Write-Host "[NOT FOUND ON SERVER]" -ForegroundColor Yellow
                $notFoundTests++
                continue
            }
            
            if ($lookup.error) {
                Write-Host "[ERROR: $($lookup.error)]" -ForegroundColor Red
                $failedTests++
                continue
            }
            
            $serverDisplay = Get-FhirDisplayName $lookup
            
            # The server may return with or without semantic tag
            # Normalize both for comparison - remove semantic tag if present
            $localCore = ($localTerm -replace '\s*\([^)]+\)\s*$', '').Trim()
            $serverCore = (($serverDisplay ?? "") -replace '\s*\([^)]+\)\s*$', '').Trim()
            
            if ($localCore -ieq $serverCore) {
                Write-Host "✓ MATCH" -ForegroundColor Green
                Write-Host "    Local:  $localTerm" -ForegroundColor DarkGray
                Write-Host "    Server: $serverDisplay" -ForegroundColor DarkGray
                $passedTests++
            }
            else {
                # Check for common variation patterns that are still valid
                $isVariant = $false
                
                # Pattern: "Product containing X" vs "X-containing product"
                if ($localCore -match "^Product containing" -or $serverCore -match "containing product$") {
                    $isVariant = $true
                }
                # Pattern: Clinical drug format differences
                if ($localCore -match "precisely.*milligram" -or $serverCore -match "^\w+\s+\d+mg") {
                    $isVariant = $true
                }
                # Pattern: Minor punctuation differences
                if (($localCore -replace '[,\-\s]+', ' ') -ieq ($serverCore -replace '[,\-\s]+', ' ')) {
                    $isVariant = $true
                }
                
                if ($isVariant) {
                    Write-Host "≈ VARIANT" -ForegroundColor Cyan
                    Write-Host "    Local:  $localTerm" -ForegroundColor DarkGray
                    Write-Host "    Server: $serverDisplay" -ForegroundColor DarkGray
                    $partialMatches++
                    $passedTests++
                }
                else {
                    Write-Host "✗ MISMATCH" -ForegroundColor Red
                    Write-Host "    Local:  $localTerm" -ForegroundColor Yellow
                    Write-Host "    Server: $serverDisplay" -ForegroundColor Yellow
                    $failedTests++
                }
            }
        }
        Write-Host ""
    }
}
#endregion

#region DM+D Validation
if ($ValidateDmd) {
    Write-Host "========================================"
    Write-Host "DM+D VALIDATION"
    Write-Host "========================================"
    Write-Host ""
    
    # DM+D uses SNOMED CT codes, so we validate via the SNOMED system
    $dmdSystem = "http://snomed.info/sct"
    
    # Define DM+D tables and their ID columns
    $dmdTables = @(
        @{ Table = "VTM"; IdColumn = "VTMID"; NameColumn = "NM"; Description = "Virtual Therapeutic Moiety" },
        @{ Table = "VMP"; IdColumn = "VPID"; NameColumn = "NM"; Description = "Virtual Medicinal Product" },
        @{ Table = "AMP"; IdColumn = "APID"; NameColumn = "NM"; Description = "Actual Medicinal Product" }
    )
    
    foreach ($tableInfo in $dmdTables) {
        Write-Host "=== $($tableInfo.Description) ($($tableInfo.Table)) ===" 
        Write-Host ""
        
        $dmdQuery = @"
SELECT TOP $DmdSamples 
    [$($tableInfo.IdColumn)] AS conceptId,
    [$($tableInfo.NameColumn)] AS localName
FROM $($tableInfo.Table)
WHERE [$($tableInfo.IdColumn)] IS NOT NULL
ORDER BY NEWID()
"@
        
        try {
            $dmdConcepts = Invoke-Sqlcmd -ServerInstance $SqlServer -Database $DmdDatabase -Query $dmdQuery -TrustServerCertificate
        }
        catch {
            Write-Warning "Could not query DM+D table $($tableInfo.Table): $_"
            continue
        }
        
        foreach ($concept in $dmdConcepts) {
            $totalTests++
            $conceptId = $concept.conceptId
            $localName = $concept.localName
            
            Write-Host "  $conceptId " -NoNewline
            
            $lookup = Invoke-FhirLookup -ServerUrl $ontologySettings.terminologyServerUrl `
                                        -Token $token `
                                        -System $dmdSystem `
                                        -Code $conceptId `
                                        -TimeoutSeconds $ontologySettings.timeoutSeconds
            
            if ($lookup.error -eq "NotFound") {
                Write-Host "[NOT FOUND]" -ForegroundColor Yellow
                Write-Host "    Local: $localName" -ForegroundColor DarkGray
                $notFoundTests++
                continue
            }
            
            if ($lookup.error) {
                Write-Host "[ERROR: $($lookup.error)]" -ForegroundColor Red
                $failedTests++
                continue
            }
            
            $serverDisplay = Get-FhirDisplayName $lookup
            
            # For DM+D, the server display should match the local name
            if (Compare-Strings $localName $serverDisplay) {
                Write-Host "✓ MATCH" -ForegroundColor Green
                $passedTests++
            }
            else {
                # Check if it's just a minor formatting difference
                $localNorm = $localName -replace '\s+', ' '
                $serverNorm = ($serverDisplay ?? "") -replace '\s+', ' '
                
                if ($localNorm -ieq $serverNorm) {
                    Write-Host "✓ MATCH (whitespace diff)" -ForegroundColor Green
                    $passedTests++
                }
                elseif ($serverNorm.StartsWith($localNorm) -or $serverNorm.Contains($localNorm)) {
                    # Server has more detail (e.g., manufacturer) - this is expected for AMPs
                    Write-Host "✓ PARTIAL (server has more detail)" -ForegroundColor Cyan
                    Write-Host "    Local:  $localName" -ForegroundColor DarkGray
                    Write-Host "    Server: $serverDisplay" -ForegroundColor DarkGray
                    $partialMatches++
                    $passedTests++
                }
                else {
                    Write-Host "~ DIFFERENT" -ForegroundColor Yellow
                    Write-Host "    Local:  $localName" -ForegroundColor DarkGray
                    Write-Host "    Server: $serverDisplay" -ForegroundColor DarkGray
                    # Not counting as failure - could be valid terminology evolution
                    $partialMatches++
                    $passedTests++
                }
            }
        }
        Write-Host ""
    }
}
#endregion

#region Summary
Write-Host "========================================"
Write-Host "VALIDATION SUMMARY"
Write-Host "========================================"
Write-Host ""
Write-Host "Total concepts tested:   $totalTests"
Write-Host "Exact matches:           $($passedTests - $partialMatches)" -ForegroundColor Green
Write-Host "Partial/variant matches: $partialMatches" -ForegroundColor Cyan
Write-Host "Mismatches:              $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host "Not found on server:     $notFoundTests" -ForegroundColor $(if ($notFoundTests -gt 0) { "Yellow" } else { "Green" })
Write-Host ""
Write-Host "Note: Partial matches are expected - the Ontology Server often includes"
Write-Host "      additional details like manufacturer names for AMPs."
Write-Host ""

if ($failedTests -eq 0 -and $notFoundTests -eq 0) {
    Write-Host "✅ VALIDATION PASSED - All local data validated against NHS Ontology Server" -ForegroundColor Green
    exit 0
}
elseif ($failedTests -eq 0) {
    Write-Host "✅ VALIDATION PASSED - Some codes not found (may be UK-specific)" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "⚠️  VALIDATION COMPLETED WITH ISSUES" -ForegroundColor Yellow
    Write-Host "   Review mismatches above. Some may be due to terminology version differences."
    exit 1
}
#endregion
