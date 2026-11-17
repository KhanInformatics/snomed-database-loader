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

.PARAMETER ConnectionTestOnly
    Tests the configured Azure SQL connection with SELECT 1 without exporting a report.

.EXAMPLE
    .\Export-ReportToAzure.ps1 -Results $results -ConfigPath .\Config\TerminologyConfig.json

.EXAMPLE
    .\Export-ReportToAzure.ps1 -ConnectionTestOnly -ConfigPath .\Config\TerminologyConfig.json

.NOTES
    Requires: SqlServer and CredentialManager modules, configured stored SQL credentials
    Target: azuresnnomedct.database.windows.net / ReportingServer
#>

[CmdletBinding(DefaultParameterSetName = "Export")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Export")]
    [hashtable]$Results,
    
    [string]$ConfigPath = ".\Config\TerminologyConfig.json",
    
    [Parameter(ParameterSetName = "Export")]
    [guid]$RunId = [guid]::NewGuid(),

    [Parameter(Mandatory = $true, ParameterSetName = "ConnectionTest")]
    [switch]$ConnectionTestOnly
)

$ErrorActionPreference = "Stop"
$connectionTestMode = $PSCmdlet.ParameterSetName -eq "ConnectionTest"

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

function Get-RedactedErrorMessage {
    param([System.Exception]$Exception)

    $message = if ($Exception) { $Exception.Message } else { "Unknown Azure SQL error" }

    # A provider exception can occasionally include part of a connection string.
    # Never allow credentials from that string to reach the transcript or report.
    return $message -replace '(?i)(Password|Pwd|User ID|UID|Access Token)\s*=\s*[^;]*', '$1=<redacted>'
}

function Get-AzureSqlFirewallDenial {
    param([System.Exception]$Exception)

    $denied = $false
    $clientIp = $null
    $serverName = $null
    for ($current = $Exception; $null -ne $current; $current = $current.InnerException) {
        $safeMessage = Get-RedactedErrorMessage -Exception $current
        if ($current.PSObject.Properties["Number"] -and $current.Number -eq 40615) {
            $denied = $true
        }
        if ($safeMessage -match "Client with IP address '(?<ip>[^']+)' is not allowed to access the server") {
            $denied = $true
            $clientIp = $Matches.ip
        }
        if ($safeMessage -match "Cannot open server '(?<server>[^']+)' requested by the login") {
            $serverName = $Matches.server
        }
    }

    if ($denied) {
        return [pscustomobject]@{ ClientIp = $clientIp; ServerName = $serverName }
    }
}

function Invoke-AzureSql {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [string]$Query,
        [string]$Operation = "Azure SQL statement",
        [ValidateRange(0, 100)]
        [int]$MaxRetries = 0,
        [ValidateRange(0, 86400)]
        [int]$RetryDelaySeconds = 0
    )

    $totalAttempts = $MaxRetries + 1

    for ($attempt = 1; $attempt -le $totalAttempts; $attempt++) {
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query -ErrorAction Stop | Out-Null
            return
        }
        catch {
            $safeMessage = Get-RedactedErrorMessage -Exception $_.Exception
            $firewallDenial = Get-AzureSqlFirewallDenial -Exception $_.Exception

            # A rejected client IP requires a firewall change, not unchanged retries.
            # Keep automatic retries for transient availability failures below.
            if ($firewallDenial) {
                $client = if ($firewallDenial.ClientIp) { "client IP '$($firewallDenial.ClientIp)'" } else { "this client's public outbound IP" }
                $server = if ($firewallDenial.ServerName) { "server '$($firewallDenial.ServerName)'" } else { "the configured Azure SQL server" }
                $guidance = "Azure SQL firewall denied $client on $server. Confirm the update host's current outbound IP and allow that single IP in the server's Networking firewall rules. After propagation, run Export-ReportToAzure.ps1 -ConnectionTestOnly with the same configuration and Windows account. No automatic retry was attempted for this firewall denial."
                throw [System.InvalidOperationException]::new("$Operation failed on attempt $attempt`: $guidance $safeMessage", $_.Exception)
            }

            if ($attempt -ge $totalAttempts) {
                $failureMessage = "$Operation failed after $attempt attempt(s): $safeMessage"
                throw [System.InvalidOperationException]::new($failureMessage, $_.Exception)
            }

            Write-Warning "$Operation failed on attempt $attempt of $totalAttempts`: $safeMessage"
            Write-Warning "Retrying in $RetryDelaySeconds second(s)..."

            if ($RetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
}

#endregion

#region Main Script

Write-Host ""
if ($connectionTestMode) {
    Write-Host "Testing Azure SQL Reporting Database connection..." -ForegroundColor Cyan
} else {
    Write-Host "Exporting results to Azure SQL Reporting Database..." -ForegroundColor Cyan
}

# Load configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $scriptDir "Config\TerminologyConfig.json"
}

