# Process SNOMED CT UK Drug Extension Data and Generate DM+D Import Scripts
# This script processes RF2 format drug data instead of XML DM+D format
# Save this as Process-SNOMEDDrugData.ps1

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [switch]$GenerateOnly = $false,
    [switch]$ExecuteOnly = $false
)

# Get the base directory where the releases are stored
$baseDir = "C:\DMD"
$currentReleasesDir = Join-Path $baseDir "CurrentReleases"
$outputFile = "C:\DMD\import-snomed-drugs.sql"

Write-Host "=== SNOMED CT UK Drug Extension Data Processor ===" -ForegroundColor Cyan
Write-Host "Base Directory: $baseDir"
Write-Host "Current Releases: $currentReleasesDir"

if (-not (Test-Path $currentReleasesDir)) {
    Write-Error "CurrentReleases folder not found at $currentReleasesDir. Please run Download-DMDReleases.ps1 first."
    exit
}

# Function to escape SQL string values
function Escape-SqlString($value) {
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    return "'" + $value.ToString().Replace("'", "''") + "'"
}

# Find SNOMED CT Drug files
Write-Host "Searching for SNOMED CT Drug files..."
$drugConceptFiles = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "*Concept*UKDG*Snapshot*.txt"
$drugDescriptionFiles = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "*Description*UKDG*Snapshot*.txt"
$drugRelationshipFiles = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "*Relationship*UKDG*Snapshot*.txt"

if ($drugConceptFiles.Count -eq 0) {
    Write-Error "No SNOMED CT Drug concept files found in $currentReleasesDir"
    exit
}

Write-Host "Found SNOMED CT Drug files:"
foreach ($file in ($drugConceptFiles + $drugDescriptionFiles + $drugRelationshipFiles)) {
    Write-Host "  $($file.FullName)"
}

