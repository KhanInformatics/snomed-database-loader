<#
.SYNOPSIS
    Unified weekly terminology update orchestrator for SNOMED CT, DMD, DMWB, and PCD.

.DESCRIPTION
    Checks for new releases from NHS TRUD, downloads, imports to database, 
    validates the data, and sends an email report.
    Designed for unattended scheduled execution.

.PARAMETER ConfigPath
    Path to TerminologyConfig.json. Default: .\Config\TerminologyConfig.json

.PARAMETER SkipSNOMED
    Skip SNOMED CT update

.PARAMETER SkipDMD
    Skip DMD update

.PARAMETER SkipDMWB
    Skip Data Migration Workbench update

.PARAMETER SkipPCD
    Skip Primary Care Domain refset validation

.PARAMETER SkipNotification
    Don't send email report

.PARAMETER Force
    Force download/import even if no new release detected

.PARAMETER WhatIf
    Show what would happen without making changes

.EXAMPLE
    .\Weekly-TerminologyUpdate.ps1
    
.EXAMPLE
    .\Weekly-TerminologyUpdate.ps1 -SkipSNOMED -Force

.EXAMPLE
    .\Weekly-TerminologyUpdate.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = ".\Config\TerminologyConfig.json",
    [switch]$SkipSNOMED,
    [switch]$SkipDMD,
    [switch]$SkipDMWB,
    [switch]$SkipPCD,
    [switch]$SkipNotification,
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$startTime = Get-Date
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Initialize results
$results = @{
    RunId         = [guid]::NewGuid().ToString()
    Success       = $true
    StartTime     = $startTime
    Duration      = ""
    UpdatesFound  = 0
    WhatIf        = [bool]$WhatIfPreference
    Force         = [bool]$Force
    Errors        = @()
    SNOMED        = $null
    DMD           = $null
    DMWB          = $null
    PCD           = $null
    LogFile       = ""
}

# Banner
Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "   Weekly Terminology Update" -ForegroundColor White
Write-Host "   Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "===============================================================================" -ForegroundColor Cyan

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $scriptDir "Config\TerminologyConfig.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Gray

# Canonical PCD supporting products are intentionally isolated from the core
# SNOMED database, which can approach the SQL Server Express 10 GB limit.
$pcdDatabaseName = if ($config.database.PSObject.Properties["pcdDatabase"] -and
    -not [string]::IsNullOrWhiteSpace([string]$config.database.pcdDatabase)) {
    [string]$config.database.pcdDatabase
} else {
    "PCD"
}

# Ensure log directory exists
$logDir = $config.paths.logsBase
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir "WeeklyUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$results.LogFile = $logFile

# Start transcript
Start-Transcript -Path $logFile -Append | Out-Null

Write-Host "Log file: $logFile" -ForegroundColor Gray

# Helper function to run a step with error handling
function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [hashtable]$ResultGroup
    )
    
    $step = @{
        Name      = $Name
        Success   = $false
        Details   = ""
        StartTime = Get-Date
        Duration  = ""
    }
    
    Write-Host ""
    Write-Host "  [$Name]" -ForegroundColor Yellow -NoNewline
    
    try {
        if ($WhatIfPreference) {
            $step.Success = $true
            $step.Details = "WhatIf: Would execute"
            Write-Host " (WhatIf)" -ForegroundColor Magenta
        } else {
            # Child scripts use Write-Error for failures. Promote those errors to
            # terminating errors within this step so they cannot be captured as
            # ordinary output and then reported as successful.
            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = "Stop"
                $output = & $Action 2>&1
            } finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            if ($output -is [bool] -and -not $output) {
                throw "$Name returned a failure result"
            }

            $step.Success = $true
            $step.Details = if ($output) { 
                $outStr = $output | Out-String
                $outStr.Trim().Substring(0, [Math]::Min(200, $outStr.Trim().Length)) 
            } else { 
                "Completed" 
            }
            Write-Host " [OK]" -ForegroundColor Green
        }
    } catch {
        $step.Success = $false
        $step.Details = $_.Exception.Message
        $script:results.Errors += "[$Name] $($_.Exception.Message)"
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $step.Duration = ((Get-Date) - $step.StartTime).ToString("mm\:ss")
    # A [ref] created from a hashtable property is only a temporary value in
    # PowerShell. Append through the containing hashtable so the step persists.
    $ResultGroup.Steps += $step
    
    return $step.Success
}

function Get-PcdCsvEncoding {
    param([Parameter(Mandatory = $true)][string]$Path)

    # PCD supporting products are currently Windows-1252 without a BOM, while
    # earlier releases may be UTF-8. Probe with a throwing UTF-8 decoder first
    # so accented clinical terms cannot silently become U+FFFD.
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.StreamReader]::new($stream, $strictUtf8, $true, 65536, $true)
        try {
            $buffer = [char[]]::new(65536)
            while ($reader.Read($buffer, 0, $buffer.Length) -gt 0) { }
            return $strictUtf8
        } finally {
            $reader.Dispose()
        }
    } catch [System.Text.DecoderFallbackException] {
        return [System.Text.Encoding]::GetEncoding(1252)
    } finally {
        $stream.Dispose()
    }
}

function ConvertTo-PcdFlagText {
    param([AllowNull()][object]$Value)

    if ($Value -is [bool]) {
        return $(if ($Value) { "1" } else { "0" })
    }

    $text = [string]$Value
    if ($text -eq "1" -or $text -eq "True") { return "1" }
    if ($text -eq "0" -or $text -eq "False") { return "0" }
    throw "Invalid PCD Boolean flag value '$text'"
}

function Get-PcdCanonicalRow {
    param(
        [Parameter(Mandatory = $true)][object]$Row,
        [Parameter(Mandatory = $true)][char]$Separator
    )

    return @(
        [string]$Row.Cluster_Category,
        [string]$Row.Cluster_ID,
        [string]$Row.Cluster_Desc,
        (ConvertTo-PcdFlagText $Row.Active_in_Refset),
        [string]$Row.Refset_Status_Date,
        [string]$Row.RefsetId,
        [string]$Row.Refset_Description,
        [string]$Row.ConceptId,
        [string]$Row.ConceptId_Description,
        (ConvertTo-PcdFlagText $Row.Active_Code_Status),
        [string]$Row.Code_Status_Date,
        [string]$Row.Type_of_Inclusion,
        (ConvertTo-PcdFlagText $Row.Sensitive_Status),
        [string]$Row.Sensitive_Status_Date
    ) -join $Separator
}