if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# The configured value is the number of retries after the initial attempt.
# Keeping delay/count as explicit function parameters allows callers/tests to use zero-delay retries.
$maxRetries = 0
$retryDelaySeconds = 0
if ($config.options -and [bool]$config.options.retryOnFailure) {
    if ($null -ne $config.options.maxRetries) {
        $maxRetries = [Math]::Max(0, [int]$config.options.maxRetries)
    }
    if ($null -ne $config.options.retryDelaySeconds) {
        $retryDelaySeconds = [Math]::Max(0, [int]$config.options.retryDelaySeconds)
    }
}

$connectionRetryParameters = @{
    MaxRetries       = $maxRetries
    RetryDelaySeconds = $retryDelaySeconds
}

# INSERT retries are unsafe without a shared transaction: the server may commit
# before a lost acknowledgement, and retrying would duplicate identity-keyed
# child rows. Fail writes immediately and let the next report use a fresh RunId.
$writeParameters = @{
    MaxRetries        = 0
    RetryDelaySeconds = 0
}

# Get Azure SQL connection string
if (-not $config.azureReporting) {
    throw "Azure reporting configuration not found in config file"
}

$azureReporting = $config.azureReporting

if (-not $azureReporting.sqlCredentialTarget) {
    throw "azureReporting.sqlCredentialTarget must be set in config (Windows Credential Manager target name)"
}

Import-Module CredentialManager -ErrorAction Stop
$sqlCred = Get-StoredCredential -Target $azureReporting.sqlCredentialTarget
if (-not $sqlCred) {
    throw "Azure SQL credentials not found in Credential Manager: $($azureReporting.sqlCredentialTarget)"
}

$sqlUser = $sqlCred.UserName
$sqlPassword = $sqlCred.GetNetworkCredential().Password
$connectionTimeout = if ($azureReporting.connectionTimeout) { $azureReporting.connectionTimeout } else { 240 }

$connectionString = "Server=tcp:$($azureReporting.server),1433;Initial Catalog=$($azureReporting.database);User ID=$sqlUser;Password=$sqlPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=$connectionTimeout;"

Write-Host "  Target: $($config.azureReporting.server)/$($config.azureReporting.database)" -ForegroundColor Gray

$runRecordInserted = $false
try {
# Test connection, including configured retries for transient availability failures.
Invoke-AzureSql -ConnectionString $connectionString -Query "SELECT 1" `
    -Operation "Azure SQL connection test" @connectionRetryParameters
Write-Host "  Connection: OK" -ForegroundColor Green

if ($connectionTestMode) {
    return @{
        Success = $true
        ConnectionTestOnly = $true
        Server = $azureReporting.server
        Database = $azureReporting.database
    }
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
    0,
    $(Get-SafeInt $Results.UpdatesFound),
    $(Get-SafeString $env:COMPUTERNAME 255),
    $(Get-SafeString $Results.LogFile 500),
    $(Get-SafeString $ConfigPath 500),
    $(Get-SafeBit $Results.WhatIf),
    $(Get-SafeBit $Results.Force)
)
"@

Write-Host "  Inserting update_runs..." -NoNewline
Invoke-AzureSql -ConnectionString $connectionString -Query $updateRunsQuery `
    -Operation "Insert update_runs" @writeParameters
$runRecordInserted = $true
Write-Host " OK" -ForegroundColor Green

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
    Invoke-AzureSql -ConnectionString $connectionString -Query $snomedQuery `
        -Operation "Insert snomed_updates" @writeParameters
    Write-Host " OK" -ForegroundColor Green
    
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
            Invoke-AzureSql -ConnectionString $connectionString -Query $stepQuery `
                -Operation "Insert SNOMED step $stepOrder" @writeParameters
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
    Invoke-AzureSql -ConnectionString $connectionString -Query $dmdQuery `
        -Operation "Insert dmd_updates" @writeParameters
    Write-Host " OK" -ForegroundColor Green
    
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
            Invoke-AzureSql -ConnectionString $connectionString -Query $stepQuery `
                -Operation "Insert DMD step $stepOrder" @writeParameters
        }
        Write-Host "  Inserted $stepOrder DMD steps" -ForegroundColor Gray
    }
}

