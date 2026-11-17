#Requires -Version 7.5
<#
.SYNOPSIS
    Save a public weekly report locally and publish it through GitHub Actions.
.DESCRIPTION
    Replay an existing private results file with -ReplayPath. This never imports
    terminology or sends email. -WhatIf performs no file writes or network calls.
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='Results')]
param(
    [Parameter(Mandatory, ParameterSetName='Results')][System.Collections.IDictionary]$Results,
    [Parameter(Mandatory, ParameterSetName='Replay')][string]$ReplayPath,
    [string]$ConfigPath = "$PSScriptRoot/Config/TerminologyConfig.json",
    [switch]$SaveOnly
)
$ErrorActionPreference = 'Stop'
if ($WhatIfPreference) { return @{Success=$true; Preview=$true} }
Import-Module "$PSScriptRoot/Reporting/TerminologyPublicReport.psm1" -Force
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if (-not $config.githubReporting.enabled) { return @{Success=$true; Skipped=$true} }
if ($ReplayPath) { $Results = Get-Content -LiteralPath $ReplayPath -Raw | ConvertFrom-Json -AsHashtable -DateKind String }
$run = ConvertTo-PublicTerminologyRun -Results $Results
$directory = Join-Path $config.paths.logsBase 'GitHubReports'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
# Private results support a faithful replay; they are never added to GitHub.
$savedPath = Join-Path $directory "$($run.runId).results.json"
$publicPath = Join-Path $directory "$($run.runId).public.json"
$Results | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath "$savedPath.tmp" -Encoding utf8
Move-Item -LiteralPath "$savedPath.tmp" -Destination $savedPath -Force
$run | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $publicPath -Encoding utf8
if ($SaveOnly) { return @{Success=$true; SavedPath=$savedPath; RunId=$run.runId} }
try {
    $published = Publish-TerminologyRun -Run $run -Repository $config.githubReporting.repository -Branch $config.githubReporting.branch
    $published | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $directory "$($run.runId).published.json") -Encoding utf8
    return $published
} catch {
    Write-Warning "Report retained for publish-only replay: $savedPath"
    throw
}
