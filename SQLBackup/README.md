# SQL Server Terminology Database Backup Scripts

This folder contains PowerShell scripts for backing up and restoring the terminology databases (SNOMED CT, DM+D, DMWB) with automatic cloud sync via OneDrive.

## Scripts

| Script | Purpose |
|--------|---------|
| `Backup-TerminologyDatabases.ps1` | Main backup script with 4-week retention |
| `Restore-TerminologyDatabase.ps1` | Restore script for disaster recovery |

## Quick Start

### Backup All Databases

```powershell
# Preview what will be backed up
.\Backup-TerminologyDatabases.ps1 -WhatIf

# Run the backup
.\Backup-TerminologyDatabases.ps1
```

### Restore a Database

```powershell
# Show available backups and choose one
.\Restore-TerminologyDatabase.ps1 -Database snomedct

# Restore specific backup file
.\Restore-TerminologyDatabase.ps1 -Database dmd -BackupFile "dmd_20260127_140000.bak"
```

## Configuration

| Setting | Default Value |
|---------|---------------|
| **Server Instance** | `SILENTPRIORY\SQLEXPRESS` |
| **Backup Location** | `O:\OneDrive\Backups\SQL Server Terminology Services` |
| **Retention** | 28 days (4 weeks) |
| **Compression** | Enabled |

## Databases Backed Up

| Database | Description | Approx Size |
|----------|-------------|-------------|
| `snomedct` | SNOMED CT terminology with UK extensions and PCD | ~7 GB |
| `dmd` | DM+D medicines and devices database | ~500 MB |
| `DMWB_Export` | Data Migration Workbench tools and mappings | ~2 GB |

## Backup Features

### Automatic Cloud Sync
- Backups are stored in OneDrive folder
- Files sync to cloud automatically in background
- No additional upload step required

### Retention Management
- Keeps last 4 weeks of backups automatically
- Older backups are deleted during each run
- Configurable retention period

### Compression
- All backups use SQL Server native compression
- Reduces backup size by ~70%
- Total compressed size: ~3-4 GB

### Error Handling
- Checks database existence before backup
- Graceful handling of missing databases
- Detailed error messages and progress reporting

## File Naming Convention

Backup files use the format: `{database}_{timestamp}.bak`

Examples:
- `snomedct_20260127_140000.bak`
- `dmd_20260127_140000.bak`
- `DMWB_Export_20260127_140000.bak`

## Restore Features

### Interactive Selection
- Lists available backups with size and date
- Prompts user to select which backup to restore
- Option to specify exact backup file

### Automatic File Relocation
- Detects logical file names from backup
- Relocates files to current SQL Server paths
- Handles different drive configurations

### Safety Checks
- Warns before overwriting existing databases
- Confirms restore operations
- Validates backup file before proceeding

## Scheduled Backups (Optional)

You can integrate this with the existing weekly automation:

```powershell
# Add to Weekly-TerminologyUpdate.ps1 or run separately
.\SQLBackup\Backup-TerminologyDatabases.ps1
```

Or create a separate scheduled task:

```powershell
# Run backup every Sunday at 6 AM
schtasks /create /tn "Backup Terminology Databases" /tr "PowerShell.exe -File 'O:\GitHub\snomed-database-loader\SQLBackup\Backup-TerminologyDatabases.ps1'" /sc weekly /d SUN /st 06:00
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Database not found" | Check database name spelling and availability |
| "Access denied" | Run PowerShell as Administrator |
| "OneDrive sync slow" | Large files may take time to sync initially |
| "Restore path error" | Check SQL Server service account permissions |

### Log Locations

- **Backup Progress**: Console output with detailed statistics
- **SQL Server Logs**: Check SQL Server Error Log for detailed backup/restore messages
- **OneDrive Sync**: OneDrive activity center shows sync progress

## Storage Requirements

### Local Storage (O: Drive)
- **Current**: ~300 GB free (sufficient)
- **Used by backups**: ~12-16 GB (4 weeks × 3-4 GB)

### OneDrive Storage
- **Personal OneDrive**: 1 TB+ recommended for terminology backups
- **OneDrive for Business**: Usually sufficient with organizational quota

## Security Notes

- Backups contain NHS terminology data
- OneDrive provides encryption in transit and at rest  
- Consider using OneDrive for Business for organizational data
- Regular backup testing recommended

---

**Last Updated**: January 27, 2026  
**Repository**: [snomed-database-loader](https://github.com/KhanInformatics/snomed-database-loader)