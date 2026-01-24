<#
.SYNOPSIS
    Exports terminology update results to Azure SQL reporting database.

.DESCRIPTION
    Takes the results hashtable from Weekly-TerminologyUpdate.ps1 and inserts
    records into the Azure SQL ReportingServer database for Blazor app consumption.

.PARAMETER Results
    The results hashtable from Weekly-TerminologyUpdate.ps1

.PARAMETER ConfigPath
    Path to TerminologyConfig.json containing Azure SQL connection details

.PARAMETER RunId
    Optional GUID for the run. If not provided, a new one is generated.

.EXAMPLE
    .\Export-ReportToAzure.ps1 -Results $results -ConfigPath .\Config\TerminologyConfig.json

.NOTES
    Requires: SqlServer module, Azure AD authentication configured
    Target: azuresnnomedct.database.windows.net / ReportingServer
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Results,
    
    [string]$ConfigPath = ".\Config\TerminologyConfig.json",
    
    [guid]$RunId = [guid]::NewGuid()
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Get-SafeString {
    param([string]$Value, [int]$MaxLength = 500)
    if ([string]::IsNullOrEmpty($Value)) { return "NULL" }
    $escaped = $Value.Replace("'", "''")
    if ($escaped.Length -gt $MaxLength) {
        $escaped = $escaped.Substring(0, $MaxLength - 3) + "..."
    }
    return "'$escaped'"
}

function Get-SafeInt {
    param($Value)
    if ($null -eq $Value) { return "NULL" }
    return [int]$Value
}

function Get-SafeBit {
    param($Value)
    if ($null -eq $Value) { return "0" }
    if ($Value) { return "1" } else { return "0" }
}

function Get-SafeDecimal {
    param($Value)
    if ($null -eq $Value) { return "NULL" }
    return [decimal]$Value
}

function Invoke-AzureSql {
    param(
        [string]$ConnectionString,
        [string]$Query
    )
    
    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "SQL Error: $_"
        Write-Warning "Query: $($Query.Substring(0, [Math]::Min(500, $Query.Length)))..."
        return $false
    }
}

#endregion

#region Main Script

Write-Host ""
Write-Host "Exporting results to Azure SQL Reporting Database..." -ForegroundColor Cyan

# Load configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $scriptDir "Config\TerminologyConfig.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    return $false
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Get Azure SQL connection string
if (-not $config.azureReporting) {
    Write-Error "Azure reporting configuration not found in config file"
    return $false
}

$connectionString = $config.azureReporting.connectionString

if ([string]::IsNullOrEmpty($connectionString)) {
    Write-Error "Azure SQL connection string is empty"
    return $false
}

Write-Host "  Target: $($config.azureReporting.server)/$($config.azureReporting.database)" -ForegroundColor Gray

# Test connection
try {
    Invoke-Sqlcmd -ConnectionString $connectionString -Query "SELECT 1" -ErrorAction Stop | Out-Null
    Write-Host "  Connection: OK" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Azure SQL: $_"
    return $false
}

#region Insert update_runs record

$endTime = if ($Results.StartTime) { 
    $Results.StartTime.AddSeconds(
        [timespan]::Parse($Results.Duration ?? "00:00:00").TotalSeconds
    ) 
} else { 
    Get-Date 
}

$durationSeconds = if ($Results.Duration) {
    [int][timespan]::Parse($Results.Duration).TotalSeconds
} else { 0 }

$updateRunsQuery = @"
INSERT INTO update_runs (
    run_id, start_time, end_time, duration_seconds, duration_formatted,
    success, updates_found, server_name, log_file_path, config_path,
    whatif_mode, forced_run
) VALUES (
    '$RunId',
    '$($Results.StartTime.ToString("yyyy-MM-dd HH:mm:ss"))',
    '$($endTime.ToString("yyyy-MM-dd HH:mm:ss"))',
    $durationSeconds,
    $(Get-SafeString $Results.Duration 20),
    $(Get-SafeBit $Results.Success),
    $(Get-SafeInt $Results.UpdatesFound),
    $(Get-SafeString $env:COMPUTERNAME 255),
    $(Get-SafeString $Results.LogFile 500),
    $(Get-SafeString $ConfigPath 500),
    $(Get-SafeBit $Results.WhatIf),
    $(Get-SafeBit $Results.Force)
)
"@

Write-Host "  Inserting update_runs..." -NoNewline
if (Invoke-AzureSql -ConnectionString $connectionString -Query $updateRunsQuery) {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    return $false
}

#endregion

#region Insert snomed_updates record

if ($Results.SNOMED) {
    $snomed = $Results.SNOMED
    
    # Get row counts from local database if available
    $conceptCount = $snomed.RowCounts?["curr_concept_f"] ?? $snomed.ConceptCount
    $descriptionCount = $snomed.RowCounts?["curr_description_f"] ?? $snomed.DescriptionCount
    $relationshipCount = $snomed.RowCounts?["curr_relationship_f"] ?? $snomed.RelationshipCount
    $langrefsetCount = $snomed.RowCounts?["curr_langrefset_f"] ?? $snomed.LangRefsetCount
    
    $snomedQuery = @"
INSERT INTO snomed_updates (
    run_id, success, new_release, release_version,
    concept_count, description_count, relationship_count, langrefset_count
) VALUES (
    '$RunId',
    $(Get-SafeBit $snomed.Success),
    $(Get-SafeBit $snomed.NewRelease),
    $(Get-SafeString $snomed.ReleaseVersion 100),
    $(Get-SafeInt $conceptCount),
    $(Get-SafeInt $descriptionCount),
    $(Get-SafeInt $relationshipCount),
    $(Get-SafeInt $langrefsetCount)
)
"@
    
    Write-Host "  Inserting snomed_updates..." -NoNewline
    if (Invoke-AzureSql -ConnectionString $connectionString -Query $snomedQuery) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
    
    # Insert steps
    if ($snomed.Steps) {
        $stepOrder = 0
        foreach ($step in $snomed.Steps) {
            $stepOrder++
            $stepDurationSec = if ($step.Duration) {
                try { [int][timespan]::Parse("00:$($step.Duration)").TotalSeconds } catch { 0 }
            } else { 0 }
            
            $stepQuery = @"
INSERT INTO update_steps (
    run_id, terminology_type, step_name, step_order, success, details, duration_seconds, duration_formatted
) VALUES (
    '$RunId', 'SNOMED', $(Get-SafeString $step.Name 100), $stepOrder,
    $(Get-SafeBit $step.Success), $(Get-SafeString $step.Details 500),
    $stepDurationSec, $(Get-SafeString $step.Duration 10)
)
"@
            Invoke-AzureSql -ConnectionString $connectionString -Query $stepQuery | Out-Null
        }
        Write-Host "  Inserted $stepOrder SNOMED steps" -ForegroundColor Gray
    }
}

