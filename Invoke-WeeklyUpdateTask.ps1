#Requires -Version 7.5
[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot/Config/TerminologyConfig.json",
    [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not $CheckOnly) {
    # A GitHub outage must not prevent imports or saving a report for replay.
    & "$PSScriptRoot/Weekly-TerminologyUpdate.ps1" -ConfigPath $ConfigPath
    return
}
$config=Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$logPath=Join-Path $config.paths.logsBase 'WeeklyTaskPreflight.json'
try {
    if ($config.githubReporting.enabled) {
        $ghResult = & gh api "repos/$($config.githubReporting.repository)" --jq '.permissions.push' 2>$null
        if ($LASTEXITCODE -ne 0 -or $ghResult -ne 'true') { throw 'Scheduled account cannot publish reports to GitHub.' }
    }
    Import-Module CredentialManager -ErrorAction Stop
    if (-not (Get-StoredCredential -Target $config.credentials.trudApiTarget)) { throw 'Scheduled account cannot read the TRUD credential.' }
    Import-Module SqlServer -ErrorAction Stop
    Invoke-Sqlcmd -ServerInstance $config.database.serverInstance -Database $config.database.snomedDatabase -Query 'SELECT 1 AS Connected' -TrustServerCertificate -ConnectionTimeout 15 -ErrorAction Stop | Out-Null
    @{Success=$true;CheckedAt=[datetimeoffset]::UtcNow.ToString('o');Account=[Security.Principal.WindowsIdentity]::GetCurrent().Name;CheckOnly=[bool]$CheckOnly} | ConvertTo-Json | Set-Content -LiteralPath $logPath
} catch {
    @{Success=$false;CheckedAt=[datetimeoffset]::UtcNow.ToString('o');Account=[Security.Principal.WindowsIdentity]::GetCurrent().Name;Error=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath $logPath
    throw
}
