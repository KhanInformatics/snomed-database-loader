# Import the CredentialManager module
Import-Module CredentialManager

# Get the base directory (where the script is located)
$baseDir = $PSScriptRoot

# Directory to store state (LastRelease.json) and logs
$dataDir = "C:\\SNOMEDCT"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# Retrieve the TRUD API key from Credential Manager (target: TRUD_API)
$credential = Get-StoredCredential -Target "TRUD_API"
if (-not $credential) {
    Write-Error "Could not retrieve the API key from Credential Manager. Please store it under the target 'TRUD_API'."
    exit
}

# Convert the SecureString to plain text
$apiKeySecure = $credential.Password
$apiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKeySecure)
         )

if (-not $apiKey) {
    Write-Error "API key is empty. Please verify your stored credential."
    exit
}

# Create a masked version of the API key for logging
if ($apiKey.Length -ge 8) {
    $maskedKey = $apiKey.Substring(0,4) + ("*" * ($apiKey.Length - 8)) + $apiKey.Substring($apiKey.Length - 4,4)
} else {
    $maskedKey = $apiKey
}
Write-Host "Retrieved API Key: $maskedKey (Length: $($apiKey.Length))"

# Define the SNOMED CT items you want to monitor.
$items = @(
    @{ Name = "SnomedCT_Monolith"; ItemNumber = "1799" },
    @{ Name = "SnomedCT_UKPrimaryCare"; ItemNumber = "659" },
    @{ Name = "SnomedCT_UKDrugExtension"; ItemNumber = "105" }
)

# Base API URL for TRUD
$baseApiUrl = "https://isd.digital.nhs.uk/trud/api/v1/keys/$apiKey/items"
Write-Host "Base API URL: $baseApiUrl"

# File to store last-known release IDs per item (as JSON) -- now in C:\SNOMEDCT
$lastReleaseFile = Join-Path $dataDir "LastRelease.json"

# Load previous release records if they exist; otherwise, initialize an empty hashtable.
$lastReleases = @{}
if (Test-Path $lastReleaseFile) {
    $temp = Get-Content $lastReleaseFile -Raw | ConvertFrom-Json
    if ($temp) {
        foreach ($prop in $temp.PSObject.Properties) {
            $lastReleases[$prop.Name] = $prop.Value
        }
    }
}

# Flag to indicate if any new release is found.
$newReleaseFound = $false

# Loop through each item and query its latest release.
foreach ($item in $items) {
    $itemName = $item.Name
    $itemNumber = $item.ItemNumber
    $url = "$baseApiUrl/$itemNumber/releases?latest"
    
    # Log the full request URL.
    Write-Host "Request URL for ${itemName} (item number ${itemNumber}): $url"
    
    Write-Host "Querying TRUD API for ${itemName} (item number ${itemNumber})..."
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    } catch {
        Write-Error "Error querying TRUD for ${itemName}: $($_.Exception.Message)"
        continue
    }
    if ($response.releases.Count -eq 0) {
        Write-Host "No releases found for ${itemName}."
        continue
    }
    
    # Use the first (latest) release from the response.
    $latestRelease = $response.releases[0]
    $currentReleaseId = $latestRelease.id  # Alternatively, you could use releaseDate.
    
    Write-Host "${itemName} latest release ID: $currentReleaseId"
    
    # Check if we already have a stored release ID for this item.
    if ($lastReleases.ContainsKey($itemName)) {
        if ($lastReleases[$itemName] -ne $currentReleaseId) {
            Write-Host "New release detected for ${itemName}: Previous ID = $($lastReleases[$itemName]), New ID = $currentReleaseId" -ForegroundColor Yellow
            $newReleaseFound = $true
        } else {
            Write-Host "No new release for ${itemName}."
        }
    }
    else {
        Write-Host "No previous record for ${itemName}. Treating as new release." -ForegroundColor Yellow
        $newReleaseFound = $true
    }
    
    # Update our record with the current release ID.
    $lastReleases[$itemName] = $currentReleaseId
}

# Save the updated release record back to the JSON file.
$lastReleases | ConvertTo-Json | Out-File $lastReleaseFile -Encoding UTF8

# Define log file path (also in C:\SNOMEDCT)
$logFile = Join-Path $dataDir "CheckNewRelease.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if ($newReleaseFound) {
    Write-Host "New release(s) detected. Initiating download and import process." -ForegroundColor Green

    # Log new release event
    "[$timestamp] New releases detected and processed." | Out-File $logFile -Append

    $downloadScript = Join-Path $baseDir "Download-SnomedReleases.ps1"
    $importScript   = Join-Path $baseDir "Generate-AndRun-AllSnapshots.ps1"

    if (Test-Path $downloadScript) {
        Write-Host "Running $downloadScript..."
        & $downloadScript
    } else {
        Write-Error "File not found: $downloadScript"
    }

    if (Test-Path $importScript) {
        Write-Host "Running $importScript..."
        & $importScript
    } else {
        Write-Error "File not found: $importScript"
    }
    
    # Define the row count query
    $query = @" 
SELECT  
    t.name AS TableName,
    SUM(p.row_count) AS TotalRows
FROM sys.tables AS t
INNER JOIN sys.dm_db_partition_stats AS p
    ON t.object_id = p.object_id
WHERE t.name IN (
    'curr_concept_f', 
    'curr_description_f', 
    'curr_textdefinition_f',
    'curr_relationship_f', 
    'curr_stated_relationship_f',
    'curr_langrefset_f', 
    'curr_associationrefset_f', 
    'curr_attributevaluerefset_f',
    'curr_simplerefset_f', 
    'curr_simplemaprefset_f', 
    'curr_extendedmaprefset_f'
)
  AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;
"@

    # Set your SQL Server connection parameters
    $serverInstance = "SILENTPRIORY\\SQLEXPRESS"
    $database = "snomedct"

    try {
        $result = Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database -Query $query -ErrorAction Stop
        "[$timestamp] Row counts:" | Out-File $logFile -Append
        $result | Out-File $logFile -Append
    }
    catch {
        "[$timestamp] ERROR running row count query: $($_.Exception.Message)" | Out-File $logFile -Append
    }
}
else {
    # If there is no new release, log that fact. This ensures the log file is created or appended to.
    "[$timestamp] No new releases detected." | Out-File $logFile -Append
    Write-Host "No new releases detected. No action taken."
}