#endregion

#region Insert dmd_updates record

if ($Results.DMD) {
    $dmd = $Results.DMD
    
    # Get table counts
    $vtmCount = $dmd.TableCounts?["vtm"] ?? $dmd.VtmCount
    $vmpCount = $dmd.TableCounts?["vmp"] ?? $dmd.VmpCount
    $ampCount = $dmd.TableCounts?["amp"] ?? $dmd.AmpCount
    $vmppCount = $dmd.TableCounts?["vmpp"] ?? $dmd.VmppCount
    $amppCount = $dmd.TableCounts?["ampp"] ?? $dmd.AmppCount
    $ingredientCount = $dmd.TableCounts?["ingredient"] ?? $dmd.IngredientCount
    $lookupCount = $dmd.TableCounts?["lookup"] ?? $dmd.LookupCount
    
    # Get change deltas
    $vtmChange = $dmd.TableChanges?["vtm"] ?? $dmd.VtmChange
    $vmpChange = $dmd.TableChanges?["vmp"] ?? $dmd.VmpChange
    $ampChange = $dmd.TableChanges?["amp"] ?? $dmd.AmpChange
    $vmppChange = $dmd.TableChanges?["vmpp"] ?? $dmd.VmppChange
    $amppChange = $dmd.TableChanges?["ampp"] ?? $dmd.AmppChange
    
    $dmdQuery = @"
INSERT INTO dmd_updates (
    run_id, success, new_release, release_version,
    vtm_count, vmp_count, amp_count, vmpp_count, ampp_count, ingredient_count, lookup_count,
    vtm_change, vmp_change, amp_change, vmpp_change, ampp_change,
    xml_validation_rate, snomed_validation_rate
) VALUES (
    '$RunId',
    $(Get-SafeBit $dmd.Success),
    $(Get-SafeBit $dmd.NewRelease),
    $(Get-SafeString $dmd.ReleaseVersion 100),
    $(Get-SafeInt $vtmCount), $(Get-SafeInt $vmpCount), $(Get-SafeInt $ampCount),
    $(Get-SafeInt $vmppCount), $(Get-SafeInt $amppCount), $(Get-SafeInt $ingredientCount), $(Get-SafeInt $lookupCount),
    $(Get-SafeInt $vtmChange), $(Get-SafeInt $vmpChange), $(Get-SafeInt $ampChange),
    $(Get-SafeInt $vmppChange), $(Get-SafeInt $amppChange),
    $(Get-SafeDecimal $dmd.ValidationRate), $(Get-SafeDecimal $dmd.SnomedValidationRate)
)
"@
    
    Write-Host "  Inserting dmd_updates..." -NoNewline
    if (Invoke-AzureSql -ConnectionString $connectionString -Query $dmdQuery) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
    
    # Insert steps
    if ($dmd.Steps) {
        $stepOrder = 0
        foreach ($step in $dmd.Steps) {
            $stepOrder++
            $stepDurationSec = if ($step.Duration) {
                try { [int][timespan]::Parse("00:$($step.Duration)").TotalSeconds } catch { 0 }
            } else { 0 }
            
            $stepQuery = @"
INSERT INTO update_steps (
    run_id, terminology_type, step_name, step_order, success, details, duration_seconds, duration_formatted
) VALUES (
    '$RunId', 'DMD', $(Get-SafeString $step.Name 100), $stepOrder,
    $(Get-SafeBit $step.Success), $(Get-SafeString $step.Details 500),
    $stepDurationSec, $(Get-SafeString $step.Duration 10)
)
"@
            Invoke-AzureSql -ConnectionString $connectionString -Query $stepQuery | Out-Null
        }
        Write-Host "  Inserted $stepOrder DMD steps" -ForegroundColor Gray
    }
}

#endregion

#region Insert errors

if ($Results.Errors -and $Results.Errors.Count -gt 0) {
    Write-Host "  Inserting $($Results.Errors.Count) error(s)..." -NoNewline
    foreach ($error in $Results.Errors) {
        $errorQuery = @"
INSERT INTO update_errors (run_id, error_source, error_message)
VALUES ('$RunId', 'Weekly Update', $(Get-SafeString $error 4000))
"@
        Invoke-AzureSql -ConnectionString $connectionString -Query $errorQuery | Out-Null
    }
    Write-Host " OK" -ForegroundColor Green
}

#endregion

Write-Host ""
Write-Host "✅ Export complete. Run ID: $RunId" -ForegroundColor Green
Write-Host ""

return @{
    Success = $true
    RunId   = $RunId
}

#endregion
