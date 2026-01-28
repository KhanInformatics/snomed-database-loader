<#
.SYNOPSIS
    Backs up all terminology databases to OneDrive with automatic retention.

.DESCRIPTION
    Creates compressed backups of SNOMED CT, DM+D, and DMWB databases.
    Backups are stored in OneDrive for automatic cloud sync.
    Automatically removes backups older than 4 weeks.

.PARAMETER ServerInstance
    SQL Server instance name. Default: SILENTPRIORY\SQLEXPRESS

.PARAMETER BackupPath
    Destination folder for backups. Default: O:\OneDrive\Backups\SQL Server Terminology Services

.PARAMETER RetentionDays
    Number of days to keep backups. Default: 28 (4 weeks)

.PARAMETER WhatIf
    Preview mode - shows what would be backed up without making changes.

.EXAMPLE
    .\Backup-TerminologyDatabases.ps1
    
.EXAMPLE
    .\Backup-TerminologyDatabases.ps1 -WhatIf
#>

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$BackupPath = "O:\OneDrive\Backups\SQL Server Terminology Services",
    [int]$RetentionDays = 28,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dateStamp = Get-Date -Format "yyyy-MM-dd"

# Databases to backup
$databases = @("snomedct", "dmd", "DMWB_Export")

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TERMINOLOGY DATABASE BACKUP" -ForegroundColor Cyan
Write-Host "  $dateStamp" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server:      $ServerInstance" -ForegroundColor Gray
Write-Host "Destination: $BackupPath" -ForegroundColor Gray
Write-Host "Retention:   $RetentionDays days ($([math]::Round($RetentionDays/7)) weeks)" -ForegroundColor Gray
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF MODE] No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Create backup folder if it doesn't exist
if (-not (Test-Path $BackupPath)) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would create folder: $BackupPath" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        Write-Host "Created backup folder: $BackupPath" -ForegroundColor Green
    }
}

# Backup each database
$results = @()
$totalSize = 0

foreach ($db in $databases) {
    $backupFile = Join-Path $BackupPath "${db}_${timestamp}.bak"
    
    Write-Host "Backing up [$db]..." -ForegroundColor White -NoNewline
    
    if ($WhatIf) {
        Write-Host " [WhatIf] Would backup to $(Split-Path $backupFile -Leaf)" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            Database = $db
            Status = "WhatIf"
            File = Split-Path $backupFile -Leaf
            SizeMB = "-"
            Duration = "-"
        }
        continue
    }
    
    $startTime = Get-Date
    
    try {
        # Check if database exists
        $dbExists = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT name FROM sys.databases WHERE name = '$db'" -TrustServerCertificate -ErrorAction Stop
        
        if (-not $dbExists) {
            Write-Host " SKIPPED (database not found)" -ForegroundColor Yellow
            $results += [PSCustomObject]@{
                Database = $db
                Status = "Skipped"
                File = "-"
                SizeMB = "-"
                Duration = "-"
            }
            continue
        }
        
        # Perform backup (Express Edition doesn't support compression)
        $backupQuery = @"
BACKUP DATABASE [$db] 
TO DISK = '$backupFile'
WITH INIT, 
     STATS = 25,
     NAME = '$db-Full-$dateStamp',
     DESCRIPTION = 'Terminology database backup - $dateStamp'
"@
        
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $backupQuery -QueryTimeout 600 -TrustServerCertificate -ErrorAction Stop
        
        $duration = (Get-Date) - $startTime
        $fileInfo = Get-Item $backupFile
        $sizeMB = [math]::Round($fileInfo.Length / 1MB, 1)
        $totalSize += $fileInfo.Length
        
        Write-Host " OK" -ForegroundColor Green -NoNewline
        Write-Host " ($sizeMB MB in $($duration.ToString('mm\:ss')))" -ForegroundColor Gray
        
        $results += [PSCustomObject]@{
            Database = $db
            Status = "Success"
            File = Split-Path $backupFile -Leaf
            SizeMB = $sizeMB
            Duration = $duration.ToString('mm\:ss')
        }
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            Database = $db
            Status = "Failed"
            File = "-"
            SizeMB = "-"
            Duration = "-"
        }
    }
}

# Cleanup old backups
Write-Host ""
Write-Host "Cleaning up backups older than $RetentionDays days..." -ForegroundColor White

$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
$oldBackups = Get-ChildItem $BackupPath -Filter "*.bak" -ErrorAction SilentlyContinue | 
              Where-Object { $_.LastWriteTime -lt $cutoffDate }

if ($oldBackups) {
    foreach ($oldFile in $oldBackups) {
        if ($WhatIf) {
            Write-Host "  [WhatIf] Would delete: $($oldFile.Name)" -ForegroundColor Yellow
        } else {
            Remove-Item $oldFile.FullName -Force
            Write-Host "  Deleted: $($oldFile.Name)" -ForegroundColor Gray
        }
    }
    if (-not $WhatIf) {
        Write-Host "  Removed $($oldBackups.Count) old backup(s)" -ForegroundColor Green
    }
} else {
    Write-Host "  No old backups to remove" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BACKUP SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize

if (-not $WhatIf) {
    $totalSizeMB = [math]::Round($totalSize / 1MB, 1)
    $totalSizeGB = [math]::Round($totalSize / 1GB, 2)
    Write-Host "Total backup size: $totalSizeMB MB ($totalSizeGB GB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "✓ Backups will sync to OneDrive automatically" -ForegroundColor Cyan
}

# List current backups
Write-Host ""
Write-Host "Current backups in folder:" -ForegroundColor White
$currentBackups = Get-ChildItem $BackupPath -Filter "*.bak" -ErrorAction SilentlyContinue | 
    Sort-Object LastWriteTime -Descending |
    Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime

if ($currentBackups) {
    $currentBackups | Format-Table -AutoSize
} else {
    Write-Host "  No backup files found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green