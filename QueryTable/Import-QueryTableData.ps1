# Import-QueryTableData.ps1
# Imports SNOMED CT UK Query Table and History Substitution Table into SQL Server
# Run after downloading data with Download-QueryTableReleases.ps1

param(
    [string]$Server = "localhost",
    [string]$Database = "snomedct",
    [switch]$CreateTables,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Base paths
$baseDir = "C:\QueryTable"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SNOMED CT UK Query Table Import" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find the latest release folder
$releasesDir = Join-Path $baseDir "CurrentReleases"
$releaseFolder = Get-ChildItem -Path $releasesDir -Directory | 
    Where-Object { $_.Name -match "uk_sctqths" } | 
    Sort-Object Name -Descending | 
    Select-Object -First 1

if (-not $releaseFolder) {
    Write-Error "No Query Table release found in $releasesDir. Run Download-QueryTableReleases.ps1 first."
    exit 1
}

Write-Host "Found release: $($releaseFolder.Name)" -ForegroundColor Green

# Find the Resources folder (varies by release structure)
$resourcesPath = Get-ChildItem -Path $releaseFolder.FullName -Recurse -Directory | 
    Where-Object { $_.Name -eq "Resources" } | 
    Select-Object -First 1

if (-not $resourcesPath) {
    Write-Error "Could not find Resources folder in release"
    exit 1
}

# Find the data files
$queryTableFile = Get-ChildItem -Path $resourcesPath.FullName -Recurse -Filter "xres2_SNOMEDQueryTable*.txt" | Select-Object -First 1
$historySubFile = Get-ChildItem -Path $resourcesPath.FullName -Recurse -Filter "xres2_HistorySubstitutionTable*.txt" | Select-Object -First 1

if (-not $queryTableFile) {
    Write-Error "Query Table file not found"
    exit 1
}

if (-not $historySubFile) {
    Write-Error "History Substitution Table file not found"  
    exit 1
}

Write-Host ""
Write-Host "Data files:" -ForegroundColor Yellow
Write-Host "  Query Table: $($queryTableFile.FullName)"
Write-Host "  History Substitution: $($historySubFile.FullName)"
Write-Host ""

# Escape paths for SQL
$queryTablePath = $queryTableFile.FullName -replace '\\', '\\\\'
$historySubPath = $historySubFile.FullName -replace '\\', '\\\\'

# Create tables if requested
if ($CreateTables) {
    Write-Host "Creating tables..." -ForegroundColor Yellow
    $createScript = Join-Path $scriptDir "create-querytable-tables.sql"
    
    if (-not (Test-Path $createScript)) {
        Write-Error "Table creation script not found: $createScript"
        exit 1
    }
    
    if (-not $WhatIf) {
        sqlcmd -S $Server -d $Database -i $createScript -b
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create tables"
            exit 1
        }
        Write-Host "Tables created successfully" -ForegroundColor Green
    } else {
        Write-Host "[WhatIf] Would run: sqlcmd -S $Server -d $Database -i $createScript" -ForegroundColor Magenta
    }
}

# Generate and run import SQL
$importSql = @"
-- Import SNOMED CT UK Query Table and History Substitution Table
-- Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- Release: $($releaseFolder.Name)

USE [$Database];
GO

SET NOCOUNT ON;
GO

PRINT 'Starting import...';
PRINT '';

-- Import Query Table (Enhanced Transitive Closure)
PRINT 'Importing UK Query Table...';
PRINT 'Source: $($queryTableFile.FullName)';
TRUNCATE TABLE uk_query_table;

BULK INSERT uk_query_table 
FROM '$queryTablePath' 
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = '\t', 
    ROWTERMINATOR = '\n', 
    TABLOCK,
    BATCHSIZE = 500000
);

DECLARE @qt_rows INT = (SELECT COUNT(*) FROM uk_query_table);
PRINT 'Loaded ' + CAST(@qt_rows AS VARCHAR) + ' rows into uk_query_table';
PRINT '';

-- Import History Substitution Table
PRINT 'Importing UK History Substitution Table...';
PRINT 'Source: $($historySubFile.FullName)';
TRUNCATE TABLE uk_history_substitution;

BULK INSERT uk_history_substitution 
FROM '$historySubPath' 
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = '\t', 
    ROWTERMINATOR = '\n', 
    TABLOCK
);

DECLARE @hs_rows INT = (SELECT COUNT(*) FROM uk_history_substitution);
PRINT 'Loaded ' + CAST(@hs_rows AS VARCHAR) + ' rows into uk_history_substitution';
PRINT '';

PRINT '=== Import Complete ===';
GO
"@

# Save import SQL to file
$importSqlFile = Join-Path $scriptDir "import-querytable-data.sql"
$importSql | Out-File -FilePath $importSqlFile -Encoding UTF8
Write-Host "Generated import script: $importSqlFile" -ForegroundColor Green

# Run the import
Write-Host ""
Write-Host "Importing data into SQL Server..." -ForegroundColor Yellow
Write-Host "  Server: $Server"
Write-Host "  Database: $Database"
Write-Host ""

if (-not $WhatIf) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    sqlcmd -S $Server -d $Database -i $importSqlFile -b
    
    $sw.Stop()
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Import failed"
        exit 1
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Import completed in $($sw.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "[WhatIf] Would run: sqlcmd -S $Server -d $Database -i $importSqlFile" -ForegroundColor Magenta
}

Write-Host ""
Write-Host "Sample queries to verify import:" -ForegroundColor Cyan
Write-Host @"

-- Find all descendants of Diabetes mellitus (73211009)
SELECT COUNT(*) AS diabetes_descendants
FROM uk_query_table
WHERE supertypeId = '73211009';

-- Find substitution for an inactive concept
SELECT TOP 10 
    oldConceptId, 
    oldConceptFSN,
    newConceptId, 
    newConceptFSN,
    isAmbiguous
FROM uk_history_substitution
ORDER BY oldConceptId;

"@
