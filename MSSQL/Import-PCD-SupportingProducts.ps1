<#
.SYNOPSIS
    Loads both current Primary Care Domain supporting products.

.DESCRIPTION
    Invokes the lossless canonical loader once for GPData and once for GDPPR.
    Each product retains its own atomic table swap and validation. The wrapper
    returns one structured result so the weekly orchestrator can report both
    products as a single step.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "PCD",
    [string]$ReleasesPath = "C:\SNOMEDCT\CurrentReleases",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$productLoader = Join-Path $scriptDir "Import-PCD-GPData.ps1"

if (-not (Test-Path -LiteralPath $productLoader -PathType Leaf)) {
    throw "Canonical PCD product loader not found: $productLoader"
}

$productResults = @()
foreach ($productCode in @("GPData", "GDPPR")) {
    $loaderParameters = @{
        ServerInstance = $ServerInstance
        DatabaseName   = $DatabaseName
        ReleasesPath   = $ReleasesPath
        ProductCode    = $productCode
        Force          = [bool]$Force
        WhatIf         = [bool]$WhatIfPreference
    }

    $productResult = & $productLoader @loaderParameters
    if (-not $productResult -or -not [bool]$productResult.Success) {
        throw "$productCode canonical loader did not return a successful result"
    }

    $productResults += $productResult
}

return [pscustomobject]@{
    Success  = $true
    Planned  = [bool]$WhatIfPreference
    Products = @($productResults)
}