#region SNOMED CT Update
if (-not $SkipSNOMED) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "SNOMED CT Update" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $snomedResults = @{
        Success        = $true
        NewRelease     = $false
        ReleaseVersion = ""
        ReleaseDate    = ""
        ReleaseName    = ""
        Steps          = @()
        RowCounts      = @{}
    }
    
    $snomedDir = Join-Path $scriptDir "MSSQL"
    
    # Step 1: Check for new release
    $newReleaseDetected = $false
    $snomedCheckSucceeded = Invoke-Step -Name "Check for new SNOMED release" -ResultGroup $snomedResults -Action {
        $checkScript = Join-Path $snomedDir "Check-NewRelease.ps1"
        if (-not (Test-Path $checkScript)) {
            throw "Check-NewRelease.ps1 not found at $checkScript"
        }
        
        Push-Location $snomedDir
        try {
            # Capture output to determine if new release was found
            # *>&1 is required to capture Write-Host (stream 6) in addition to stdout/stderr
            $output = & $checkScript *>&1 | Out-String
            
            if ($output -match "New release found|New release detected|Downloading|new release available|Starting download") {
                $script:newReleaseDetected = $true
                return "New release detected - download initiated"
            } elseif ($output -match "No new release|up to date|Already have|No action taken") {
                return "No new release available"
            } else {
                return "Check completed"
            }
        } finally {
            Pop-Location
        }
    }
    
    # Determine if we should continue with SNOMED
    $snomedHasUpdate = $Force -or ($snomedCheckSucceeded -and $newReleaseDetected)
    
    if ($snomedHasUpdate) {
        $snomedResults.NewRelease = $true
        $results.UpdatesFound++
        
        # Fetch SNOMED release version and date from TRUD API
        try {
            Import-Module CredentialManager -ErrorAction SilentlyContinue
            $trudCred = Get-StoredCredential -Target $config.credentials.trudApiTarget -ErrorAction SilentlyContinue
            if ($trudCred) {
                $trudKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($trudCred.Password)
                )
                $monolithItem = $config.trudItems.snomedMonolith
                $trudUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$trudKey/items/$monolithItem/releases?latest"
                $trudResponse = Invoke-RestMethod -Uri $trudUrl -Method Get -ErrorAction Stop
                if ($trudResponse.releases.Count -gt 0) {
                    $rel = $trudResponse.releases[0]
                    $snomedResults.ReleaseDate = $rel.releaseDate
                    $snomedResults.ReleaseName = $rel.name
                    # Extract version from name (e.g. "Release 41.5.0") or from id
                    if ($rel.name -match '[\d]+\.[\d]+\.[\d]+') {
                        $snomedResults.ReleaseVersion = $Matches[0]
                    } elseif ($rel.id -match 'sct2mo_(\d+\.\d+\.\d+)') {
                        $snomedResults.ReleaseVersion = $Matches[1]
                    } else {
                        $snomedResults.ReleaseVersion = $rel.name
                    }
                    Write-Host "  SNOMED Release: $($snomedResults.ReleaseVersion) ($($snomedResults.ReleaseDate))" -ForegroundColor Green
                }
            }
        } catch {
            Write-Warning "Could not fetch SNOMED release info from TRUD: $($_.Exception.Message)"
        }
        
        # Step 2: Import to database
        Invoke-Step -Name "Import SNOMED to database" -ResultGroup $snomedResults -Action {
            $importScript = Join-Path $snomedDir "Generate-AndRun-AllSnapshots.ps1"
            if (-not (Test-Path $importScript)) {
                throw "Generate-AndRun-AllSnapshots.ps1 not found"
            }
            
            Push-Location $snomedDir
            try {
                & $importScript
                return "Import completed"
            } finally {
                Pop-Location
            }
        } | Out-Null
        
        # Step 3: Get row counts for validation
        Invoke-Step -Name "Validate SNOMED import" -ResultGroup $snomedResults -Action {
            $tables = @("curr_concept_f", "curr_description_f", "curr_relationship_f", "curr_langrefset_f")
            $counts = @()
            foreach ($table in $tables) {
                try {
                    $count = (Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                        -Database $config.database.snomedDatabase `
                        -Query "SELECT COUNT(*) as cnt FROM $table" `
                        -TrustServerCertificate -ErrorAction Stop).cnt
                    $snomedResults.RowCounts[$table] = $count
                    $counts += "$($table.Replace('curr_','').Replace('_f',''))=$($count.ToString('N0'))"
                } catch {
                    Write-Warning "Could not get count for $table"
                }
            }
            return "Counts: $($counts -join ', ')"
        } | Out-Null
    } elseif ($snomedCheckSucceeded -and -not $WhatIfPreference) {
        Write-Host "  No new SNOMED release - skipping download/import" -ForegroundColor Gray
        $snomedResults.Steps += @{
            Name     = "Skip"
            Success  = $true
            Details  = "No new release available"
            Duration = "00:00"
        }
    }
    
    $snomedResults.Success = ($snomedResults.Steps | Where-Object { -not $_.Success }).Count -eq 0
    $results.SNOMED = $snomedResults
    if (-not $snomedResults.Success) { $results.Success = $false }
}
#endregion