#endregion

#region Insert dmwb_updates record

if ($Results.DMWB) {
    $dmwb = $Results.DMWB
    
    $totalTables = if ($dmwb.TableCounts) { $dmwb.TableCounts.Count } else { 0 }
    $totalRecords = if ($dmwb.TableCounts) { ($dmwb.TableCounts.Values | Measure-Object -Sum).Sum } else { 0 }
    
    $dmwbQuery = @"
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'dmwb_updates')
BEGIN
    CREATE TABLE dmwb_updates (
        id INT IDENTITY(1,1) PRIMARY KEY,
        run_id UNIQUEIDENTIFIER NOT NULL,
        success BIT NOT NULL DEFAULT 0,
        new_release BIT NOT NULL DEFAULT 0,
        release_version NVARCHAR(200),
        release_date NVARCHAR(50),
        release_name NVARCHAR(500),
        total_tables INT,
        total_records INT,
        created_at DATETIME DEFAULT GETDATE()
    )
END;
INSERT INTO dmwb_updates (
    run_id, success, new_release, release_version, release_date, release_name,
    total_tables, total_records
) VALUES (
    '$RunId',
    $(Get-SafeBit $dmwb.Success),
    $(Get-SafeBit $dmwb.NewRelease),
    $(Get-SafeString $dmwb.ReleaseVersion 200),
    $(Get-SafeString $dmwb.ReleaseDate 50),
    $(Get-SafeString $dmwb.ReleaseName 500),
    $(Get-SafeInt $totalTables),
    $(Get-SafeInt $totalRecords)
)
"@
    
    Write-Host "  Inserting dmwb_updates..." -NoNewline
    Invoke-AzureSql -ConnectionString $connectionString -Query $dmwbQuery `
        -Operation "Insert dmwb_updates" @writeParameters
    Write-Host " OK" -ForegroundColor Green
    
    # Insert steps
    if ($dmwb.Steps) {
        $stepOrder = 0
        foreach ($step in $dmwb.Steps) {
            $stepOrder++
            $stepDurationSec = if ($step.Duration) {
                try { [int][timespan]::Parse("00:$($step.Duration)").TotalSeconds } catch { 0 }
            } else { 0 }
            
            $stepQuery = @"
INSERT INTO update_steps (
    run_id, terminology_type, step_name, step_order, success, details, duration_seconds, duration_formatted
) VALUES (
    '$RunId', 'DMWB', $(Get-SafeString $step.Name 100), $stepOrder,
    $(Get-SafeBit $step.Success), $(Get-SafeString $step.Details 500),
    $stepDurationSec, $(Get-SafeString $step.Duration 10)
)
"@
            Invoke-AzureSql -ConnectionString $connectionString -Query $stepQuery `
                -Operation "Insert DMWB step $stepOrder" @writeParameters
        }
        Write-Host "  Inserted $stepOrder DMWB steps" -ForegroundColor Gray
    }
}

#endregion

#region Insert pcd_validations record

