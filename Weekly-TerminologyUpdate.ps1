<#
.SYNOPSIS
    Unified weekly terminology update orchestrator for SNOMED CT and DMD.

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
    [switch]$SkipNotification,
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$startTime = Get-Date
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Initialize results
$results = @{
    Success       = $true
    StartTime     = $startTime
    Duration      = ""
    UpdatesFound  = 0
    Errors        = @()
    SNOMED        = $null
    DMD           = $null
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
        [ref]$StepResults
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
        if ($WhatIf) {
            $step.Success = $true
            $step.Details = "WhatIf: Would execute"
            Write-Host " (WhatIf)" -ForegroundColor Magenta
        } else {
            $output = & $Action 2>&1
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
    $StepResults.Value += $step
    
    return $step.Success
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
        Steps          = @()
        RowCounts      = @{}
    }
    
    $snomedDir = Join-Path $scriptDir "MSSQL"
    
    # Step 1: Check for new release
    $newReleaseDetected = $false
    Invoke-Step -Name "Check for new SNOMED release" -StepResults ([ref]$snomedResults.Steps) -Action {
        $checkScript = Join-Path $snomedDir "Check-NewRelease.ps1"
        if (-not (Test-Path $checkScript)) {
            throw "Check-NewRelease.ps1 not found at $checkScript"
        }
        
        Push-Location $snomedDir
        try {
            # Capture output to determine if new release was found
            $output = & $checkScript 2>&1 | Out-String
            
            if ($output -match "New release found|Downloading|new release available|Starting download") {
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
    } | Out-Null
    
    # Determine if we should continue with SNOMED
    $snomedHasUpdate = $Force -or $newReleaseDetected
    
    if ($snomedHasUpdate) {
        $snomedResults.NewRelease = $true
        $results.UpdatesFound++
        
        # Step 2: Import to database
        Invoke-Step -Name "Import SNOMED to database" -StepResults ([ref]$snomedResults.Steps) -Action {
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
        Invoke-Step -Name "Validate SNOMED import" -StepResults ([ref]$snomedResults.Steps) -Action {
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
    } else {
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
        $tables = @("vtm", "vmp", "amp", "vmpp", "ampp")
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
    Invoke-Step -Name "Check for new DMD release" -StepResults ([ref]$dmdResults.Steps) -Action {
        $checkScript = Join-Path $dmdDir "Check-NewDMDRelease.ps1"
        if (-not (Test-Path $checkScript)) {
            throw "Check-NewDMDRelease.ps1 not found at $checkScript"
        }
        
        Push-Location $dmdDir
        try {
            $output = & $checkScript 2>&1 | Out-String
            
            if ($output -match "New release|Downloading|new release available|Release \d.*new|Starting download") {
                $script:dmdNewReleaseDetected = $true
                return "New release detected - download initiated"
            } elseif ($output -match "No new release|up to date|Already have|Already imported") {
                return "No new release available"
            } else {
                return "Check completed"
            }
        } finally {
            Pop-Location
        }
    } | Out-Null
    
    $dmdHasUpdate = $Force -or $dmdNewReleaseDetected
    
    if ($dmdHasUpdate) {
        $dmdResults.NewRelease = $true
        $results.UpdatesFound++
        
        # Step 2: Download (if not already done by check script)
        if (-not $dmdNewReleaseDetected -and $Force) {
            Invoke-Step -Name "Download DMD release" -StepResults ([ref]$dmdResults.Steps) -Action {
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
        
        # Step 3: Import
        Invoke-Step -Name "Import DMD to database" -StepResults ([ref]$dmdResults.Steps) -Action {
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
        
        # Step 4: Get post-update counts
        Invoke-Step -Name "Collect table statistics" -StepResults ([ref]$dmdResults.Steps) -Action {
            $tables = @("vtm", "vmp", "amp", "vmpp", "ampp", "ingredient", "lookup")
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
        Invoke-Step -Name "Validate DMD against XML" -StepResults ([ref]$dmdResults.Steps) -Action {
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
                $output = & $validateScript -XmlPath $mainRelease.FullName -SamplesPerTable $config.validation.dmdSamplesPerTable 2>&1 | Out-String
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
            Invoke-Step -Name "Validate DMD against SNOMED CT" -StepResults ([ref]$dmdResults.Steps) -Action {
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
    } else {
        Write-Host "  No new DMD release - skipping download/import" -ForegroundColor Gray
        $dmdResults.Steps += @{
            Name     = "Skip"
            Success  = $true
            Details  = "No new release available"
            Duration = "00:00"
        }
    }
    
    $dmdResults.Success = ($dmdResults.Steps | Where-Object { -not $_.Success }).Count -eq 0
    $results.DMD = $dmdResults
    if (-not $dmdResults.Success) { $results.Success = $false }
}
#endregion

# Calculate duration
$results.Duration = ((Get-Date) - $startTime).ToString("hh\:mm\:ss")

# Summary
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

# Stop transcript
Stop-Transcript | Out-Null

# Send notification
if (-not $SkipNotification -and -not $WhatIf) {
    Write-Host ""
    Write-Host "Sending email report..." -ForegroundColor Yellow
    $reportScript = Join-Path $scriptDir "Send-UpdateReport.ps1"
    if (Test-Path $reportScript) {
        try {
            & $reportScript -Results $results -ConfigPath $ConfigPath
        } catch {
            Write-Error "Failed to send report: $_"
            $results.Errors += "Email notification failed: $_"
        }
    } else {
        Write-Warning "Send-UpdateReport.ps1 not found - skipping notification"
    }
}

Write-Host ""
Write-Host "Log file: $logFile" -ForegroundColor Gray
Write-Host ""

# Set exit code based on success
if (-not $results.Success) {
    exit 1
}

# Return results for pipeline use
return $results
