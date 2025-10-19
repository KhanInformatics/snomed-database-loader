# Check for New DM+D Releases from TRUD
# Save this as Check-NewDMDRelease.ps1

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

# Define the DM+D items to check
$items = @(
    @{ Name = "NHSBSA dm+d (Main)"; ItemNumber = "105" },
    @{ Name = "NHSBSA dm+d (Supplementary)"; ItemNumber = "108" }
)

# Base API URL for TRUD
$baseApiUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$apiKey/items"

# Check for release tracking file
$releaseTrackingFile = "C:\DMD\last_checked_releases.json"
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

Write-Host "=== DM+D Release Check - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ForegroundColor Cyan

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
        # First time checking this item
        $isNewRelease = $true
    }
    
    if ($isNewRelease) {
        Write-Host "  ⚡ NEW RELEASE DETECTED!" -ForegroundColor Magenta
        $newReleasesFound = $true
        
        if ($lastCheckedReleases.ContainsKey($itemNumber)) {
            $lastDate = [DateTime]::Parse($lastCheckedReleases[$itemNumber].releaseDate)
            Write-Host "  Previous Release Date: $($lastDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
        } else {
            Write-Host "  This is the first time checking this item" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No new release (already checked)" -ForegroundColor Gray
    }
}

# Save the current release information for next check
$dmdDir = "C:\DMD"
if (-not (Test-Path $dmdDir)) {
    New-Item -ItemType Directory -Path $dmdDir | Out-Null
}

$allReleaseInfo | ConvertTo-Json -Depth 3 | Set-Content $releaseTrackingFile

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($newReleasesFound) {
    Write-Host "🔄 New DM+D releases are available!" -ForegroundColor Green
    Write-Host "Run Download-DMDReleases.ps1 to download the latest releases." -ForegroundColor Yellow
    
    # Check next release schedule  
    Write-Host "`n📅 DM+D Release Schedule:" -ForegroundColor Cyan
    Write-Host "  • Main dm+d releases: Weekly (typically Monday 4:00 AM)" -ForegroundColor White
    Write-Host "  • Next scheduled release: Monday $(Get-Date (Get-Date).AddDays(8 - [int](Get-Date).DayOfWeek) -Format 'yyyy-MM-dd') at 4:00 AM" -ForegroundColor White
} else {
    Write-Host "✅ No new releases found. All checked items are up to date." -ForegroundColor Green
}

Write-Host "`n💡 Tip: You can automate this check by scheduling this script to run daily." -ForegroundColor Cyan