# NHS Data Migration Workbench (DMWB) Loader

This directory provides automated scripts for downloading and managing the **NHS Data Migration Workbench (DMWB)** from NHS TRUD.

## What is Data Migration Workbench?

The NHS Data Migration Workbench is a tool provided by NHS Digital to assist with migrating clinical data between different systems while maintaining SNOMED CT terminology standards. It provides mapping tools, validation utilities, and reference data to ensure accurate data migration.

## Features

- ✅ Automated download of DMWB releases from TRUD
- ✅ Release version tracking and update detection
- ✅ Complete workflow automation
- ✅ Integration with existing SNOMED CT and DM+D workflows

## Prerequisites

### 1. TRUD API Access
- Register for a TRUD account at [https://isd.digital.nhs.uk/trud](https://isd.digital.nhs.uk/trud)
- Generate an API key from your TRUD profile
- Store your API key in Windows Credential Manager:
  ```powershell
  # Install CredentialManager module if not already installed
  Install-Module -Name CredentialManager -Force
  
  # Store your TRUD API key
  New-StoredCredential -Target "TRUD_API" -UserName "TRUD_API" -Password "your-api-key-here" -Persist LocalMachine
  ```

### 2. Directory Structure
The scripts expect the following directory structure (automatically created):
```
C:\DMWB\
├── Downloads\          # Temporary download location
├── CurrentReleases\    # Extracted DMWB files
└── last_checked_releases.json  # Release tracking
```

## Scripts Overview

### Check-NewDMWBRelease.ps1
Checks TRUD API for new Data Migration Workbench releases.

**Usage:**
```powershell
.\Check-NewDMWBRelease.ps1
```

**Features:**
- Queries TRUD API for latest release information
- Compares with previously tracked release
- Displays release details and update status
- Updates tracking file for future checks

**Example Output:**
```
=== Data Migration Workbench Release Check - 2025-12-27 14:30:00 ===

Checking NHS Data Migration Workbench (Item: 98)...
  Latest Release: NHS Data Migration Workbench Release 2024.1
  Release Date: 2024-10-15 00:00:00
  File: dmwb_2024.1.zip
  ⭐ NEW RELEASE DETECTED!

=== Summary ===
New releases are available! Run Download-DMWBReleases.ps1 to download them.
```

### Download-DMWBReleases.ps1
Downloads the latest Data Migration Workbench release from TRUD.

**Usage:**
```powershell
.\Download-DMWBReleases.ps1
```

**Process:**
1. Authenticates with TRUD API using stored credentials
2. Queries for latest DMWB release (Item 98)
3. Downloads the release ZIP file
4. Extracts contents to temporary folder
5. Moves extracted files to `C:\DMWB\CurrentReleases\`
6. Cleans up temporary files

**Example Output:**
```
Script base directory: C:\DMWB
Querying TRUD API for NHS_DMWB (item number 98)...
Latest release for NHS_DMWB: NHS Data Migration Workbench Release 2024.1 released on 2024-10-15
Downloading dmwb_2024.1.zip...
Downloaded file saved to: C:\DMWB\Downloads\dmwb_2024.1.zip
Unzipping to extract folder...
Moved to: C:\DMWB\CurrentReleases\dmwb_2024.1

✅ Data Migration Workbench release downloaded, extracted, and moved to CurrentReleases.
Next step: The DMWB tools are ready to use in: C:\DMWB\CurrentReleases
```

### Complete-DMWBWorkflow.ps1
Complete end-to-end workflow for checking and downloading DMWB releases.

**Usage:**
```powershell
.\Complete-DMWBWorkflow.ps1
```

**Process:**
1. Checks for new releases
2. Prompts user to download if updates are available
3. Downloads and extracts latest release
4. Displays completion summary

## Quick Start

### First Time Setup
```powershell
# 1. Store your TRUD API key
Install-Module -Name CredentialManager -Force
New-StoredCredential -Target "TRUD_API" -UserName "TRUD_API" -Password "your-api-key-here" -Persist LocalMachine

# 2. Download latest DMWB release
cd O:\GitHub\snomed-database-loader\DMWB
.\Download-DMWBReleases.ps1
```

### Regular Updates
```powershell
# Check for and download new releases
.\Complete-DMWBWorkflow.ps1
```

### Manual Workflow
```powershell
# Step 1: Check for new releases
.\Check-NewDMWBRelease.ps1

# Step 2: If new release available, download it
.\Download-DMWBReleases.ps1
```

## Integration with Other Workflows

The DMWB can be used alongside SNOMED CT and DM+D databases:

```powershell
# Complete setup of all terminologies
cd ..\MSSQL
.\Complete-SnomedWorkflow.ps1

cd ..\DMD
.\Complete-DMDWorkflow.ps1

cd ..\DMWB
.\Complete-DMWBWorkflow.ps1
```

## File Locations

After running the download script:
- **Downloaded Tools**: `C:\DMWB\CurrentReleases\`
- **Release Tracking**: `C:\DMWB\last_checked_releases.json`
- **Download Cache**: `C:\DMWB\Downloads\` (cleaned automatically)

## TRUD Item Reference

- **Item Number**: 98
- **Name**: NHS Data Migration Workbench
- **URL**: https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/categories/7/items/98/releases

## Troubleshooting

### API Key Issues
```powershell
# Verify stored credential
Get-StoredCredential -Target "TRUD_API"

# Re-store credential if needed
New-StoredCredential -Target "TRUD_API" -UserName "TRUD_API" -Password "your-api-key-here" -Persist LocalMachine
```

### Permission Issues
- Ensure you have write permissions to `C:\DMWB\`
- Run PowerShell as Administrator if needed

### Network Issues
- Verify internet connectivity
- Check firewall settings for TRUD API access
- Verify TRUD API key is valid and active

## Support and Documentation

- **TRUD Website**: https://isd.digital.nhs.uk/trud
- **DMWB Documentation**: Included in downloaded release
- **Main Repository**: [snomed-database-loader](https://github.com/KhanInformatics/snomed-database-loader)

## License

This project follows the same license as the main repository. The NHS Data Migration Workbench itself is provided under NHS Digital licensing terms.
