# Check for New Data Migration Workbench Releases from TRUD
# Save this as Check-NewDMWBRelease.ps1

# Import the CredentialManager module (ensure it's installed)
Import-Module CredentialManager

# Retrieve the TRUD API key from Credential Manager (target: TRUD_API)
$credential = Get-StoredCredential -Target "TRUD_API"
if (-not $credential) {
    Write-Error "TRUD_API credential not found. Please store your API key in Credential Manager under the target 'TRUD_API'."
    exit
}

# Convert the SecureString API key to plain text
$apiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
)

if (-not $apiKey) {
    Write-Error "API key is empty. Please verify your stored credential."
    exit
}

# Define the Data Migration Workbench item to check
# Item 98: NHS Data Migration Workbench
$items = @(
    @{ Name = "NHS Data Migration Workbench"; ItemNumber = "98" }
)

# Base API URL for TRUD
$baseApiUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$apiKey/items"

# Check for release tracking file
$releaseTrackingFile = "C:\DMWB\last_checked_releases.json"
$lastCheckedReleases = @{}

if (Test-Path $releaseTrackingFile) {
    try {
        $lastCheckedReleases = Get-Content $releaseTrackingFile | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warning "Could not read release tracking file. Will treat all releases as new."
        $lastCheckedReleases = @{}
    }
}

$newReleasesFound = $false
$allReleaseInfo = @{}

Write-Host "=== Data Migration Workbench Release Check - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ForegroundColor Cyan

foreach ($item in $items) {
    $itemNumber = $item.ItemNumber
    $itemName = $item.Name

    Write-Host "`nChecking ${itemName} (Item: ${itemNumber})..." -ForegroundColor Yellow
    
    # Construct the TRUD API URL to get the latest release for the item
    $url = "$baseApiUrl/$itemNumber/releases?latest"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    } catch {
        Write-Error "Error retrieving release information for ${itemName}: $($_.Exception.Message)"
        continue
    }
    
    if ($response.releases.Count -eq 0) {
        Write-Host "  No releases found for ${itemName}" -ForegroundColor Red
        continue
    }
    
    # Get latest release details
    $release = $response.releases[0]
    $releaseDate = [DateTime]::Parse($release.releaseDate)
    $releaseName = $release.name
    $releaseId = $release.id
    
    # Store current release info
    $allReleaseInfo[$itemNumber] = @{
        "id" = $releaseId
        "name" = $releaseName
        "releaseDate" = $releaseDate.ToString("yyyy-MM-dd")
        "itemName" = $itemName
    }
    
    Write-Host "  Latest Release: $releaseName" -ForegroundColor Green
    Write-Host "  Release Date: $($releaseDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
    Write-Host "  File: $($release.archiveFileName)" -ForegroundColor Green
    
    # Check if this is a new release
    $isNewRelease = $false
    if ($lastCheckedReleases.ContainsKey($itemNumber)) {
        $lastReleaseId = $lastCheckedReleases[$itemNumber].id
        if ($releaseId -ne $lastReleaseId) {
            $isNewRelease = $true
        }
    } else {
        # First time checking - consider it new
        $isNewRelease = $true
    }
    
    if ($isNewRelease) {
        Write-Host "  ⭐ NEW RELEASE DETECTED!" -ForegroundColor Magenta
        $newReleasesFound = $true
        
        if ($lastCheckedReleases.ContainsKey($itemNumber)) {
            $lastRelease = $lastCheckedReleases[$itemNumber]
            Write-Host "  Previous Release: $($lastRelease.name)" -ForegroundColor Gray
            Write-Host "  Previous Date: $($lastRelease.releaseDate)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No new release (same as last check)" -ForegroundColor Gray
    }
}

# Update the tracking file with current release information
$allReleaseInfo | ConvertTo-Json | Set-Content $releaseTrackingFile
Write-Host "`nRelease tracking information updated: $releaseTrackingFile" -ForegroundColor Cyan

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($newReleasesFound) {
    Write-Host "New releases are available! Run Download-DMWBReleases.ps1 to download them." -ForegroundColor Green
} else {
    Write-Host "No new releases detected. You have the latest version." -ForegroundColor Yellow
}

Write-Host "`nDone." -ForegroundColor Cyan