# Generate SQL import script
if (-not $ExecuteOnly) {
    Write-Host "`nGenerating SQL import script..."

    # SQL Header - Create temporary tables for SNOMED drug data
    $sqlHeader = @"
-- SNOMED CT UK Drug Extension Import Script  
-- Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
USE $Database;
GO

-- Create temporary tables for SNOMED CT Drug data
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[temp_snomed_concepts]') AND type in (N'U'))
    DROP TABLE temp_snomed_concepts;
    
CREATE TABLE temp_snomed_concepts (
    conceptId BIGINT NOT NULL,
    effectiveTime VARCHAR(8) NOT NULL,
    active BIT NOT NULL,
    moduleId BIGINT NOT NULL,
    definitionStatusId BIGINT NOT NULL,
    PRIMARY KEY (conceptId, effectiveTime)
);

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[temp_snomed_descriptions]') AND type in (N'U'))
    DROP TABLE temp_snomed_descriptions;
    
CREATE TABLE temp_snomed_descriptions (
    id BIGINT NOT NULL,
    effectiveTime VARCHAR(8) NOT NULL,
    active BIT NOT NULL,
    moduleId BIGINT NOT NULL,
    conceptId BIGINT NOT NULL,
    languageCode VARCHAR(2) NOT NULL,
    typeId BIGINT NOT NULL,
    term NVARCHAR(255) NOT NULL,
    caseSignificanceId BIGINT NOT NULL,
    PRIMARY KEY (id, effectiveTime)
);

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[temp_snomed_relationships]') AND type in (N'U'))
    DROP TABLE temp_snomed_relationships;
    
CREATE TABLE temp_snomed_relationships (
    id BIGINT NOT NULL,
    effectiveTime VARCHAR(8) NOT NULL,
    active BIT NOT NULL,
    moduleId BIGINT NOT NULL,
    sourceId BIGINT NOT NULL,
    destinationId BIGINT NOT NULL,
    relationshipGroup INT NOT NULL,
    typeId BIGINT NOT NULL,
    characteristicTypeId BIGINT NOT NULL,
    modifierId BIGINT NOT NULL,
    PRIMARY KEY (id, effectiveTime)
);

PRINT 'Starting SNOMED CT Drug data import...';

"@

    Set-Content -Path $outputFile -Value $sqlHeader

    # Process Concept files
    foreach ($conceptFile in $drugConceptFiles) {
        Write-Host "Processing concept file: $($conceptFile.Name)..."
        
        Add-Content -Path $outputFile -Value "`n-- Processing concept file: $($conceptFile.Name)"
        
        # Use BULK INSERT for concept data
        $escapedPath = $conceptFile.FullName -replace "\\", "\\\\"
        $bulkInsert = "BULK INSERT temp_snomed_concepts FROM '$escapedPath' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);"
        Add-Content -Path $outputFile -Value $bulkInsert
    }

    # Process Description files  
    foreach ($descFile in $drugDescriptionFiles) {
        Write-Host "Processing description file: $($descFile.Name)..."
        
        Add-Content -Path $outputFile -Value "`n-- Processing description file: $($descFile.Name)"
        
        $escapedPath = $descFile.FullName -replace "\\", "\\\\"
        $bulkInsert = "BULK INSERT temp_snomed_descriptions FROM '$escapedPath' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);"
        Add-Content -Path $outputFile -Value $bulkInsert
    }

    # Process Relationship files
    foreach ($relFile in $drugRelationshipFiles) {
        Write-Host "Processing relationship file: $($relFile.Name)..."
        
        Add-Content -Path $outputFile -Value "`n-- Processing relationship file: $($relFile.Name)"
        
        $escapedPath = $relFile.FullName -replace "\\", "\\\\"
        $bulkInsert = "BULK INSERT temp_snomed_relationships FROM '$escapedPath' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);"
        Add-Content -Path $outputFile -Value $bulkInsert
    }

    # SQL transformation logic to extract DM+D structure from SNOMED CT
    $sqlTransformation = @"

-- Extract DM+D hierarchy from SNOMED CT Drug Extension
PRINT 'Extracting DM+D structure from SNOMED CT Drug Extension...';

-- Clear existing DM+D data
TRUNCATE TABLE dmd_snomed;
DELETE FROM vmp_ingredient;
DELETE FROM vmp_drugform; 
DELETE FROM vmp_drugroute;
DELETE FROM ampp;
DELETE FROM vmpp;
DELETE FROM amp;
DELETE FROM vmp;
DELETE FROM vtm;

-- Extract VTMs (Virtual Therapeutic Moieties) - these are substance concepts
INSERT INTO vtm (vtmid, invalid, nm)
SELECT DISTINCT
    c.conceptId,
    CASE WHEN c.active = 0 THEN 1 ELSE 0 END,
    d.term
FROM temp_snomed_concepts c
JOIN temp_snomed_descriptions d ON c.conceptId = d.conceptId
JOIN temp_snomed_relationships r ON c.conceptId = r.sourceId
WHERE c.active = 1 
  AND d.active = 1
  AND d.typeId = 900000000000003001  -- FSN (Fully Specified Name)
  AND r.active = 1
  AND r.typeId = 116680003  -- Is a relationship
  AND r.destinationId = 105590001   -- Substance (substance)
  AND d.term LIKE '%(substance)%'
  AND c.conceptId > 999000000000000000; -- UK Extension concepts

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' VTM concepts';

-- Extract VMPs (Virtual Medical Products) - these are medicinal product concepts  
INSERT INTO vmp (vpid, invalid, vtmid, nm, pres_f)
SELECT DISTINCT
    c.conceptId,
    CASE WHEN c.active = 0 THEN 1 ELSE 0 END,
    r.destinationId, -- Link to VTM through "Has active ingredient" relationship
    d.term,
    1  -- Assume prescribable by default
FROM temp_snomed_concepts c
JOIN temp_snomed_descriptions d ON c.conceptId = d.conceptId  
JOIN temp_snomed_relationships r ON c.conceptId = r.sourceId
JOIN vtm v ON r.destinationId = v.vtmid
WHERE c.active = 1
  AND d.active = 1 
  AND d.typeId = 900000000000003001  -- FSN
  AND r.active = 1
  AND r.typeId = 127489000  -- Has active ingredient
  AND (d.term LIKE '%(medicinal product)%' OR d.term LIKE '%(product)%')
  AND c.conceptId > 999000000000000000; -- UK Extension concepts

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' VMP concepts';

-- Extract AMPs (Actual Medical Products) - these are trade product concepts
INSERT INTO amp (apid, invalid, vpid, nm)  
SELECT DISTINCT
    c.conceptId,
    CASE WHEN c.active = 0 THEN 1 ELSE 0 END,
    r.destinationId, -- Link to VMP through "Is a" relationship  
    d.term
FROM temp_snomed_concepts c
JOIN temp_snomed_descriptions d ON c.conceptId = d.conceptId
JOIN temp_snomed_relationships r ON c.conceptId = r.sourceId
JOIN vmp v ON r.destinationId = v.vpid
WHERE c.active = 1
  AND d.active = 1
  AND d.typeId = 900000000000003001  -- FSN
  AND r.active = 1 
  AND r.typeId = 116680003  -- Is a relationship
  AND (d.term LIKE '%(product)%' OR d.term NOT LIKE '%(medicinal product)%')
  AND c.conceptId > 999000000000000000; -- UK Extension concepts

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' AMP concepts';

-- Create SNOMED CT mappings
INSERT INTO dmd_snomed (dmd_id, dmd_type, snomed_conceptid)
SELECT vtmid, 'VTM', vtmid FROM vtm
UNION ALL  
SELECT vpid, 'VMP', vpid FROM vmp
UNION ALL
SELECT apid, 'AMP', apid FROM amp;

-- Populate lookup table with common SNOMED CT concepts
INSERT INTO lookup (cd, cdtype, desc_val)
SELECT DISTINCT
    c.conceptId,
    'SNOMED_CONCEPT',
    d.term
FROM temp_snomed_concepts c
JOIN temp_snomed_descriptions d ON c.conceptId = d.conceptId
WHERE c.active = 1
  AND d.active = 1
  AND d.typeId = 900000000000003001  -- FSN
  AND c.conceptId IN (
      SELECT DISTINCT typeId FROM temp_snomed_relationships
      UNION
      SELECT DISTINCT destinationId FROM temp_snomed_relationships
      WHERE destinationId < 999000000000000000 -- International concepts used as types
  );

-- Clean up temporary tables
DROP TABLE temp_snomed_concepts;
DROP TABLE temp_snomed_descriptions; 
DROP TABLE temp_snomed_relationships;

PRINT 'SNOMED CT Drug data processing completed successfully';

-- Summary statistics
SELECT 
    'VTMs (Active Ingredients)' as Entity_Type,
    COUNT(*) as Total_Count,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Count
FROM vtm
UNION ALL
SELECT 
    'VMPs (Generic Products)',
    COUNT(*),
    COUNT(CASE WHEN invalid = 0 THEN 1 END)
FROM vmp  
UNION ALL
SELECT
    'AMPs (Branded Products)', 
    COUNT(*),
    COUNT(CASE WHEN invalid = 0 THEN 1 END)
FROM amp
UNION ALL
SELECT
    'SNOMED Mappings',
    COUNT(*),
    COUNT(*)
FROM dmd_snomed
UNION ALL
SELECT
    'Lookup Concepts',
    COUNT(*), 
    COUNT(*)
FROM lookup;
"@

    Add-Content -Path $outputFile -Value $sqlTransformation
    Write-Host "✅ SQL import script generated: $outputFile"
}

# Execute the SQL script if requested
if (-not $GenerateOnly) {
    Write-Host "`nExecuting SQL import script..."
    
    try {
        # Use trusted connection with no encryption
        $sqlcmdCommand = "sqlcmd -S `"$ServerInstance`" -d `"$Database`" -E -C -i `"$outputFile`""
        Write-Host "Executing: $sqlcmdCommand"
        Invoke-Expression $sqlcmdCommand
        Write-Host "✅ SNOMED CT Drug data import completed successfully!"
    } catch {
        Write-Error "Error executing SQL script: $($_.Exception.Message)"
        Write-Host "You can manually execute the script: $outputFile"
    }
}

Write-Host "`n=== SNOMED Drug Processing Complete ===" -ForegroundColor Green
Write-Host "Note: This processed SNOMED CT UK Drug Extension data instead of pure DM+D XML."
Write-Host "The data includes drug concepts mapped to SNOMED CT but may not have all commercial DM+D fields."
Write-Host "`nNext steps:"
Write-Host "1. Run Validate-DMDImport.ps1 to validate the imported data"
Write-Host "2. Use queries in the DMD\Queries folder to explore the drug data"
Write-Host "3. Consider subscribing to the actual DM+D XML files (items 105/108) for complete commercial data"