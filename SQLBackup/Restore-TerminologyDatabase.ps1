<#
.SYNOPSIS
    Restores a terminology database from backup.

.DESCRIPTION
    Lists available backup files and restores the selected database.
    Handles file relocation if the original paths don't exist.

.PARAMETER Database
    Database name to restore (snomedct, dmd, DMWB_Export)

.PARAMETER BackupFile
    Specific backup file to restore from. If not provided, shows available backups.

.PARAMETER BackupPath
    Folder containing backup files. Default: O:\OneDrive\Backups\SQL Server Terminology Services

.PARAMETER ServerInstance
    SQL Server instance name. Default: SILENTPRIORY\SQLEXPRESS

.PARAMETER DataPath
    Custom path for database data files. If not provided, uses SQL Server default.

.PARAMETER LogPath
    Custom path for database log files. If not provided, uses SQL Server default.

.PARAMETER Force
    Overwrite existing database without confirmation.

.EXAMPLE
    .\Restore-TerminologyDatabase.ps1 -Database snomedct
    Lists available snomedct backups and prompts for selection

.EXAMPLE
    .\Restore-TerminologyDatabase.ps1 -Database dmd -BackupFile "dmd_20260127_140000.bak"
    Restores specific backup file

.EXAMPLE
    .\Restore-TerminologyDatabase.ps1 -Database snomedct -Force
    Restores latest backup, overwriting existing database
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("snomedct", "dmd", "DMWB_Export")]
    [string]$Database,
    
    [string]$BackupFile,
    [string]$BackupPath = "O:\OneDrive\Backups\SQL Server Terminology Services",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DataPath,
    [string]$LogPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TERMINOLOGY DATABASE RESTORE" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Database:    $Database" -ForegroundColor Gray
Write-Host "Server:      $ServerInstance" -ForegroundColor Gray
Write-Host "Backup Path: $BackupPath" -ForegroundColor Gray
Write-Host ""

# Check if backup folder exists
if (-not (Test-Path $BackupPath)) {
    Write-Host "❌ Backup folder not found: $BackupPath" -ForegroundColor Red
    exit 1
}

# Find available backups for the database
$availableBackups = Get-ChildItem $BackupPath -Filter "${Database}_*.bak" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if (-not $availableBackups) {
    Write-Host "❌ No backup files found for database '$Database'" -ForegroundColor Red
    Write-Host "   Looking for: ${Database}_*.bak in $BackupPath" -ForegroundColor Gray
    exit 1
}

# Select backup file
$selectedBackup = $null

if ($BackupFile) {
    # Use specified backup file
    $selectedBackup = $availableBackups | Where-Object { $_.Name -eq $BackupFile }
    if (-not $selectedBackup) {
        Write-Host "❌ Specified backup file not found: $BackupFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available backups:" -ForegroundColor White
        $availableBackups | Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime | Format-Table -AutoSize
        exit 1
    }
} else {
    # Show available backups and let user choose
    Write-Host "Available backups for '$Database':" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $availableBackups.Count; $i++) {
        $backup = $availableBackups[$i]
        $sizeMB = [math]::Round($backup.Length / 1MB, 1)
        Write-Host "  $($i + 1). $($backup.Name)" -ForegroundColor Yellow
        Write-Host "      Size: $sizeMB MB, Created: $($backup.LastWriteTime)" -ForegroundColor Gray
    }
    
    Write-Host ""
    $selection = Read-Host "Select backup number (1-$($availableBackups.Count)) or press Enter for latest"
    
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $selectedBackup = $availableBackups[0]  # Latest
        Write-Host "Selected latest backup: $($selectedBackup.Name)" -ForegroundColor Green
    } elseif ([int]::TryParse($selection, [ref]$null) -and $selection -ge 1 -and $selection -le $availableBackups.Count) {
        $selectedBackup = $availableBackups[$selection - 1]
        Write-Host "Selected backup: $($selectedBackup.Name)" -ForegroundColor Green
    } else {
        Write-Host "❌ Invalid selection" -ForegroundColor Red
        exit 1
    }
}

$backupFilePath = $selectedBackup.FullName
Write-Host ""
Write-Host "Backup file: $($selectedBackup.Name)" -ForegroundColor White
Write-Host "Size: $([math]::Round($selectedBackup.Length / 1MB, 1)) MB" -ForegroundColor Gray
Write-Host "Created: $($selectedBackup.LastWriteTime)" -ForegroundColor Gray

# Check if database already exists
$existingDb = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT name FROM sys.databases WHERE name = '$Database'" -TrustServerCertificate -ErrorAction SilentlyContinue

if ($existingDb -and -not $Force) {
    Write-Host ""
    Write-Host "⚠️  Database '$Database' already exists!" -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to overwrite it? (y/N)"
    if ($confirm -notmatch '^y|yes$') {
        Write-Host "Restore cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Get logical file names from backup
Write-Host ""
Write-Host "Reading backup file information..." -ForegroundColor White

try {
    $fileList = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "RESTORE FILELISTONLY FROM DISK = '$backupFilePath'" -TrustServerCertificate -ErrorAction Stop
    
    if (-not $fileList) {
        Write-Host "❌ Could not read backup file contents" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Logical files in backup:" -ForegroundColor Gray
    $fileList | Select-Object LogicalName, PhysicalName, Type | Format-Table -AutoSize
    
} catch {
    Write-Host "❌ Error reading backup file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get SQL Server default paths if custom paths not provided
if (-not $DataPath -or -not $LogPath) {
    $defaultPaths = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query @"
SELECT 
    SERVERPROPERTY('InstanceDefaultDataPath') AS DefaultDataPath,
    SERVERPROPERTY('InstanceDefaultLogPath') AS DefaultLogPath
"@ -TrustServerCertificate -ErrorAction Stop

    if (-not $DataPath) { $DataPath = $defaultPaths.DefaultDataPath }
    if (-not $LogPath) { $LogPath = $defaultPaths.DefaultLogPath }
}

# Build RESTORE command with file moves
$restoreQuery = "RESTORE DATABASE [$Database] FROM DISK = '$backupFilePath' WITH REPLACE"

foreach ($file in $fileList) {
    $logicalName = $file.LogicalName
    $extension = if ($file.Type -eq 'D') { '.mdf' } else { '.ldf' }  # Data or Log
    $targetPath = if ($file.Type -eq 'D') { $DataPath } else { $LogPath }
    $physicalName = Join-Path $targetPath "${Database}${extension}"
    
    $restoreQuery += ", MOVE '$logicalName' TO '$physicalName'"
}

$restoreQuery += ", STATS = 25"

Write-Host ""
Write-Host "Restore command:" -ForegroundColor Gray
Write-Host $restoreQuery -ForegroundColor DarkGray
Write-Host ""

# Perform restore
Write-Host "Starting restore of '$Database'..." -ForegroundColor White
$startTime = Get-Date

try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $restoreQuery -QueryTimeout 1800 -TrustServerCertificate -ErrorAction Stop
    
    $duration = (Get-Date) - $startTime
    
    Write-Host ""
    Write-Host "✓ Database '$Database' restored successfully!" -ForegroundColor Green
    Write-Host "  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host "  From: $($selectedBackup.Name)" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "❌ Restore failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green