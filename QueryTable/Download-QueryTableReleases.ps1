# Download SNOMED CT UK Query Table and History Substitution Table from TRUD
# TRUD Item 1805 - Contains enhanced transitive closure with inactive concept handling
# Recommended by JGPIT for primary care systems

# Import the CredentialManager module (ensure it's installed)
Import-Module CredentialManager

# Get the base directory where the logs and releases are stored
$baseDir = "C:\QueryTable"
Write-Host "Script base directory: $baseDir" -ForegroundColor Cyan

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

# Define the Query Table item to download
# Item number 276: SNOMED CT UK Query Table and History Substitution Table
$items = @(
    @{ Name = "UK_SCTQTHS"; ItemNumber = "276" }
)

# Base API URL for TRUD
$baseApiUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$apiKey/items"

# Define download and output locations
$downloadDir = Join-Path $baseDir "Downloads"
$currentReleasesDir = Join-Path $baseDir "CurrentReleases"

# Ensure base directory exists
if (-not (Test-Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir | Out-Null
    Write-Host "Created base directory: $baseDir"
}

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

    # Construct the TRUD API URL to get the latest release for the item
    $url = "$baseApiUrl/$itemNumber/releases?latest"
    Write-Host "`nQuerying TRUD API for ${itemName} (TRUD Item ${itemNumber})..." -ForegroundColor Yellow
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
    $releaseName = $release.name
    $releaseDate = $release.releaseDate
    
    Write-Host "Latest release: $releaseName" -ForegroundColor Green
    Write-Host "Release date: $releaseDate"
    Write-Host "Archive: $releaseFileName"
    Write-Host "`nDownloading from: $releaseUrl"

    # Download the release file
    $localFilePath = Join-Path $downloadDir $releaseFileName
    try {
        $ProgressPreference = 'SilentlyContinue'  # Speeds up download
        Invoke-WebRequest -Uri $releaseUrl -OutFile $localFilePath -ErrorAction Stop
        $ProgressPreference = 'Continue'
    } catch {
        Write-Error "Error downloading ${releaseFileName}: $($_.Exception.Message)"
        continue
    }
    
    $fileSize = (Get-Item $localFilePath).Length / 1MB
    Write-Host "Downloaded: $localFilePath ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green

    # Unzip to a temporary extract folder
    $unzipFolderName = [IO.Path]::GetFileNameWithoutExtension($releaseFileName)
    $extractDir = Join-Path $downloadDir $unzipFolderName

    Write-Host "`nExtracting archive..."
    try {
        Expand-Archive -Path $localFilePath -DestinationPath $extractDir -Force
        Write-Host "Extraction complete." -ForegroundColor Green
    } catch {
        Write-Error "Error unzipping ${localFilePath}: $($_.Exception.Message)"
        continue
    }

    # Delete the original ZIP file
    Write-Host "Cleaning up ZIP file..."
    Remove-Item $localFilePath -Force

    # Move the extracted folder into CurrentReleases
    $destinationDir = Join-Path $currentReleasesDir $unzipFolderName
    Write-Host "Moving to: $destinationDir"
    try {
        if (Test-Path $destinationDir) {
            Remove-Item $destinationDir -Recurse -Force
        }
        Move-Item -Path $extractDir -Destination $destinationDir
        Write-Host "Complete!" -ForegroundColor Green
    } catch {
        Write-Error "Error moving folder: $($_.Exception.Message)"
    }
    
    # List the contents
    Write-Host "`n=== Downloaded Files ===" -ForegroundColor Cyan
    Get-ChildItem -Path $destinationDir -Recurse -File | ForEach-Object {
        $relPath = $_.FullName.Replace($destinationDir, "").TrimStart("\")
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $relPath ($size MB)"
    }
}

Write-Host "`n=== Download Complete ===" -ForegroundColor Green
Write-Host "Query Table files are in: $currentReleasesDir"
Write-Host "`nContents:"
Write-Host "  - Query Table (SCTQT): Enhanced transitive closure with inactive concept handling"
Write-Host "  - History Substitution Table (SCTHS): Inactive to active concept mappings"