#region DMD Update
if (-not $SkipDMD) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "DMD Update" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $dmdResults = @{
        Success              = $true
        NewRelease           = $false
        ReleaseVersion       = ""
        Steps                = @()
        TableCounts          = @{}
        TableChanges         = @{}
        ValidationRate       = 0
        SnomedValidationRate = 0
    }
    
    $dmdDir = Join-Path $scriptDir "DMD"
    
    # Get current counts before update
    $preUpdateCounts = @{}
    try {
        $tables = @("vtm", "vmp", "amp", "vmpp", "ampp", "ampp_price", "vmpp_drugtariffinfo")
        foreach ($table in $tables) {
            $count = (Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                -Database $config.database.dmdDatabase `
                -Query "SELECT COUNT(*) as cnt FROM $table" `
                -TrustServerCertificate -ErrorAction SilentlyContinue).cnt
            if ($count) { $preUpdateCounts[$table] = $count }
        }
    } catch { }
    
    # Step 1: Check for new release
    $dmdNewReleaseDetected = $false
    $dmdCheckSucceeded = Invoke-Step -Name "Check for new DMD release" -ResultGroup $dmdResults -Action {
        $checkScript = Join-Path $dmdDir "Check-NewDMDRelease.ps1"
        if (-not (Test-Path $checkScript)) {
            throw "Check-NewDMDRelease.ps1 not found at $checkScript"
        }
        
        Push-Location $dmdDir
        try {
            # *>&1 is required to capture Write-Host (stream 6) in addition to stdout/stderr
            $output = & $checkScript -ServerInstance $config.database.serverInstance -Database $config.database.dmdDatabase -DataDirectory $config.paths.dmdBase *>&1 | Out-String
            
            # Check-NewDMDRelease performs the update itself. Match its terminal
            # success messages so "No new releases" cannot be mistaken for a
            # positive substring match.
            if ($output -match "DM\+D update complete!") {
                $script:dmdNewReleaseDetected = $true
                return "New release detected - download initiated"
            } elseif ($output -match "No new releases\. Database is already up to date") {
                return "No new release available"
            } else {
                return "Check completed"
            }
        } finally {
            Pop-Location
        }
    }
    
    $dmdHasUpdate = $Force -or ($dmdCheckSucceeded -and $dmdNewReleaseDetected)
    
    if ($dmdHasUpdate) {
        $dmdResults.NewRelease = $true
        $results.UpdatesFound++
        
        # Step 2: Download (if not already done by check script)
        if (-not $dmdNewReleaseDetected -and $Force) {
            Invoke-Step -Name "Download DMD release" -ResultGroup $dmdResults -Action {
                $downloadScript = Join-Path $dmdDir "Download-DMDReleases.ps1"
                if (Test-Path $downloadScript) {
                    Push-Location $dmdDir
                    try {
                        & $downloadScript
                        return "Download completed"
                    } finally {
                        Pop-Location
                    }
                }
                return "Download script not found"
            } | Out-Null
        }
        
        # Check-NewDMDRelease performs the download and import when it finds a
        # release. Only import here for a forced run where the check found none.
        if (-not $dmdNewReleaseDetected) {
            Invoke-Step -Name "Import DMD to database" -ResultGroup $dmdResults -Action {
            $importScript = Join-Path $dmdDir "StandaloneImports\Run-AllImports.ps1"
            
            # Find the release paths
            $currentReleases = Join-Path $config.paths.dmdBase "CurrentReleases"
            if (-not (Test-Path $currentReleases)) {
                throw "CurrentReleases folder not found at $currentReleases"
            }
            
            $mainRelease = Get-ChildItem $currentReleases -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -match "nhsbsa_dmd_\d" } | 
                Sort-Object Name -Descending | 
                Select-Object -First 1
            $bonusRelease = Get-ChildItem $currentReleases -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -match "nhsbsa_dmdbonus" } | 
                Sort-Object Name -Descending | 
                Select-Object -First 1
            
            if (-not $mainRelease) {
                throw "No DMD release folder found in $currentReleases"
            }
            
            if (-not (Test-Path $importScript)) {
                throw "Run-AllImports.ps1 not found"
            }
            
            # Store release version
            if ($mainRelease.Name -match "(\d+\.\d+\.\d+_\d+)") {
                $dmdResults.ReleaseVersion = $Matches[1]
            }
            
            Push-Location (Join-Path $dmdDir "StandaloneImports")
            try {
                $params = @{
                    XmlPath        = $mainRelease.FullName
                    ServerInstance = $config.database.serverInstance
                    DatabaseName   = $config.database.dmdDatabase
                }
                if ($bonusRelease) {
                    $params.BonusPath = $bonusRelease.FullName
                }
                & $importScript @params
                return "Import completed from $($mainRelease.Name)"
            } finally {
                Pop-Location
            }
            } | Out-Null
        }
        
        # Step 4: Get post-update counts
        Invoke-Step -Name "Collect table statistics" -ResultGroup $dmdResults -Action {
            $tables = @("vtm", "vmp", "amp", "vmpp", "ampp", "ingredient", "lookup", "ampp_price", "vmpp_drugtariffinfo")
            $changes = @()
            foreach ($table in $tables) {
                try {
                    $count = (Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                        -Database $config.database.dmdDatabase `
                        -Query "SELECT COUNT(*) as cnt FROM $table" `
                        -TrustServerCertificate -ErrorAction Stop).cnt
                    $dmdResults.TableCounts[$table] = $count
                    if ($preUpdateCounts.ContainsKey($table)) {
                        $diff = $count - $preUpdateCounts[$table]
                        $dmdResults.TableChanges[$table] = $diff
                        if ($diff -ne 0) {
                            $sign = if ($diff -gt 0) { "+" } else { "" }
                            $changes += "$table($sign$diff)"
                        }
                    }
                } catch {
                    Write-Warning "Could not get count for $table"
                }
            }
            $changeText = if ($changes.Count -gt 0) { $changes -join ", " } else { "No changes" }
            return "Changes: $changeText"
        } | Out-Null
        
        # Step 5: Validate against XML
        Invoke-Step -Name "Validate DMD against XML" -ResultGroup $dmdResults -Action {
            $validateScript = Join-Path $dmdDir "Validate-RandomSamples.ps1"
            $currentReleases = Join-Path $config.paths.dmdBase "CurrentReleases"
            $mainRelease = Get-ChildItem $currentReleases -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -match "nhsbsa_dmd_\d" } | 
                Sort-Object Name -Descending | 
                Select-Object -First 1
            
            if (-not (Test-Path $validateScript)) {
                return "Validation script not found"
            }
            if (-not $mainRelease) {
                return "Release folder not found"
            }
            
            Push-Location $dmdDir
            try {
                $output = & $validateScript -XmlPath $mainRelease.FullName -ServerInstance $config.database.serverInstance -Database $config.database.dmdDatabase -SamplesPerTable $config.validation.dmdSamplesPerTable 2>&1 | Out-String
                if ($output -match "Match Rate:\s*(\d+)") {
                    $dmdResults.ValidationRate = [int]$Matches[1]
                    return "Validation rate: $($dmdResults.ValidationRate)%"
                }
                return "Validation completed"
            } finally {
                Pop-Location
            }
        } | Out-Null
        
        # Step 6: Validate against local SNOMED (optional)
        if ($config.validation.validateAgainstLocalSnomed) {
            Invoke-Step -Name "Validate DMD against SNOMED CT" -ResultGroup $dmdResults -Action {
                $validateScript = Join-Path $dmdDir "Validate-LocalSNOMED.ps1"
                if (-not (Test-Path $validateScript)) {
                    return "SNOMED validation script not found"
                }
                
                Push-Location $dmdDir
                try {
                    $output = & $validateScript -SamplesPerTable $config.validation.snomedSamplesPerTable 2>&1 | Out-String
                    if ($output -match "Validation Rate:\s*(\d+)") {
                        $dmdResults.SnomedValidationRate = [int]$Matches[1]
                        return "SNOMED validation: $($dmdResults.SnomedValidationRate)%"
                    }
                    return "SNOMED validation completed"
                } finally {
                    Pop-Location
                }
            } | Out-Null
        }
    } elseif ($dmdCheckSucceeded -and -not $WhatIfPreference) {
        Write-Host "  No new DMD release - skipping download/import" -ForegroundColor Gray
        $dmdResults.Steps += @{
            Name     = "Skip"
            Success  = $true
            Details  = "No new release available"
            Duration = "00:00"
        }
    }
    
    # Always check pricing, including weeks with no new release. Missing tables,
    # changed values and removed tariff entries must not be reported as healthy.
    Invoke-Step -Name "Validate DMD pack prices against XML" -ResultGroup $dmdResults -Action {
        $releaseRoot = Join-Path $config.paths.dmdBase 'CurrentReleases'
        $priceRelease = Get-ChildItem -LiteralPath $releaseRoot -Directory -ErrorAction Stop |
            Where-Object { $_.Name -match '^nhsbsa_dmd_\d+\.\d+\.\d+_(\d+)$' } |
            Sort-Object { [regex]::Match($_.Name, '(\d+)$').Value } -Descending |
            Select-Object -First 1
        if (-not $priceRelease) { throw "No dm+d main release folder in $releaseRoot" }
        $priceChecks = @(& (Join-Path $dmdDir 'Validate-PackPrices.ps1') `
            -XmlPath $priceRelease.FullName -ServerInstance $config.database.serverInstance -Database $config.database.dmdDatabase)
        foreach ($check in $priceChecks) {
            $dmdResults.TableCounts[$check.Table] = $check.Rows
            if ($preUpdateCounts.ContainsKey($check.Table)) {
                $dmdResults.TableChanges[$check.Table] = $check.Rows - $preUpdateCounts[$check.Table]
            }
        }
        return "All pricing fields match XML: $(($priceChecks | ForEach-Object { "$($_.Table)=$($_.Rows)" }) -join ', ')"
    } | Out-Null

    $dmdResults.Success = ($dmdResults.Steps | Where-Object { -not $_.Success }).Count -eq 0
    $results.DMD = $dmdResults
    if (-not $dmdResults.Success) { $results.Success = $false }
}
#endregion

#region DMWB Update
if (-not $SkipDMWB) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Data Migration Workbench (DMWB) Update" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $dmwbResults = @{
        Success        = $true
        NewRelease     = $false
        ReleaseVersion = ""
        ReleaseDate    = ""
        ReleaseName    = ""
        Steps          = @()
        TableCounts    = @{}
    }
    
    $dmwbDir = Join-Path $scriptDir "DMWB"
    
    # Step 1: Check for new release
    $dmwbNewReleaseDetected = $false
    $dmwbCheckSucceeded = Invoke-Step -Name "Check for new DMWB release" -ResultGroup $dmwbResults -Action {
        $checkScript = Join-Path $dmwbDir "Check-NewDMWBRelease.ps1"
        if (-not (Test-Path $checkScript)) {
            throw "Check-NewDMWBRelease.ps1 not found at $checkScript"
        }
        
        Push-Location $dmwbDir
        try {
            $output = & $checkScript *>&1 | Out-String
            
            if ($output -match "NEW RELEASE DETECTED|New releases are available|Downloading|Starting download") {
                $script:dmwbNewReleaseDetected = $true
                return "New DMWB release detected"
            } elseif ($output -match "No new release|same as last check|latest version|No new releases detected") {
                return "No new release available"
            } else {
                return "Check completed"
            }
        } finally {
            Pop-Location
        }
    }
    
    $dmwbHasUpdate = $Force -or ($dmwbCheckSucceeded -and $dmwbNewReleaseDetected)
    
    if ($dmwbHasUpdate) {
        $dmwbResults.NewRelease = $true
        $results.UpdatesFound++
        
        # Fetch DMWB release version and date from TRUD API
        try {
            Import-Module CredentialManager -ErrorAction SilentlyContinue
            $trudCred = Get-StoredCredential -Target $config.credentials.trudApiTarget -ErrorAction SilentlyContinue
            if ($trudCred) {
                $trudKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($trudCred.Password)
                )
                $dmwbItem = $config.trudItems.dmwb
                $trudUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$trudKey/items/$dmwbItem/releases?latest"
                $trudResponse = Invoke-RestMethod -Uri $trudUrl -Method Get -ErrorAction Stop
                if ($trudResponse.releases.Count -gt 0) {
                    $rel = $trudResponse.releases[0]
                    $dmwbResults.ReleaseDate = $rel.releaseDate
                    $dmwbResults.ReleaseName = $rel.name
                    $dmwbResults.ReleaseVersion = $rel.name
                    Write-Host "  DMWB Release: $($dmwbResults.ReleaseName) ($($dmwbResults.ReleaseDate))" -ForegroundColor Green
                }
            }
        } catch {
            Write-Warning "Could not fetch DMWB release info from TRUD: $($_.Exception.Message)"
        }
        
        # Step 2: Download release
        Invoke-Step -Name "Download DMWB release" -ResultGroup $dmwbResults -Action {
            $downloadScript = Join-Path $dmwbDir "Download-DMWBReleases.ps1"
            if (-not (Test-Path $downloadScript)) {
                throw "Download-DMWBReleases.ps1 not found"
            }
            
            Push-Location $dmwbDir
            try {
                & $downloadScript
                return "Download completed"
            } finally {
                Pop-Location
            }
        } | Out-Null
        
        # Step 3: Export to SQL Server
        Invoke-Step -Name "Export DMWB to SQL Server" -ResultGroup $dmwbResults -Action {
            $exportScript = Join-Path $dmwbDir "Export-DmwbToSqlServer.ps1"
            if (-not (Test-Path $exportScript)) {
                throw "Export-DmwbToSqlServer.ps1 not found"
            }
            
            Push-Location $dmwbDir
            try {
                $params = @{
                    ServerInstance = $config.database.serverInstance
                    DatabaseName   = $config.database.dmwbDatabase
                    DropExisting   = $true
                }
                & $exportScript @params
                return "Export to SQL Server completed"
            } finally {
                Pop-Location
            }
        } | Out-Null
        
        # Step 4: Validate export (get table counts)
        Invoke-Step -Name "Validate DMWB export" -ResultGroup $dmwbResults -Action {
            $counts = @()
            try {
                $tables = Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                    -Database $config.database.dmwbDatabase `
                    -Query "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME" `
                    -TrustServerCertificate -ErrorAction Stop
                foreach ($t in $tables) {
                    $tableName = $t.TABLE_NAME
                    $count = (Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                        -Database $config.database.dmwbDatabase `
                        -Query "SELECT COUNT(*) as cnt FROM [$tableName]" `
                        -TrustServerCertificate -ErrorAction Stop).cnt
                    $dmwbResults.TableCounts[$tableName] = $count
                    $counts += "$tableName=$($count.ToString('N0'))"
                }
            } catch {
                Write-Warning "Could not validate DMWB tables: $($_.Exception.Message)"
            }
            if ($counts.Count -gt 0) {
                return "Tables: $($counts.Count), Records: $(($dmwbResults.TableCounts.Values | Measure-Object -Sum).Sum.ToString('N0'))"
            }
            return "Validation completed"
        } | Out-Null
    } elseif ($dmwbCheckSucceeded -and -not $WhatIfPreference) {
        Write-Host "  No new DMWB release - skipping download/export" -ForegroundColor Gray
        $dmwbResults.Steps += @{
            Name     = "Skip"
            Success  = $true
            Details  = "No new release available"
            Duration = "00:00"
        }
    }
    
    $dmwbResults.Success = ($dmwbResults.Steps | Where-Object { -not $_.Success }).Count -eq 0
    $results.DMWB = $dmwbResults
    if (-not $dmwbResults.Success) { $results.Success = $false }
}
#endregion

#region PCD Refset Validation
if (-not $SkipPCD) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Primary Care Domain (PCD) Refset Validation" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $pcdResults = @{
        Success        = $true
        Steps          = @()
        TableCounts    = @{}
        ValidationRate = 0
        TablesChecked  = 0
        TablesPassed   = 0
        DatabaseName   = $pcdDatabaseName
        RequiredTables = @(
            "PCD_GPData_Cluster_Refset",
            "PCD_GDPPR_Cluster_Refset"
        )
        OptionalTables = @(
            "PCD_Refset_Content_by_Output",
            "PCD_Refset_Content_V2",
            "PCD_Ruleset_Full_Name_Mappings_V2",
            "PCD_Service_Full_Name_Mappings_V2",
            "PCD_Output_Descriptions_V2"
        )
        RF2Status               = "Unknown"
        GPDataStatus            = "Unknown"
        GDPPRStatus             = "Unknown"
        SupportingProductsStatus = "Unknown"
        LegacyStatus            = "Unknown"
    }

    # Validate the official RF2 snapshot independently from the two canonical
    # supporting products and the legacy compatibility tables. These are
    # different products with different release semantics.
    Invoke-Step -Name "Validate current PCD RF2 snapshot" -ResultGroup $pcdResults -Action {
        $currentReleases = Join-Path $config.paths.snomedBase "CurrentReleases"
        $release = Get-ChildItem -LiteralPath $currentReleases -Directory -Filter "uk_sct2pc_*" -ErrorAction Stop |
            ForEach-Object {
                if ($_.Name -match '_(?<stamp>\d{14})Z$') {
                    [pscustomobject]@{ Path = $_.FullName; Stamp = $Matches.stamp }
                }
            } |
            Sort-Object Stamp -Descending |
            Select-Object -First 1
        if (-not $release) {
            throw "No timestamped uk_sct2pc release found in $currentReleases"
        }

        $snapshotFile = Get-ChildItem -LiteralPath $release.Path -Recurse -File `
            -Filter "der2_Refset_SimpleUKPCSnapshot_*.txt" -ErrorAction Stop |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if (-not $snapshotFile) {
            throw "Current PCD simple-refset snapshot not found below $($release.Path)"
        }

        $requiredHeaders = @("id", "effectiveTime", "active", "moduleId", "refsetId", "referencedComponentId")
        $actualHeaders = (Get-Content -LiteralPath $snapshotFile.FullName -TotalCount 1) -split "`t"
        $missingHeaders = @($requiredHeaders | Where-Object { $_ -notin $actualHeaders })
        if ($missingHeaders.Count -gt 0) {
            throw "PCD RF2 snapshot is missing required columns: $($missingHeaders -join ', ')"
        }

        $pcdModuleId = "999000011000230102"
        $sourceRows = @(Import-Csv -LiteralPath $snapshotFile.FullName -Delimiter "`t" |
            Where-Object { $_.moduleId -eq $pcdModuleId })
        if ($sourceRows.Count -eq 0) {
            throw "PCD RF2 snapshot contains no rows for module $pcdModuleId"
        }

        $dbRows = @(Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
            -Database $config.database.snomedDatabase `
            -Query @"
SELECT id, effectiveTime, active, moduleId, refsetId, referencedComponentId
FROM dbo.curr_simplerefset_f
WHERE moduleId = '$pcdModuleId';
"@ `
            -TrustServerCertificate -QueryTimeout 120 -ErrorAction Stop)

        $separator = [char]31
        # RF2 UUID text casing differs between the source file and SqlClient's
        # System.Guid rendering; identifiers are case-insensitive by definition.
        $rf2Comparer = [System.StringComparer]::OrdinalIgnoreCase
        $sourceKeys = [System.Collections.Generic.HashSet[string]]::new($rf2Comparer)
        foreach ($row in $sourceRows) {
            [void]$sourceKeys.Add("$($row.id)$separator$($row.effectiveTime)$separator$($row.active)$separator$($row.moduleId)$separator$($row.refsetId)$separator$($row.referencedComponentId)")
        }
        $dbKeys = [System.Collections.Generic.HashSet[string]]::new($rf2Comparer)
        foreach ($row in $dbRows) {
            [void]$dbKeys.Add("$($row.id)$separator$($row.effectiveTime)$separator$($row.active)$separator$($row.moduleId)$separator$($row.refsetId)$separator$($row.referencedComponentId)")
        }

        $missing = [System.Collections.Generic.HashSet[string]]::new($sourceKeys, $rf2Comparer)
        $missing.ExceptWith($dbKeys)
        $stale = [System.Collections.Generic.HashSet[string]]::new($dbKeys, $rf2Comparer)
        $stale.ExceptWith($sourceKeys)
        $sourceDuplicates = $sourceRows.Count - $sourceKeys.Count
        $dbDuplicates = $dbRows.Count - $dbKeys.Count

        if ($missing.Count -gt 0 -or $stale.Count -gt 0 -or $sourceDuplicates -gt 0 -or $dbDuplicates -gt 0) {
            $pcdResults.RF2Status = "Mismatch"
            throw "RF2 exact-row mismatch: source=$($sourceRows.Count), database=$($dbRows.Count), missing=$($missing.Count), stale=$($stale.Count), source duplicates=$sourceDuplicates, database duplicates=$dbDuplicates"
        }

        $activeSourceRows = @($sourceRows | Where-Object { $_.active -eq "1" })
        $sourceRefsets = @($activeSourceRows.refsetId | Sort-Object -Unique).Count
        $sourceEffectiveTime = ($sourceRows.effectiveTime | Measure-Object -Maximum).Maximum
        $pcdResults.RF2Status = "Current"
        if ((Split-Path $release.Path -Leaf) -match '^uk_sct2pc_(\d+\.\d+\.\d+)_(\d{8})') {
            $pcdResults.ReleaseVersion = $Matches[1]
            $pcdResults.ReleaseDate = [datetime]::ParseExact($Matches[2], 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
        }
        return "Current release $(Split-Path $release.Path -Leaf): exact match for $($sourceRows.Count) snapshot rows ($($activeSourceRows.Count) active), $sourceRefsets active refsets, effectiveTime $sourceEffectiveTime"
    } | Out-Null

    Invoke-Step -Name "Load current PCD supporting products" -ResultGroup $pcdResults -Action {
        $supportingProductLoader = Join-Path $scriptDir "MSSQL\Import-PCD-SupportingProducts.ps1"
        if (-not (Test-Path -LiteralPath $supportingProductLoader -PathType Leaf)) {
            throw "Import-PCD-SupportingProducts.ps1 not found at $supportingProductLoader"
        }

        $loadParameters = @{
            ServerInstance = $config.database.serverInstance
            DatabaseName   = $pcdDatabaseName
            ReleasesPath   = Join-Path $config.paths.snomedBase "CurrentReleases"
            Force          = [bool]$Force
        }
        $loadResult = & $supportingProductLoader @loadParameters
        if (-not $loadResult -or -not [bool]$loadResult.Success) {
            throw "Canonical PCD supporting-product loader returned an unsuccessful result"
        }

        $details = @(
            foreach ($product in @($loadResult.Products)) {
                $loadAction = if ($product.Skipped) { "already current" } else { "loaded" }
                "$($product.ProductCode)=$loadAction ($(([int64]$product.SourceRows).ToString('N0')) rows, $($product.SourceEncoding))"
            }
        )
        return $details -join "; "
    } | Out-Null

    Invoke-Step -Name "Validate current PCD supporting products" -ResultGroup $pcdResults -Action {
        $currentReleases = Join-Path $config.paths.snomedBase "CurrentReleases"
        $release = Get-ChildItem -LiteralPath $currentReleases -Directory -Filter "uk_sct2pc_*" -ErrorAction Stop |
            ForEach-Object {
                if ($_.Name -match '_(?<stamp>\d{14})Z$') {
                    [pscustomobject]@{ Path = $_.FullName; Stamp = $Matches.stamp }
                }
            } |
            Sort-Object Stamp -Descending |
            Select-Object -First 1
        if (-not $release) {
            throw "No timestamped uk_sct2pc release found in $currentReleases"
        }

        $sourceColumns = @(
            "Cluster_Category", "Cluster_ID", "Cluster_Desc", "Active_in_Refset",
            "Refset_Status_Date", "RefsetId", "Refset_Description", "ConceptId",
            "ConceptId_Description", "Active_Code_Status", "Code_Status_Date",
            "Type_of_Inclusion", "Sensitive_Status", "Sensitive_Status_Date"
        )
        $separator = [char]31
        $passed = 0
        $mismatches = @()
        $validatedProducts = @()
        foreach ($product in @(
            @{ Code = "GPData"; Table = "PCD_GPData_Cluster_Refset" },
            @{ Code = "GDPPR"; Table = "PCD_GDPPR_Cluster_Refset" }
        )) {
            $productCode = $product.Code
            $table = $product.Table
            try {
                $sourceFile = Get-ChildItem -LiteralPath $release.Path -Recurse -File `
                    -Filter "${productCode}_Cluster_Refset_*.csv" -ErrorAction Stop |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
                if (-not $sourceFile) {
                    throw "Current $productCode supporting product not found below $($release.Path)"
                }

                $sourceEncoding = Get-PcdCsvEncoding -Path $sourceFile.FullName
                $sourceRows = @(Import-Csv -LiteralPath $sourceFile.FullName -Encoding $sourceEncoding)
                if ($sourceRows.Count -eq 0) {
                    throw "Current $productCode supporting product is empty: $($sourceFile.FullName)"
                }

                $actualHeaders = @($sourceRows[0].PSObject.Properties.Name)
                $missingHeaders = @($sourceColumns | Where-Object { $_ -notin $actualHeaders })
                $unexpectedHeaders = @($actualHeaders | Where-Object { $_ -notin $sourceColumns })
                if ($missingHeaders.Count -gt 0 -or $unexpectedHeaders.Count -gt 0) {
                    throw "$productCode schema mismatch. Missing=[$($missingHeaders -join ', ')]; unexpected=[$($unexpectedHeaders -join ', ')]"
                }

                $sourceCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                $sourceMembership = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                $sourceHasReplacementCharacter = $false
                $activeRows = 0
                foreach ($row in $sourceRows) {
                    foreach ($column in $sourceColumns) {
                        if (([string]$row.$column).Contains([char]0xFFFD)) {
                            $sourceHasReplacementCharacter = $true
                        }
                    }
                    [void]$sourceCanonical.Add((Get-PcdCanonicalRow -Row $row -Separator $separator))
                    [void]$sourceMembership.Add("$($row.Cluster_ID)$separator$($row.ConceptId)$separator$($row.RefsetId)")
                    if ($row.Active_in_Refset -eq "1" -and $row.Active_Code_Status -eq "1") {
                        $activeRows++
                    }
                }
                if ($sourceHasReplacementCharacter) {
                    throw "$productCode source contains U+FFFD after $($sourceEncoding.WebName) decoding"
                }

                $dbRows = @(Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                    -Database $pcdDatabaseName `
                    -Query @"
SELECT Cluster_Category, Cluster_ID, Cluster_Desc, Active_in_Refset,
       Refset_Status_Date, RefsetId, Refset_Description, ConceptId,
       ConceptId_Description, Active_Code_Status, Code_Status_Date,
       Type_of_Inclusion, Sensitive_Status, Sensitive_Status_Date
FROM dbo.[$table];
"@ `
                    -TrustServerCertificate -QueryTimeout 300 -ErrorAction Stop)
                $pcdResults.TableCounts[$table] = $dbRows.Count

                $dbCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                $dbMembership = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                foreach ($row in $dbRows) {
                    [void]$dbCanonical.Add((Get-PcdCanonicalRow -Row $row -Separator $separator))
                    [void]$dbMembership.Add("$($row.Cluster_ID)$separator$($row.ConceptId)$separator$($row.RefsetId)")
                }

                $missing = [System.Collections.Generic.HashSet[string]]::new($sourceCanonical, [System.StringComparer]::Ordinal)
                $missing.ExceptWith($dbCanonical)
                $stale = [System.Collections.Generic.HashSet[string]]::new($dbCanonical, [System.StringComparer]::Ordinal)
                $stale.ExceptWith($sourceCanonical)
                $sourceDuplicateRows = $sourceRows.Count - $sourceCanonical.Count
                $databaseDuplicateRows = $dbRows.Count - $dbCanonical.Count
                $sourceDuplicateMemberships = $sourceRows.Count - $sourceMembership.Count
                $databaseDuplicateMemberships = $dbRows.Count - $dbMembership.Count

                if ($missing.Count -gt 0 -or $stale.Count -gt 0 -or
                    $sourceDuplicateRows -gt 0 -or $databaseDuplicateRows -gt 0 -or
                    $sourceDuplicateMemberships -gt 0 -or $databaseDuplicateMemberships -gt 0) {
                    throw "exact 14-field mismatch: source=$($sourceRows.Count), database=$($dbRows.Count), missing=$($missing.Count), stale=$($stale.Count), source row duplicates=$sourceDuplicateRows, database row duplicates=$databaseDuplicateRows, source membership duplicates=$sourceDuplicateMemberships, database membership duplicates=$databaseDuplicateMemberships"
                }

                $passed++
                $pcdResults["${productCode}Status"] = "Current"
                $validatedProducts += "$productCode=$($sourceRows.Count.ToString('N0')) rows/$($activeRows.ToString('N0')) active ($($sourceEncoding.WebName))"
            } catch {
                $pcdResults["${productCode}Status"] = "Mismatch"
                if (-not $pcdResults.TableCounts.ContainsKey($table)) {
                    $pcdResults.TableCounts[$table] = -1
                }
                $mismatches += "${productCode}: $($_.Exception.Message)"
            }
        }

        $pcdResults.TablesChecked = $pcdResults.RequiredTables.Count
        $pcdResults.TablesPassed = $passed
        $pcdResults.ValidationRate = [math]::Round(($passed / $pcdResults.TablesChecked) * 100)
        if ($mismatches.Count -gt 0) {
            $pcdResults.SupportingProductsStatus = "Mismatch"
            throw "Current PCD supporting-product validation failed: $($mismatches -join '; ')"
        }

        $pcdResults.SupportingProductsStatus = "Current"
        return "Exact 14-field matches: $($validatedProducts -join '; ')"
    } | Out-Null

    Invoke-Step -Name "Inspect legacy PCD enrichment tables" -ResultGroup $pcdResults -Action {
        $currentReleases = Join-Path $config.paths.snomedBase "CurrentReleases"
        $release = Get-ChildItem -LiteralPath $currentReleases -Directory -Filter "uk_sct2pc_*" -ErrorAction Stop |
            ForEach-Object {
                if ($_.Name -match '_(?<stamp>\d{14})Z$') {
                    [pscustomobject]@{ Path = $_.FullName; Stamp = $Matches.stamp }
                }
            } |
            Sort-Object Stamp -Descending |
            Select-Object -First 1
        if (-not $release) {
            throw "No timestamped uk_sct2pc release found in $currentReleases"
        }

        $details = @()
        foreach ($table in $pcdResults.OptionalTables) {
            try {
                $count = (Invoke-Sqlcmd -ServerInstance $config.database.serverInstance `
                    -Database $config.database.snomedDatabase `
                    -Query "SELECT COUNT_BIG(*) AS cnt FROM dbo.[$table]" `
                    -TrustServerCertificate -ErrorAction Stop).cnt
                $pcdResults.TableCounts[$table] = $count
                $details += "$($table.Replace('PCD_',''))=$($count.ToString('N0'))"
            } catch {
                $pcdResults.TableCounts[$table] = -1
                $details += "$($table.Replace('PCD_',''))=MISSING"
            }
        }

        $legacyPatterns = @(
            "*PCD_Ruleset_Full_Name_Mappings*",
            "*PCD_Service_Full_Name_Mappings*",
            "*PCD_Output_Descriptions*"
        )
        $legacyFiles = @(
            foreach ($pattern in $legacyPatterns) {
                Get-ChildItem -LiteralPath $release.Path -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
            }
        )
        $releaseName = Split-Path $release.Path -Leaf
        if ($legacyFiles.Count -gt 0) {
            $pcdResults.LegacyStatus = "Available in $releaseName - validator update required"
            throw "Current release contains legacy enrichment feed(s) that are not yet validated: $($legacyFiles.Name -join ', ')"
        }

        $pcdResults.LegacyStatus = "N/A - not supplied in $releaseName"
        return "$($pcdResults.LegacyStatus). Compatibility tables: $($details -join ', ')"
    } | Out-Null

    $pcdResults.Success = ($pcdResults.Steps | Where-Object { -not $_.Success }).Count -eq 0
    $results.PCD = $pcdResults
    if (-not $pcdResults.Success) { $results.Success = $false }
}
#endregion

# An error must never coexist with a successful overall result.
if ($results.Errors.Count -gt 0) {
    $results.Success = $false
}

# Calculate the core workflow duration before publishing the report.
$results.Duration = ((Get-Date) - $startTime).ToString("hh\:mm\:ss")

# Export to Azure SQL Reporting Database
if (-not $WhatIfPreference -and $config.azureReporting -and $config.azureReporting.enabled) {
    Write-Host ""
    Write-Host "Exporting to Azure SQL..." -ForegroundColor Yellow
    $exportScript = Join-Path $scriptDir "Export-ReportToAzure.ps1"
    if (Test-Path $exportScript) {
        try {
            $exportResult = & $exportScript -Results $results -ConfigPath $ConfigPath
            if (-not $exportResult -or -not $exportResult.Success) {
                throw "Azure SQL exporter returned an unsuccessful result"
            }
            Write-Host "Report exported to Azure SQL (Run ID: $($exportResult.RunId))" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to export to Azure SQL: $_"
            $results.Errors += "Azure SQL export failed: $_"
            $results.Success = $false
        }
    } else {
        $message = "Export-ReportToAzure.ps1 not found while Azure reporting is enabled"
        Write-Warning $message
        $results.Errors += "Azure SQL export failed: $message"
        $results.Success = $false
    }
}

# Export to Azure Blob Storage (for instant dashboard access)
if (-not $WhatIfPreference) {
    Write-Host ""
    Write-Host "Exporting to Azure Blob Storage..." -ForegroundColor Yellow
    $blobScript = Join-Path $scriptDir "Export-ReportToBlob.ps1"
    if (Test-Path $blobScript) {
        try {
            $blobResult = & $blobScript -Results $results -ConfigPath $ConfigPath
            if ($blobResult.Success) {
                Write-Host "Dashboard JSON uploaded to: $($blobResult.BlobUrl)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to export to Blob Storage: $_"
            # Don't add to errors - blob export is optional
        }
    }
}

# Send notification
if (-not $SkipNotification -and -not $WhatIfPreference) {
    Write-Host ""
    Write-Host "Sending email report..." -ForegroundColor Yellow
    $reportScript = Join-Path $scriptDir "Send-UpdateReport.ps1"
    if (Test-Path $reportScript) {
        try {
            $emailResult = & $reportScript -Results $results -ConfigPath $ConfigPath
            if ($emailResult -is [bool] -and -not $emailResult) {
                throw "Email reporter returned an unsuccessful result"
            }
        } catch {
            Write-Error "Failed to send report: $_"
            $results.Errors += "Email notification failed: $_"
            $results.Success = $false
        }
    } else {
        Write-Warning "Send-UpdateReport.ps1 not found - skipping notification"
    }
}

# Final duration and summary include publishing/notification work and therefore
# reflect every required failure that occurred during the run.
$results.Duration = ((Get-Date) - $startTime).ToString("hh\:mm\:ss")
if ($results.Errors.Count -gt 0) {
    $results.Success = $false
}

# Publish the completed outcome even when an import or notification failed.
# EndTime/duration describe the workflow before GitHub transport/deployment.
$results.EndTime = Get-Date
# Capture installed release identifiers only after successful product work.
if (-not $WhatIfPreference) {
    if ($results.DMD -and $results.DMD.Success) {
        $importRecordPath = Join-Path $config.paths.dmdBase 'LastImportedRelease.json'
        if (Test-Path -LiteralPath $importRecordPath) {
            $importRecord = Get-Content -LiteralPath $importRecordPath -Raw | ConvertFrom-Json
            if ($importRecord.DMD_Main -match '^nhsbsa_dmd_(\d+\.\d+\.\d+)_') { $results.DMD.ReleaseVersion = $Matches[1] }
        }
    }
    if ($results.DMWB -and $results.DMWB.Success -and $results.DMWB.ReleaseName -match '_(\d+\.\d+\.\d+)_') { $results.DMWB.ReleaseVersion = $Matches[1] }
    if ($results.PCD -and $results.PCD.Success) {
        try {
            $loaded = Invoke-Sqlcmd -ServerInstance $config.database.serverInstance -Database $pcdDatabaseName -TrustServerCertificate -Query "SELECT MAX(Completed_At) AS LastUpdated FROM dbo.PCD_GPData_Load_History WHERE Success=1 AND Product_Code IN ('GPData','GDPPR')" -ErrorAction Stop
            if ($loaded.LastUpdated -is [datetime]) { $results.PCD.LastUpdated = [datetime]::SpecifyKind($loaded.LastUpdated, [DateTimeKind]::Utc).ToLocalTime().ToString('yyyy-MM-dd') }
        } catch { Write-Warning 'PCD last-updated metadata is unavailable; the previous recorded date will be retained.' }
    }
}
if (-not $WhatIfPreference -and $config.githubReporting -and $config.githubReporting.enabled) {
    try {
        $githubResult = & (Join-Path $scriptDir 'Export-ReportToGitHub.ps1') -Results $results -ConfigPath $ConfigPath
        if (-not $githubResult.Success) { throw 'GitHub publisher returned an unsuccessful result.' }
        Write-Host "Report committed to GitHub; website deployment is handled by Actions." -ForegroundColor Green
    } catch {
        $results.Errors += "GitHub report publishing failed: $($_.Exception.Message)"
        $results.Success = $false
        Write-Warning 'Report publishing failed. Replay the saved report without rerunning imports.'
    }
}

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "   SUMMARY" -ForegroundColor White
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  Duration:       $($results.Duration)" -ForegroundColor Gray
Write-Host "  Updates Found:  $($results.UpdatesFound)" -ForegroundColor Gray

$statusColor = if ($results.Success) { "Green" } else { "Red" }
$statusText = if ($results.Success) { "SUCCESS" } else { "FAILED" }
Write-Host "  Overall Status: $statusText" -ForegroundColor $statusColor

if ($results.Errors.Count -gt 0) {
    Write-Host ""
    Write-Host "  Errors:" -ForegroundColor Red
    foreach ($err in $results.Errors) {
        Write-Host "    - $err" -ForegroundColor Red
    }
}

Stop-Transcript | Out-Null

Write-Host ""
Write-Host "Log file: $logFile" -ForegroundColor Gray
Write-Host ""

# Set exit code based on success
if (-not $results.Success) {
    exit 1
}

# Return results for pipeline use
return $results
