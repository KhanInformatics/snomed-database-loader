# Check for New DM+D Releases from TRUD and Automatically Import
# This script tracks IMPORTED releases (not just checked releases)
# If a new release is found, it automatically downloads and imports the data

# Get the base directory (where the script is located)
$baseDir = $PSScriptRoot

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
# Item 24: NHSBSA dm+d (Dictionary of Medicines and Devices - Main data)
# Item 25: NHSBSA dm+d BONUS (BNF and ATC codes - Supplementary data)
$items = @(
    @{ Name = "DMD_Main"; ItemNumber = "24" },
    @{ Name = "DMD_Bonus"; ItemNumber = "25" }
)

# Base API URL for TRUD
$baseApiUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$apiKey/items"

# Directory to store state and logs
$dataDir = "C:\DMD"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# File to store last IMPORTED release IDs (not just checked)
$lastImportFile = Join-Path $dataDir "LastImportedRelease.json"

# Load previous import records if they exist
$lastImportedReleases = @{}
if (Test-Path $lastImportFile) {
    $temp = Get-Content $lastImportFile -Raw | ConvertFrom-Json
    if ($temp) {
        foreach ($prop in $temp.PSObject.Properties) {
            $lastImportedReleases[$prop.Name] = $prop.Value
        }
    }
}

# Log file
$logFile = Join-Path $dataDir "CheckNewDMDRelease.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== DM+D Release Check - $timestamp ===" -ForegroundColor Cyan
"[$timestamp] Starting DM+D release check" | Out-File $logFile -Append

# Flag to indicate if any new release is found
$newReleaseFound = $false
$currentReleases = @{}

# Loop through each item and query its latest release
foreach ($item in $items) {
    $itemName = $item.Name
    $itemNumber = $item.ItemNumber
    $url = "$baseApiUrl/$itemNumber/releases?latest"
    
    Write-Host "`nChecking $itemName (Item: $itemNumber)..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    } catch {
        Write-Error "Error querying TRUD for ${itemName}: $($_.Exception.Message)"
        "[$timestamp] ERROR: Failed to query $itemName - $($_.Exception.Message)" | Out-File $logFile -Append
        continue
    }
    
    if ($response.releases.Count -eq 0) {
        Write-Host "  No releases found for $itemName" -ForegroundColor Red
        continue
    }
    
    # Use the first (latest) release from the response
    $latestRelease = $response.releases[0]
    $currentReleaseId = $latestRelease.id
    $releaseDate = $latestRelease.releaseDate
    $archiveFileName = $latestRelease.archiveFileName
    
    # Store current release info
    $currentReleases[$itemName] = $currentReleaseId
    
    Write-Host "  Latest Release: $currentReleaseId" -ForegroundColor Green
    Write-Host "  Release Date: $releaseDate" -ForegroundColor Green
    Write-Host "  File: $archiveFileName" -ForegroundColor Green
    
    # Check if we already have IMPORTED this release
    if ($lastImportedReleases.ContainsKey($itemName)) {
        if ($lastImportedReleases[$itemName] -ne $currentReleaseId) {
            Write-Host "  ⚡ NEW RELEASE - needs import!" -ForegroundColor Magenta
            Write-Host "    Previous imported: $($lastImportedReleases[$itemName])" -ForegroundColor Gray
            Write-Host "    New release: $currentReleaseId" -ForegroundColor Gray
            $newReleaseFound = $true
        } else {
            Write-Host "  ✓ Already imported (up to date)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ⚡ NEW - no previous import record" -ForegroundColor Magenta
        $newReleaseFound = $true
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan

if ($newReleaseFound) {
    Write-Host "🔄 New DM+D release(s) detected. Starting download and import..." -ForegroundColor Green
    "[$timestamp] New releases detected - initiating download and import" | Out-File $logFile -Append
    
    # Step 1: Download releases
    $downloadScript = Join-Path $baseDir "Download-DMDReleases.ps1"
    if (Test-Path $downloadScript) {
        Write-Host "`n--- Step 1: Downloading releases ---" -ForegroundColor Cyan
        & $downloadScript
    } else {
        Write-Error "Download script not found: $downloadScript"
        "[$timestamp] ERROR: Download script not found" | Out-File $logFile -Append
        exit 1
    }
    
    # Step 2: Run imports
    $importScript = Join-Path $baseDir "StandaloneImports\Run-AllImports.ps1"
    if (Test-Path $importScript) {
        Write-Host "`n--- Step 2: Running imports ---" -ForegroundColor Cyan
        
        # Find the latest release folders dynamically
        $currentReleasesDir = Join-Path $dataDir "CurrentReleases"
        $dmdMainFolder = Get-ChildItem -Path $currentReleasesDir -Directory | 
            Where-Object { $_.Name -match "^nhsbsa_dmd_\d" } |
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        $dmdBonusFolder = Get-ChildItem -Path $currentReleasesDir -Directory | 
            Where-Object { $_.Name -match "^nhsbsa_dmdbonus_" } |
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($dmdMainFolder -and $dmdBonusFolder) {
            Write-Host "  Using DM+D Main: $($dmdMainFolder.Name)" -ForegroundColor Gray
            Write-Host "  Using DM+D Bonus: $($dmdBonusFolder.Name)" -ForegroundColor Gray
            Push-Location (Join-Path $baseDir "StandaloneImports")
            & $importScript -XmlPath $dmdMainFolder.FullName -BonusPath $dmdBonusFolder.FullName
            Pop-Location
        } else {
            Write-Error "Could not find DM+D release folders in $currentReleasesDir"
            "[$timestamp] ERROR: Release folders not found" | Out-File $logFile -Append
            exit 1
        }
    } else {
        Write-Error "Import script not found: $importScript"
        "[$timestamp] ERROR: Import script not found" | Out-File $logFile -Append
        exit 1
    }
    
    # Step 3: Validate (optional but recommended)
    $validateScript = Join-Path $baseDir "Validate-RandomSamples.ps1"
    if (Test-Path $validateScript) {
        Write-Host "`n--- Step 3: Validating import ---" -ForegroundColor Cyan
        # Find the latest release folder for validation
        $currentReleasesDir = Join-Path $dataDir "CurrentReleases"
        $latestReleaseFolder = Get-ChildItem -Path $currentReleasesDir -Directory | 
            Where-Object { $_.Name -match "nhsbsa_dmd_" } |
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($latestReleaseFolder) {
            & $validateScript -XmlPath $latestReleaseFolder.FullName -SamplesPerTable 100
        } else {
            Write-Warning "Could not find release folder for validation"
        }
    }
    
    # Step 4: Update the last imported release tracking (only after successful import)
    foreach ($itemName in $currentReleases.Keys) {
        $lastImportedReleases[$itemName] = $currentReleases[$itemName]
    }
    $lastImportedReleases | ConvertTo-Json | Out-File $lastImportFile -Encoding UTF8
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] Import completed successfully" | Out-File $logFile -Append
    
    Write-Host "`n✅ DM+D update complete!" -ForegroundColor Green
    Write-Host "   Releases imported: $($currentReleases.Values -join ', ')" -ForegroundColor Green
    
} else {
    "[$timestamp] No new releases - already up to date" | Out-File $logFile -Append
    Write-Host "✅ No new releases. Database is already up to date." -ForegroundColor Green
    Write-Host "   Last imported: $($lastImportedReleases.Values -join ', ')" -ForegroundColor Gray
}

Write-Host "`n💡 Tip: Schedule this script to run weekly for automatic updates." -ForegroundColor Cyan