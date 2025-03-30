# Save this as Generate-AndRun-AllSnapshots.ps1

# Get the directory where this script is located
$baseDir = $PSScriptRoot
Write-Host "Script base directory: $baseDir"

# Define the CurrentReleases folder path (where the TRUD releases have been extracted)
$currentReleasesDir = Join-Path $baseDir "CurrentReleases"
if (-not (Test-Path $currentReleasesDir)) {
    Write-Host "CurrentReleases folder not found at $currentReleasesDir. Please ensure releases are downloaded and extracted there."
    exit
}

# Automatically locate snapshot folders by searching recursively for directories named "Snapshot" within CurrentReleases
$snapshotFolders = Get-ChildItem -Path $currentReleasesDir -Recurse -Directory | Where-Object { $_.Name -eq "Snapshot" } | ForEach-Object { 
    Write-Host "Found snapshot folder: $($_.FullName)"
    $_.FullName 
}

if ($snapshotFolders.Count -eq 0) {
    Write-Host "No snapshot folders found in $currentReleasesDir. Ensure that the SNOMED packages contain a 'Snapshot' folder."
    exit
}

# Global header for the SQL script
$outputFile = "C:\SNOMEDCT\import.sql"
$header = @"
-- Generating BULK INSERTS for Monolith + UK Primary Care Snapshot
USE snomedct;
GO
TRUNCATE TABLE curr_concept_f;
TRUNCATE TABLE curr_description_f;
TRUNCATE TABLE curr_textdefinition_f;
TRUNCATE TABLE curr_relationship_f;
TRUNCATE TABLE curr_stated_relationship_f;
TRUNCATE TABLE curr_langrefset_f;
TRUNCATE TABLE curr_simplerefset_f;
TRUNCATE TABLE curr_attributevaluerefset_f;
TRUNCATE TABLE curr_associationrefset_f;
TRUNCATE TABLE curr_simplemaprefset_f;
TRUNCATE TABLE curr_extendedmaprefset_f;
"@

# Write the global header to the output file
Set-Content -Path $outputFile -Value $header

# Mapping of file prefixes to database table names
$mapping = @{
    "sct2_Concept"                 = "curr_concept_f"
    "sct2_Description"             = "curr_description_f"
    "sct2_TextDefinition"          = "curr_textdefinition_f"
    "sct2_Relationship"            = "curr_relationship_f"
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
    Get-ChildItem -Recurse -Path $folder -File | ForEach-Object {
        foreach ($prefix in $mapping.Keys) {
            if ($_.Name -like "$prefix*") {
                $filesFound = $true
                $table = $mapping[$prefix]
                # Escape backslashes for SQL script
                $path = $_.FullName -replace "\\", "\\\\"
                $stmt = "BULK INSERT $table FROM '$path' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);"
                Add-Content -Path $outputFile -Value $stmt
                Write-Host "Added BULK INSERT for file: $($_.Name) -> $table"
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
