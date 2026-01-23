# Save this as Generate-AndRun-AllSnapshots.ps1

# Get the base directory where the logs and releases are stored.
$baseDir = "C:\SNOMEDCT"
Write-Host "Script base directory: $baseDir"

# Define the CurrentReleases folder path (where the TRUD releases have been extracted)
$currentReleasesDir = Join-Path $baseDir "CurrentReleases"
if (-not (Test-Path $currentReleasesDir)) {
    Write-Host "CurrentReleases folder not found at $currentReleasesDir. Please ensure releases are downloaded and extracted there."
    exit
}

# Automatically locate snapshot folders by searching recursively for directories named "Snapshot" within CurrentReleases
$allSnapshotFolders = Get-ChildItem -Path $currentReleasesDir -Recurse -Directory | Where-Object { $_.Name -eq "Snapshot" } | ForEach-Object { 
    $_.FullName 
}

# Check if Monolith is present - if so, exclude standalone International, UK Edition, and UK Drug Extension to avoid duplicates
# The Monolith (UK Clinical Edition) already includes International, UK Edition, and UK Drug Extension content
$hasMonolith = $allSnapshotFolders | Where-Object { $_ -match "Monolith|uk_sct2mo" }
$hasInternational = $allSnapshotFolders | Where-Object { $_ -match "SnomedCT_InternationalRF2" }

$snapshotFolders = @()
foreach ($folder in $allSnapshotFolders) {
    # Skip standalone International if Monolith is present (Monolith already includes International)
    if ($hasMonolith -and $folder -match "SnomedCT_InternationalRF2") {
        Write-Host "Skipping standalone International (already included in Monolith): $folder" -ForegroundColor Yellow
        continue
    }
    # Skip UK Edition from Drug Extension package if Monolith is present (Monolith already includes UK Edition)
    if ($hasMonolith -and $folder -match "SnomedCT_UKEditionRF2") {
        Write-Host "Skipping UK Edition (already included in Monolith): $folder" -ForegroundColor Yellow
        continue
    }
    # Skip UK Drug Extension if Monolith is present (Monolith already includes UK Drug Extension)
    if ($hasMonolith -and $folder -match "SnomedCT_UKDrugRF2") {
        Write-Host "Skipping UK Drug Extension (already included in Monolith): $folder" -ForegroundColor Yellow
        continue
    }
    Write-Host "Found snapshot folder: $folder"
    $snapshotFolders += $folder
}

# Sort folders to ensure Monolith is processed first (if present), then UK Primary Care
$snapshotFolders = $snapshotFolders | Sort-Object { 
    if ($_ -match "Monolith|uk_sct2mo") { 0 }
    elseif ($_ -match "UKPrimaryCare|uk_sct2pc") { 1 }
    else { 2 }
}

if ($snapshotFolders.Count -eq 0) {
    Write-Host "No snapshot folders found in $currentReleasesDir. Ensure that the SNOMED packages contain a 'Snapshot' folder."
    exit
}

# Global header for the SQL script
$outputFile = "C:\SNOMEDCT\import.sql"
$header = @"
-- Generating BULK INSERTS for Monolith + UK Primary Care + UK Drug Extension Snapshot
USE snomedct;
GO

-- Clear all tables before import to prevent duplicate key errors
PRINT 'Clearing existing data from tables...';

DELETE FROM curr_textdefinition_f;
PRINT 'Cleared curr_textdefinition_f';

DELETE FROM curr_stated_relationship_f;
PRINT 'Cleared curr_stated_relationship_f';

DELETE FROM curr_relationship_f;
PRINT 'Cleared curr_relationship_f';

DELETE FROM curr_description_f;
PRINT 'Cleared curr_description_f';

DELETE FROM curr_concept_f;
PRINT 'Cleared curr_concept_f';

DELETE FROM curr_extendedmaprefset_f;
PRINT 'Cleared curr_extendedmaprefset_f';

