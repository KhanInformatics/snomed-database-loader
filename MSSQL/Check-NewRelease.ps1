# Import the CredentialManager module
Import-Module CredentialManager

# ---- Determine the script’s own folder, no matter where it's launched from ----
$scriptDir = $PSScriptRoot
# (Alternative if you ever need compatibility with older PS versions:
#  $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
# )

Write-Host "Script folder: $scriptDir"

# Retrieve the TRUD API key…
$credential = Get-StoredCredential -Target "TRUD_API"
…    

# Point the JSON cache at the script’s folder
$lastReleaseFile = Join-Path $scriptDir "LastRelease.json"
Write-Host "Using JSON cache: $lastReleaseFile"

# … your existing load/compare logic …

if ($newReleaseFound) {
    Write-Host "New release(s) detected. Initiating download and import."

    # Look for the other scripts right next to this one:
    $downloadScript = Join-Path $scriptDir "Download-SnomedReleases.ps1"
    $importScript   = Join-Path $scriptDir "Generate-AndRun-AllSnapshots.ps1"

    if (Test-Path $downloadScript) {
        Write-Host "Running $downloadScript"
        & $downloadScript
    } else {
        Write-Error "Cannot find: $downloadScript"
    }

    if (Test-Path $importScript) {
        Write-Host "Running $importScript"
        & $importScript
    } else {
        Write-Error "Cannot find: $importScript"
    }
} else {
    Write-Host "No new releases detected."
}
