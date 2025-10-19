# Simple SNOMED CT Drug Data Import Script
# This version uses PowerShell to parse the files and generate INSERT statements

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd"
)

Write-Host "=== Simple SNOMED CT Drug Import ===" -ForegroundColor Cyan

# Find the files
$currentReleasesDir = "C:\DMD\CurrentReleases"
$conceptFile = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "*Concept*UKDG*Snapshot*.txt" | Select-Object -First 1
$descriptionFile = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "sct2_Description*UKDG*" | Where-Object { $_.Name -like "*en_*" }
$relationshipFile = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "sct2_Relationship*UKDG*Snapshot*.txt" | Select-Object -First 1

Write-Host "Using files:"
Write-Host "  Concepts: $($conceptFile.Name)"
Write-Host "  Descriptions: $($descriptionFile.Name)" 
Write-Host "  Relationships: $($relationshipFile.Name)"

# Clear existing data
Write-Host "`nClearing existing DM+D data..."
$clearSQL = @"
USE $Database;
DELETE FROM dmd_snomed;
DELETE FROM vmp_ingredient;
DELETE FROM vmp_drugform; 
DELETE FROM vmp_drugroute;
DELETE FROM ampp;
DELETE FROM vmpp;
DELETE FROM amp;
DELETE FROM vmp;
DELETE FROM vtm;
DELETE FROM lookup WHERE cdtype = 'SNOMED_CONCEPT';
"@

sqlcmd -S "$ServerInstance" -d "$Database" -E -C -Q "$clearSQL"

# Function to escape SQL strings
function Escape-SqlString($value) {
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    return "'" + $value.ToString().Replace("'", "''") + "'"
}

Write-Host "`nProcessing concept and description files..."

# Load concepts and descriptions
$concepts = @{}
$descriptions = @{}

# Read concepts (skip header)
Get-Content $conceptFile.FullName | Select-Object -Skip 1 | ForEach-Object {
    $fields = $_ -split "`t"
    if ($fields.Length -ge 5) {
        $concepts[$fields[0]] = @{
            conceptId = $fields[0]
            effectiveTime = $fields[1]
            active = $fields[2]
            moduleId = $fields[3]
            definitionStatusId = $fields[4]
        }
    }
}

Write-Host "Loaded $($concepts.Count) concepts"

# Read descriptions (skip header) 
Get-Content $descriptionFile.FullName | Select-Object -Skip 1 | ForEach-Object {
    $fields = $_ -split "`t"
    if ($fields.Length -ge 9) {
        $conceptId = $fields[4]
        $typeId = $fields[6]
        $term = $fields[7]
        
        # Only keep FSN (Fully Specified Names) for active concepts
        if ($fields[2] -eq "1" -and $typeId -eq "900000000000003001" -and $concepts.ContainsKey($conceptId)) {
            $descriptions[$conceptId] = $term
        }
    }
}

Write-Host "Loaded $($descriptions.Count) active descriptions"

# Extract VTMs (substance concepts)
Write-Host "`nExtracting VTMs (substances)..."
$vtmCount = 0
$vtmSQL = @()

foreach ($conceptId in $concepts.Keys) {
    $concept = $concepts[$conceptId]
    if ($concept.active -eq "1" -and $descriptions.ContainsKey($conceptId)) {
        $term = $descriptions[$conceptId]
        if ($term -like "*(substance)*" -and $conceptId -gt 999000000000000000) {
            $escapedTerm = Escape-SqlString $term
            $vtmSQL += "INSERT INTO vtm (vtmid, invalid, nm) VALUES ($conceptId, 0, $escapedTerm);"
            $vtmCount++
            if ($vtmCount -le 10) { Write-Host "  VTM: $conceptId - $term" }
        }
    }
}

Write-Host "Found $vtmCount VTM concepts"

# Extract VMPs and AMPs (product concepts)
Write-Host "`nExtracting VMPs and AMPs (products)..."
$vmpCount = 0
$ampCount = 0
$vmpSQL = @()
$ampSQL = @()

