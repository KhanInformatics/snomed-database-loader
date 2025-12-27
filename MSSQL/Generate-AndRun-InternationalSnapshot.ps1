# Save this as Generate-AndRun-InternationalSnapshot.ps1
# This script generates BULK INSERT statements specifically for the SNOMED CT International Edition
# and imports them into the separate snomedct_int database

param(
    [string]$BaseDir = "C:\SNOMEDCT",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "snomedct_int"
)

Write-Host "=============================================="
Write-Host "SNOMED CT International Edition Import Script"
Write-Host "=============================================="
Write-Host ""
Write-Host "Script base directory: $BaseDir"
Write-Host "Target database: $Database"
Write-Host ""

# Define the CurrentReleases folder path
$currentReleasesDir = Join-Path $BaseDir "CurrentReleases"
if (-not (Test-Path $currentReleasesDir)) {
    Write-Error "CurrentReleases folder not found at $currentReleasesDir. Please ensure releases are downloaded and extracted there."
    exit 1
}

# Look specifically for the International Edition folder
# International Edition releases typically have names like "SnomedCT_InternationalRF2_PRODUCTION_*"
$intRelease = Get-ChildItem -Path $currentReleasesDir -Directory | Where-Object { 
    $_.Name -like "*International*" -or $_.Name -like "*INT*" 
}

if (-not $intRelease) {
    Write-Error "No International Edition release found in $currentReleasesDir"
    Write-Host "Expected folder pattern: *International* or *INT*"
    Write-Host ""
    Write-Host "Available folders:"
    Get-ChildItem -Path $currentReleasesDir -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

Write-Host "Found International Edition release: $($intRelease.FullName)"

# Find the Snapshot folder within the International release
$snapshotFolders = Get-ChildItem -Path $intRelease.FullName -Recurse -Directory | Where-Object { $_.Name -eq "Snapshot" }

if ($snapshotFolders.Count -eq 0) {
    Write-Error "No Snapshot folder found in the International Edition release"
    exit 1
}

foreach ($snap in $snapshotFolders) {
    Write-Host "Found snapshot folder: $($snap.FullName)"
}

# Output SQL file
$outputFile = Join-Path $BaseDir "import-international.sql"

# SQL Header - uses the snomedct_int database
$header = @"
-- BULK INSERTS for SNOMED CT International Edition Snapshot
-- Target database: $Database
USE $Database;
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

# Write the header
Set-Content -Path $outputFile -Value $header

# Mapping of RF2 file prefixes to database table names
$mapping = @{
    "sct2_Concept"                    = "curr_concept_f"
    "sct2_Description"                = "curr_description_f"
    "sct2_TextDefinition"             = "curr_textdefinition_f"
    "sct2_Relationship"               = "curr_relationship_f"
    "sct2_RelationshipConcreteValues" = "curr_relationship_f"
    "sct2_StatedRelationship"         = "curr_stated_relationship_f"
    "der2_cRefset_Language"           = "curr_langrefset_f"
    "der2_Refset_Simple"              = "curr_simplerefset_f"
    "der2_cRefset_AttributeValue"     = "curr_attributevaluerefset_f"
    "der2_cRefset_Association"        = "curr_associationrefset_f"
    "der2_sRefset_SimpleMap"          = "curr_simplemaprefset_f"
    "der2_iisssccRefset_ExtendedMap"  = "curr_extendedmaprefset_f"
}

# Process each snapshot folder
$totalFiles = 0
foreach ($folder in $snapshotFolders) {
    Add-Content -Path $outputFile -Value "-- Processing folder: $folder"
    Write-Host ""
    Write-Host "Processing folder: $($folder.FullName)"
    
    Get-ChildItem -Recurse -Path $folder.FullName -File -Filter "*.txt" | ForEach-Object {
        foreach ($prefix in $mapping.Keys) {
            if ($_.Name -like "$prefix*") {
                $table = $mapping[$prefix]
                $path = $_.FullName -replace "\\", "\\\\"
                $stmt = "BULK INSERT $table FROM '$path' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);"
                Add-Content -Path $outputFile -Value $stmt
                Write-Host "  + $($_.Name) -> $table"
                $totalFiles++
            }
        }
    }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "Generated $totalFiles BULK INSERT statements"
Write-Host "SQL script saved to: $outputFile"
Write-Host "=============================================="
Write-Host ""

# Ask user before executing
$confirm = Read-Host "Do you want to execute the import now? (Y/N)"
if ($confirm -eq "Y" -or $confirm -eq "y") {
    Write-Host ""
    Write-Host "Executing SQL script..."
    Write-Host "Server: $ServerInstance"
    Write-Host "Database: $Database"
    Write-Host ""
    
    $sqlcmdCommand = "sqlcmd -S `"$ServerInstance`" -d `"$Database`" -i `"$outputFile`""
    Write-Host "Command: $sqlcmdCommand"
    Write-Host ""
    
    try {
        Invoke-Expression $sqlcmdCommand
        Write-Host ""
        Write-Host "✅ Import completed successfully!"
        
        # Show record counts
        Write-Host ""
        Write-Host "Verifying import - Record counts:"
        $countQuery = @"
SELECT 'Concepts' as TableName, COUNT(*) as Records FROM curr_concept_f
UNION ALL SELECT 'Descriptions', COUNT(*) FROM curr_description_f
UNION ALL SELECT 'Relationships', COUNT(*) FROM curr_relationship_f
"@
        sqlcmd -S "$ServerInstance" -d "$Database" -Q "$countQuery"
        
    } catch {
        Write-Error "Error executing SQL script: $_"
    }
} else {
    Write-Host ""
    Write-Host "Import cancelled. To run manually, execute:"
    Write-Host "  sqlcmd -S `"$ServerInstance`" -d `"$Database`" -i `"$outputFile`""
}