if ($Results.PCD) {
    $pcd = $Results.PCD
    
    $pcdQuery = @"
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'pcd_validations')
BEGIN
    CREATE TABLE pcd_validations (
        id INT IDENTITY(1,1) PRIMARY KEY,
        run_id UNIQUEIDENTIFIER NOT NULL,
        success BIT NOT NULL DEFAULT 0,
        tables_checked INT,
        tables_passed INT,
        validation_rate DECIMAL(5,2),
        created_at DATETIME DEFAULT GETDATE()
    )
END;
INSERT INTO pcd_validations (
    run_id, success, tables_checked, tables_passed, validation_rate
) VALUES (
    '$RunId',
    $(Get-SafeBit $pcd.Success),
    $(Get-SafeInt $pcd.TablesChecked),
    $(Get-SafeInt $pcd.TablesPassed),
    $(Get-SafeDecimal $pcd.ValidationRate)
)
"@
    
    Write-Host "  Inserting pcd_validations..." -NoNewline
    Invoke-AzureSql -ConnectionString $connectionString -Query $pcdQuery `
        -Operation "Insert pcd_validations" @writeParameters
    Write-Host " OK" -ForegroundColor Green
    
    # Insert steps
    if ($pcd.Steps) {
        $stepOrder = 0
        foreach ($step in $pcd.Steps) {
            $stepOrder++
            $stepDurationSec = if ($step.Duration) {
                try { [int][timespan]::Parse("00:$($step.Duration)").TotalSeconds } catch { 0 }
            } else { 0 }
            
            $stepQuery = @"
INSERT INTO update_steps (
    run_id, terminology_type, step_name, step_order, success, details, duration_seconds, duration_formatted
) VALUES (
    '$RunId', 'PCD', $(Get-SafeString $step.Name 100), $stepOrder,
    $(Get-SafeBit $step.Success), $(Get-SafeString $step.Details 500),
    $stepDurationSec, $(Get-SafeString $step.Duration 10)
)
"@
            Invoke-AzureSql -ConnectionString $connectionString -Query $stepQuery `
                -Operation "Insert PCD step $stepOrder" @writeParameters
        }
        Write-Host "  Inserted $stepOrder PCD steps" -ForegroundColor Gray
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
        Invoke-AzureSql -ConnectionString $connectionString -Query $errorQuery `
            -Operation "Insert update error" @writeParameters
    }
    Write-Host " OK" -ForegroundColor Green
}

#endregion

# Publish the intended final status only after every related row is present.
# Until this succeeds, readers see a failed/incomplete run rather than a false
# positive caused by a partially exported report.
$finalizeRunQuery = "UPDATE update_runs SET success = $(Get-SafeBit $Results.Success) WHERE run_id = '$RunId';"
Invoke-AzureSql -ConnectionString $connectionString -Query $finalizeRunQuery `
    -Operation "Finalize update_runs status" @writeParameters
}
catch {
    $exportException = $_.Exception
    $safeExportError = Get-RedactedErrorMessage -Exception $exportException

    # If the parent row was committed before a later statement failed, make the
    # partial run visibly failed in Azure rather than leaving a green orphan.
    if ($runRecordInserted) {
        $markFailedQuery = @"
UPDATE update_runs SET success = 0 WHERE run_id = '$RunId';
IF OBJECT_ID('dbo.update_errors', 'U') IS NOT NULL
BEGIN
    INSERT INTO update_errors (run_id, error_source, error_message)
    VALUES ('$RunId', 'Azure export', $(Get-SafeString $safeExportError 4000));
END
"@
        try {
            Invoke-Sqlcmd -ConnectionString $connectionString -Query $markFailedQuery -ErrorAction Stop | Out-Null
        }
        catch {
            $safeCleanupError = Get-RedactedErrorMessage -Exception $_.Exception
            Write-Warning "Could not mark partial Azure report run as failed: $safeCleanupError"
        }
    }

    throw [System.InvalidOperationException]::new("Azure SQL export failed: $safeExportError", $exportException)
}
finally {
    $connectionString = $null
    $sqlPassword = $null
    $sqlCred = $null
}

Write-Host ""
Write-Host "✅ Export complete. Run ID: $RunId" -ForegroundColor Green
Write-Host ""

return @{
    Success = $true
    RunId   = $RunId
}

#endregion