DELETE FROM curr_simplemaprefset_f;
PRINT 'Cleared curr_simplemaprefset_f';

DELETE FROM curr_associationrefset_f;
PRINT 'Cleared curr_associationrefset_f';

DELETE FROM curr_attributevaluerefset_f;
PRINT 'Cleared curr_attributevaluerefset_f';

DELETE FROM curr_simplerefset_f;
PRINT 'Cleared curr_simplerefset_f';

DELETE FROM curr_langrefset_f;
PRINT 'Cleared curr_langrefset_f';

PRINT 'All tables cleared. Starting import...';
GO

"@

# Write the global header to the output file
Set-Content -Path $outputFile -Value $header

# Mapping of file prefixes to database table names
# Supports Monolith, UK Primary Care, and UK Drug Extension RF2 formats
$mapping = @{
    "sct2_Concept"                 = "curr_concept_f"
    "sct2_Description"             = "curr_description_f"
    "sct2_TextDefinition"          = "curr_textdefinition_f"
    "sct2_Relationship"            = "curr_relationship_f"
    "sct2_RelationshipConcreteValues" = "curr_relationship_f"
    "sct2_StatedRelationship"      = "curr_stated_relationship_f"
    "der2_cRefset_Language"        = "curr_langrefset_f"
    "der2_Refset_Simple"           = "curr_simplerefset_f"
    "der2_cRefset_AttributeValue"  = "curr_attributevaluerefset_f"
    "der2_cRefset_Association"     = "curr_associationrefset_f"
    "der2_sRefset_SimpleMap"       = "curr_simplemaprefset_f"
    "der2_iisssccRefset_ExtendedMap" = "curr_extendedmaprefset_f"
}

# Loop through each snapshot folder to add BULK INSERT statements
foreach ($folder in $snapshotFolders) {
    # Write a comment header for the current folder in the output file
    $folderHeader = "-- Processing folder: $folder"
    Add-Content -Path $outputFile -Value $folderHeader
    Write-Host "Processing folder: $folder"

    # Process each file in the folder (including subdirectories)
    $filesFound = $false
    $processedFiles = @{}  # Track processed files to avoid duplicates
    Get-ChildItem -Recurse -Path $folder -File | ForEach-Object {
        $fileName = $_.Name
        $filePath = $_.FullName
        
        # Skip if already processed (can happen with overlapping prefix matches)
        if ($processedFiles.ContainsKey($filePath)) {
            return
        }
        
        # Sort prefixes by length descending to match most specific prefix first
        $sortedPrefixes = $mapping.Keys | Sort-Object { $_.Length } -Descending
        
        foreach ($prefix in $sortedPrefixes) {
            if ($fileName -like "$prefix*") {
                $filesFound = $true
                $processedFiles[$filePath] = $true
                $table = $mapping[$prefix]
                # Escape backslashes for SQL script
                $path = $filePath -replace "\\", "\\\\"
                $stmt = "BULK INSERT $table FROM '$path' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);"
                Add-Content -Path $outputFile -Value $stmt
                Write-Host "Added BULK INSERT for file: $fileName -> $table"
                break  # Stop after first (most specific) match to avoid duplicate inserts
            }
        }
    }
    if (-not $filesFound) {
        Write-Host "No matching files found in folder: $folder"
    }
}

Write-Host "import.sql has been created at $outputFile"

# Set your SQL Server instance and database name
$serverInstance = "SILENTPRIORY\SQLEXPRESS"
$database = "snomedct"

# Option 1: Using Invoke-Sqlcmd (requires the SqlServer module)
# Uncomment the following lines if you prefer this method:
# Import-Module SqlServer
# Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database -InputFile $outputFile

# Option 2: Using sqlcmd command-line utility
$sqlcmdCommand = "sqlcmd -S `"$serverInstance`" -d `"$database`" -i `"$outputFile`""
Write-Host "Executing SQL script with command: $sqlcmdCommand"
Invoke-Expression $sqlcmdCommand

Write-Host "SQL script executed successfully."