foreach ($conceptId in $concepts.Keys) {
    $concept = $concepts[$conceptId]
    if ($concept.active -eq "1" -and $descriptions.ContainsKey($conceptId)) {
        $term = $descriptions[$conceptId]
        if ($term -like "*(product)*" -and $conceptId -gt 999000000000000000) {
            if ($term -like "*(medicinal product)*") {
                # This is likely a VMP
                $escapedTerm = Escape-SqlString $term
                $vmpSQL += "INSERT INTO vmp (vpid, invalid, nm, pres_f) VALUES ($conceptId, 0, $escapedTerm, 1);"
                $vmpCount++
                if ($vmpCount -le 5) { Write-Host "  VMP: $conceptId - $term" }
            } else {
                # This is likely an AMP
                $escapedTerm = Escape-SqlString $term
                $ampSQL += "INSERT INTO amp (apid, invalid, nm) VALUES ($conceptId, 0, $escapedTerm);"  
                $ampCount++
                if ($ampCount -le 5) { Write-Host "  AMP: $conceptId - $term" }
            }
        }
    }
}

Write-Host "Found $vmpCount VMP concepts and $ampCount AMP concepts"

# Execute SQL in batches
Write-Host "`nImporting data to database..."

if ($vtmSQL.Count -gt 0) {
    $batchSQL = "USE $Database;`n" + ($vtmSQL -join "`n")
    $batchSQL | Out-File -FilePath "C:\DMD\vtm_import.sql" -Encoding UTF8
    sqlcmd -S "$ServerInstance" -d "$Database" -E -C -i "C:\DMD\vtm_import.sql"
    Write-Host "✅ Imported $($vtmSQL.Count) VTMs"
}

if ($vmpSQL.Count -gt 0) {
    $batchSQL = "USE $Database;`n" + ($vmpSQL -join "`n")
    $batchSQL | Out-File -FilePath "C:\DMD\vmp_import.sql" -Encoding UTF8
    sqlcmd -S "$ServerInstance" -d "$Database" -E -C -i "C:\DMD\vmp_import.sql"
    Write-Host "✅ Imported $($vmpSQL.Count) VMPs"
}

if ($ampSQL.Count -gt 0) {
    $batchSQL = "USE $Database;`n" + ($ampSQL -join "`n")
    $batchSQL | Out-File -FilePath "C:\DMD\amp_import.sql" -Encoding UTF8
    sqlcmd -S "$ServerInstance" -d "$Database" -E -C -i "C:\DMD\amp_import.sql"
    Write-Host "✅ Imported $($ampSQL.Count) AMPs"
}

# Create SNOMED mappings
Write-Host "`nCreating SNOMED mappings..."
$mappingSQL = @"
USE $Database;
INSERT INTO dmd_snomed (dmd_id, dmd_type, snomed_conceptid)
SELECT vtmid, 'VTM', vtmid FROM vtm
UNION ALL  
SELECT vpid, 'VMP', vpid FROM vmp
UNION ALL
SELECT apid, 'AMP', apid FROM amp;
"@

sqlcmd -S "$ServerInstance" -d "$Database" -E -C -Q "$mappingSQL"

# Final summary
Write-Host "`n=== Import Summary ===" -ForegroundColor Green
sqlcmd -S "$ServerInstance" -d "$Database" -E -C -Q @"
SELECT 
    'VTMs (Substances)' as Entity_Type,
    COUNT(*) as Total_Count
FROM vtm
UNION ALL
SELECT 
    'VMPs (Generic Products)',
    COUNT(*)
FROM vmp  
UNION ALL
SELECT
    'AMPs (Branded Products)', 
    COUNT(*)
FROM amp
UNION ALL
SELECT
    'SNOMED Mappings',
    COUNT(*)
FROM dmd_snomed;
"@

Write-Host "`n✅ SNOMED CT Drug import completed!" -ForegroundColor Green