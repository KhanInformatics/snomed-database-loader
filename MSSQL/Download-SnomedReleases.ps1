# Save this as Download-SnomedReleases.ps1

# Import the CredentialManager module (ensure it's installed)
Import-Module CredentialManager

# Get the base directory where the logs and releases are stored.
$baseDir = "C:\SNOMEDCT"
Write-Host "Script base directory: $baseDir"

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

# Define the SNOMED CT items you want to download.
# - Monolith: Item number 1799
# - UK Primary Care: Item number 659
$items = @(
    @{ Name = "SnomedCT_Monolith"; ItemNumber = "1799" },
    @{ Name = "SnomedCT_UKPrimaryCare"; ItemNumber = "659" }
)

# Base API URL for TRUD
$baseApiUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$apiKey/items"

# Define download and output locations
$downloadDir = "C:\SNOMEDCT\Downloads"
$currentReleasesDir = Join-Path $baseDir "CurrentReleases"

# Ensure download folder exists
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir | Out-Null
}

# Ensure CurrentReleases folder exists and is emptied
if (Test-Path $currentReleasesDir) {
    Write-Host "Cleaning up CurrentReleases folder: $currentReleasesDir"
    Get-ChildItem -Path $currentReleasesDir -Recurse -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $currentReleasesDir | Out-Null
}
Write-Host "Ready to receive new releases in: $currentReleasesDir"

foreach ($item in $items) {
    $itemNumber = $item.ItemNumber
    $itemName = $item.Name

    # Construct the TRUD API URL to get the latest release for the item.
    $url = "$baseApiUrl/$itemNumber/releases?latest"
    Write-Host "Querying TRUD API for ${itemName} (item number ${itemNumber})..."
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    } catch {
        Write-Error "Error retrieving release for ${itemName}: $($_.Exception.Message)"
        continue
    }
    
    if ($response.releases.Count -eq 0) {
        Write-Host "No releases found for ${itemName}."
        continue
    }
    
    # Get latest release details
    $release = $response.releases[0]
    $releaseUrl = $release.archiveFileUrl
    $releaseFileName = $release.archiveFileName
    Write-Host "Latest release for ${itemName}: $($release.name) released on $($release.releaseDate)"
    Write-Host "Downloading ${releaseFileName} from ${releaseUrl}..."

    # Download the release file
    $localFilePath = Join-Path $downloadDir $releaseFileName
    try {
        Invoke-WebRequest -Uri $releaseUrl -OutFile $localFilePath -ErrorAction Stop
    } catch {
        Write-Error "Error downloading ${releaseFileName}: $($_.Exception.Message)"
        continue
    }
    Write-Host "Downloaded file saved to: $localFilePath"

    # Unzip to a temporary extract folder
    $unzipFolderName = [IO.Path]::GetFileNameWithoutExtension($releaseFileName)
    $extractDir = Join-Path $downloadDir $unzipFolderName

    Write-Host "Unzipping $localFilePath to $extractDir..."
    try {
        Expand-Archive -Path $localFilePath -DestinationPath $extractDir -Force
        Write-Host "Unzip complete."
    } catch {
        Write-Error "Error unzipping ${localFilePath}: $($_.Exception.Message)"
        continue
    }

    # Delete the original ZIP file
    Write-Host "Deleting ZIP file: $localFilePath"
    Remove-Item $localFilePath -Force

    # Move the extracted folder into CurrentReleases
    $destinationDir = Join-Path $currentReleasesDir $unzipFolderName
    Write-Host "Moving $extractDir to $destinationDir..."
    try {
        if (Test-Path $destinationDir) {
            Remove-Item $destinationDir -Recurse -Force
        }
        Move-Item -Path $extractDir -Destination $destinationDir
        Write-Host "Moved to: $destinationDir"
    } catch {
        Write-Error "Error moving folder: $($_.Exception.Message)"
    }
}

Write-Host "`n✅ All SNOMED CT releases downloaded, extracted, and moved to CurrentReleases."
