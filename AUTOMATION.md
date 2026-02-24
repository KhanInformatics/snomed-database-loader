# Automated Weekly Terminology Updates

This document describes the automated update system for **SNOMED CT**, **DM+D**, **Data Migration Workbench (DMWB)**, and **Primary Care Domain (PCD)** databases from NHS TRUD.

## Overview

The automation system provides unattended weekly updates for all four terminology workstreams with:
- ✅ Automatic new release detection via TRUD API
- ✅ Secure credential storage in Windows Credential Manager
- ✅ Full data validation after each import
- ✅ DMWB Access database export to SQL Server (46 tables, 53M+ rows)
- ✅ PCD reference set validation against source files
- ✅ HTML email reports with detailed statistics
- ✅ Azure SQL and Blob Storage reporting dashboards
- ✅ Comprehensive logging for audit and troubleshooting

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WEEKLY TERMINOLOGY UPDATE SYSTEM                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌──────────────────────────────────────────────────────┐
│  Task Scheduler │────▶│          Weekly-TerminologyUpdate.ps1                │
│  (Saturday 12PM)│     │              Main Orchestrator                       │
└─────────────────┘     └──────────────────────────────────────────────────────┘
                                            │
            ┌───────────────┬───────────────┼───────────────┬───────────────┐
            ▼               ▼               │               ▼               ▼
 ┌────────────────┐ ┌────────────────┐      │   ┌────────────────┐ ┌────────────────┐
 │  SNOMED CT     │ │    DMD         │      │   │    DMWB        │ │    PCD         │
 │  Phase         │ │    Phase       │      │   │    Phase       │ │    Phase       │
 │                │ │                │      │   │                │ │                │
 │ 1. Check TRUD  │ │ 1. Check TRUD  │      │   │ 1. Check TRUD  │ │ 1. Validate    │
 │ 2. Download    │ │ 2. Download    │      │   │    (Item 98)   │ │    5 PCD tables│
 │ 3. Import      │ │ 3. Import      │      │   │ 2. Download    │ │ 2. Compare vs  │
 │    (BULK INS.) │ │    (XML→SQL)   │      │   │ 3. Export to   │ │    source files│
 │ 4. Validate    │ │ 4. Validate    │      │   │    SQL Server  │ │ 3. Report      │
 │    (Row counts)│ │    (XML vs DB) │      │   │    (46 tables) │ │    validation  │
 │                │ │ 5. Cross-valid.│      │   │ 4. Validate    │ │    rate        │
 │                │ │    (DMD↔SNOMED)│      │   │    table counts│ │                │
 └───────┬────────┘ └───────┬────────┘      │   └───────┬────────┘ └───────┬────────┘
         │                  │               │           │                  │
         └──────────┬───────┴───────────────┴───────────┴──────────────────┘
                    ▼
  ┌──────────────────────────────────────┐
  │         Results Aggregation          │
  │  • Table counts & changes            │
  │  • Validation statistics             │
  │  • DMWB export summary              │
  │  • PCD validation rate              │
  │  • Error collection                  │
  └─────────────────┬────────────────────┘
                    ▼
  ┌──────────────────────────────────────┐
  │      Reporting & Notifications       │
  │                                      │
  │  ┌────────────────────────────────┐  │
  │  │ Send-UpdateReport.ps1         │  │
  │  │ • HTML email with all results │  │
  │  │ • Color-coded status          │  │
  │  │ • DMWB & PCD sections         │  │
  │  └────────────────────────────────┘  │
  │  ┌────────────────────────────────┐  │
  │  │ Export-ReportToBlob.ps1       │  │
  │  │ • JSON dashboard to Azure Blob│  │
  │  │ • SNOMED/DMD/DMWB/PCD data    │  │
  │  └────────────────────────────────┘  │
  │  ┌────────────────────────────────┐  │
  │  │ Export-ReportToAzure.ps1      │  │
  │  │ • Azure SQL reporting tables  │  │
  │  │ • dmwb_updates table          │  │
  │  │ • pcd_validations table       │  │
  │  └────────────────────────────────┘  │
  └─────────────────┬────────────────────┘
                    ▼
  ┌──────────────────────────────────────┐
  │              Log File                │
  │   C:\TerminologyLogs\WeeklyUpdate_  │
  │      YYYYMMDD_HHMMSS.log            │
  └──────────────────────────────────────┘
```

---

## Process Flow Diagram

```
                                    START
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │   Load Configuration   │
                         │ Config/TerminologyConfig│
                         └───────────┬────────────┘
                                     │
                         ┌───────────▼────────────┐
                         │   Initialize Logging   │
                         │   Create log file      │
                         └───────────┬────────────┘
                                     │
     ┌───────────────────┬───────────┼───────────┬───────────────────┐
     │                   │           │           │                   │
     ▼                   ▼           │           ▼                   ▼
┌──────────┐      ┌──────────┐      │    ┌──────────┐       ┌──────────┐
│  Skip    │─YES─▶│  Skip    │─YES─▶│    │  Skip    │─YES──▶│  Skip    │─YES─┐
│ SNOMED?  │      │  DMD?    │      │    │  DMWB?   │       │  PCD?    │     │
└────┬─────┘      └────┬─────┘      │    └────┬─────┘       └────┬─────┘     │
     │ NO              │ NO         │         │ NO               │ NO        │
     ▼                 ▼            │         ▼                  ▼           │
┌─────────────┐ ┌─────────────┐    │  ┌─────────────┐   ┌──────────────┐   │
│ Check SNOMED│ │  Check DMD  │    │  │  Check DMWB │   │ Validate PCD │   │
│ TRUD API    │ │  TRUD API   │    │  │  TRUD API   │   │ 5 tables     │   │
└──────┬──────┘ └──────┬──────┘    │  └──────┬──────┘   │ vs source    │   │
       │               │           │         │          │ files        │   │
       ▼               ▼           │         ▼          └──────┬───────┘   │
┌─────────────┐ ┌─────────────┐    │  ┌─────────────┐         │           │
│ New Release │ │ New Release │    │  │ New Release │         │           │
│ OR Force?   │ │ OR Force?   │    │  │ OR Force?   │         │           │
└──────┬──────┘ └──────┬──────┘    │  └──────┬──────┘         │           │
  YES  │  NO      YES  │  NO      │    YES  │  NO            │           │
       │  │            │  │       │         │  │             │           │
       ▼  │            ▼  │       │         ▼  │             │           │
┌────────┐│     ┌────────┐│       │  ┌────────┐│             │           │
│Download││     │Download││       │  │Download││             │           │
│SNOMED  ││     │DMD     ││       │  │DMWB    ││             │           │
└───┬────┘│     └───┬────┘│       │  └───┬────┘│             │           │
    │     │         │     │       │      │     │             │           │
    ▼     │         ▼     │       │      ▼     │             │           │
┌────────┐│     ┌────────┐│       │  ┌────────┐│             │           │
│Import  ││     │Import  ││       │  │Export  ││             │           │
│SNOMED  ││     │DMD     ││       │  │to SQL  ││             │           │
└───┬────┘│     └───┬────┘│       │  │Server  ││             │           │
    │     │         │     │       │  │46 tbls ││             │           │
    ▼     │         ▼     │       │  └───┬────┘│             │           │
┌────────┐│     ┌────────┐│       │      │     │             │           │
│Validate││     │Validate││       │      ▼     │             │           │
│SNOMED  ││     │DMD     ││       │  ┌────────┐│             │           │
└───┬────┘│     └───┬────┘│       │  │Validate││             │           │
    │     │         │     │       │  │Counts  ││             │           │
    │     │         ▼     │       │  └───┬────┘│             │           │
    │     │     ┌────────┐│       │      │     │             │           │
    │     │     │Cross-  ││       │      │     │             │           │
    │     │     │validate││       │      │     │             │           │
    │     │     │DMD↔SCT ││       │      │     │             │           │
    │     │     └───┬────┘│       │      │     │             │           │
    │     │         │     │       │      │     │             │           │
    └──┬──┴─────────┴──┬──┘       └──────┴──┬──┴─────────────┴───────────┘
       │               │                    │
       └───────────────┴────────────────────┘
                       │
                       ▼
            ┌─────────────────────┐
            │  Aggregate Results  │
            │  - Success/Failure  │
            │  - Table statistics │
            │  - DMWB export info │
            │  - PCD validation   │
            │  - Error summary    │
            └──────────┬──────────┘
                       │
                       ▼
            ┌─────────────────────┐
            │ Notifications       │───── NO ──────┐
            │   Enabled?          │               │
            └──────────┬──────────┘               │
                       │ YES                      │
                       ▼                          │
            ┌─────────────────────┐               │
            │  Send HTML Email    │               │
            │  via SMTP           │               │
            └──────────┬──────────┘               │
                       │                          │
                       ▼                          │
            ┌─────────────────────┐               │
            │ Export to Azure     │               │
            │ • Blob (JSON)       │               │
            │ • SQL (tables)      │               │
            └──────────┬──────────┘               │
                       │                          │
                       └────────────┬─────────────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │  Write Log File │
                          │  Exit with code │
                          └─────────────────┘
                                    │
                                    ▼
                                  END
```

---

## File Structure

```
snomed-database-loader/
├── Weekly-TerminologyUpdate.ps1    # Main orchestrator script
├── Install-WeeklyUpdateTask.ps1    # Task Scheduler installer (Run as Admin)
├── Send-UpdateReport.ps1           # Email notification module
├── Export-ReportToBlob.ps1         # Azure Blob Storage JSON export
├── Export-ReportToAzure.ps1        # Azure SQL reporting export
├── Validate-OntologyServer.ps1     # NHS Ontology Server validation
├── AUTOMATION.md                   # This documentation
│
├── Config/                         # Configuration files
│   ├── TerminologyConfig.json      # Central configuration
│   └── Terminologysettings.json    # NHS Ontology Server credentials
│
├── MSSQL/                          # SNOMED CT scripts
│   ├── Check-NewRelease.ps1        # Check TRUD for new releases
│   ├── Download-SnomedReleases.ps1 # Download from TRUD
│   ├── Generate-AndRun-AllSnapshots.ps1  # Import to SQL Server
│   ├── Load-PCD-Refset-Content.ps1 # Import PCD reference sets
│   ├── Quick-PCD-Validation.ps1    # Validate PCD imports
│   └── Validate-PCD-Import.ps1     # Full PCD validation
│
├── DMD/                            # DM+D scripts
│   ├── Check-NewDMDRelease.ps1     # Check TRUD for new releases
│   ├── Download-DMDReleases.ps1    # Download from TRUD
│   ├── Validate-RandomSamples.ps1  # Validate XML vs DB
│   └── StandaloneImports/
│       └── Run-AllImports.ps1      # Import all DMD data
│
├── DMWB/                           # Data Migration Workbench scripts
│   ├── Check-NewDMWBRelease.ps1    # Check TRUD for new releases (Item 98)
│   ├── Download-DMWBReleases.ps1   # Download from TRUD
│   ├── Export-DmwbToSqlServer.ps1  # Export Access → SQL Server (46 tables)
│   ├── Complete-DMWBWorkflow.ps1   # End-to-end workflow
│   └── Test-DMWBExport.ps1         # Validate SQL Server export
│
└── BlazorApi/                      # Dashboard & reporting
    ├── TerminologyDashboard.razor   # Azure SQL dashboard
    └── TerminologyDashboardBlob.razor # Blob Storage dashboard
```

---

## Configuration

### Config/TerminologyConfig.json

```json
{
    "paths": {
        "snomedBase": "C:\\SNOMEDCT",      // SNOMED CT downloads
        "dmdBase": "C:\\DMD",               // DMD downloads
        "dmwbBase": "C:\\DMWB",             // DMWB downloads
        "logsBase": "C:\\TerminologyLogs"   // Log files
    },
    "database": {
        "serverInstance": "SERVER\\INSTANCE",
        "snomedDatabase": "snomedct",
        "dmdDatabase": "dmd",
        "dmwbDatabase": "DMWB_Export"
    },
    "trudItems": {
        "snomedMonolith": 1799,
        "snomedUkPrimaryCare": 659,
        "snomedUkDrugExtension": 105,
        "snomedInternational": 4,
        "dmdMain": 24,
        "dmdBonus": 25,
        "dmwb": 98
    },
    "credentials": {
        "trudApiTarget": "TRUD_API"         // Windows Credential Manager
    },
    "validation": {
        "dmdSamplesPerTable": 100,          // Random samples per table
        "validateAgainstLocalSnomed": true  // Cross-validate DMD → SNOMED
    },
    "notifications": {
        "enabled": true,
        "smtpServer": "smtp.your-server.com",
        "smtpPort": 587,
        "smtpUseSsl": true,
        "fromAddress": "terminology@your-domain.com",
        "toAddresses": ["admin@your-domain.com"]
    },
    "azureReporting": {
        "enabled": true,
        "blobConnectionTarget": "AZURE_BLOB_CONN",
        "sqlConnectionString": "Server=your-server.database.windows.net;..."
    },
    "schedule": {
        "dayOfWeek": "Saturday",
        "timeOfDay": "12:00"
    }
}
```

### Setting Up Credentials

```powershell
# Store TRUD API key in Windows Credential Manager
$cred = Get-Credential -UserName "TRUD_API" -Message "Enter TRUD API Key as password"
New-StoredCredential -Target "TRUD_API" -Credential $cred -Type Generic -Persist LocalMachine

# (Optional) Store SMTP credentials for email
$smtp = Get-Credential -Message "SMTP username and password"
New-StoredCredential -Target "SMTP_CREDENTIALS" -Credential $smtp -Type Generic -Persist LocalMachine
```

---

## Usage

### Manual Execution

```powershell
# Full update with notifications
.\Weekly-TerminologyUpdate.ps1

# Preview mode (no changes)
.\Weekly-TerminologyUpdate.ps1 -WhatIf

# Force update even if no new release
.\Weekly-TerminologyUpdate.ps1 -Force

# Skip email notification
.\Weekly-TerminologyUpdate.ps1 -SkipNotification

# Update only DMD
.\Weekly-TerminologyUpdate.ps1 -SkipSNOMED -SkipDMWB -SkipPCD

# Update only SNOMED CT
.\Weekly-TerminologyUpdate.ps1 -SkipDMD -SkipDMWB -SkipPCD

# Update only DMWB
.\Weekly-TerminologyUpdate.ps1 -SkipSNOMED -SkipDMD -SkipPCD

# Validate PCD only
.\Weekly-TerminologyUpdate.ps1 -SkipSNOMED -SkipDMD -SkipDMWB

# Skip DMWB and PCD (original SNOMED + DMD only)
.\Weekly-TerminologyUpdate.ps1 -SkipDMWB -SkipPCD
```

### Scheduled Execution

```powershell
# Install as Windows Scheduled Task (requires Admin)
.\Install-WeeklyUpdateTask.ps1

# Or with custom schedule
.\Install-WeeklyUpdateTask.ps1 -DayOfWeek Tuesday -TimeOfDay "06:00"
```

---

## Validation Process

### DMD Validation (Two-Stage)

**Stage 1: XML vs Database Comparison**
- Randomly samples records from each table
- Compares field values between XML source and database
- Reports match/mismatch statistics

**Stage 2: SNOMED CT Cross-Reference**
- Verifies DMD concept IDs exist in local SNOMED CT database
- Checks UK Drug Extension is properly loaded
- Reports active/inactive concept status

### SNOMED CT Validation
- Verifies row counts in all imported tables
- Compares with expected counts from release notes
- Validates referential integrity

---

## Output and Reporting

### Console Output

```
===============================================================================
   Weekly Terminology Update
   Started: 2026-01-23 12:00:00
===============================================================================

  [SNOMED CT Update]
  ───────────────────────────────────────────────────────────────────────────
    [Check for new release]                                            [OK]
    [Import to database]                                               [OK]
    [Validate import]                                                  [OK]

  [DMD Update]
  ───────────────────────────────────────────────────────────────────────────
    [Check for new release]                                            [OK]
    [Download release files]                                           [OK]
    [Import to database]                                               [OK]
    [Validate against XML source]                                      [OK]
    [Validate against SNOMED CT]                                       [OK]

  [DMWB Update]
  ───────────────────────────────────────────────────────────────────────────
    [Check for new release]                                            [OK]
    [Download release files]                                           [OK]
    [Export to SQL Server]                                             [OK]
    [Validate table counts]                                            [OK]

  [PCD Refset Validation]
  ───────────────────────────────────────────────────────────────────────────
    [Validate PCD tables]                                              [OK]
    [Compare against source files]                                     [OK]

===============================================================================
   SUMMARY
===============================================================================
  Duration:       00:55:00
  Updates Found:  3
  DMWB Tables:    46 (53,431,533 total rows)
  PCD Validation: 5/5 tables passed (100%)
  Overall Status: SUCCESS

Log file: C:\TerminologyLogs\WeeklyUpdate_20260123_120000.log
```

### Email Report

The HTML email report includes:
- ✅ Color-coded status (green=success, red=failure)
- 📊 Table row counts with change indicators (+/-)
- 📝 Detailed step-by-step execution log for all phases
- 🗄️ DMWB export summary (tables exported, total rows, release info)
- 🔍 PCD validation summary (tables checked, validation rate %)
- ⚠️ Error messages if any step failed

### Azure Reporting

Results are also exported to Azure for dashboard access:

**Azure Blob Storage** (`Export-ReportToBlob.ps1`):
- JSON dashboard file with SNOMED, DMD, DMWB, and PCD objects
- Stored in `terminology-reports/terminology-dashboard.json`
- Used by Blazor dashboard components

**Azure SQL** (`Export-ReportToAzure.ps1`):
- `update_runs` - Overall run summary
- `update_steps` - Individual step details (all terminology types)
- `snomed_updates` - SNOMED CT-specific metrics
- `dmd_updates` - DM+D-specific metrics
- `dmwb_updates` - DMWB export metrics (tables, rows, release info)
- `pcd_validations` - PCD validation metrics (tables checked, pass rate)

### Log Files

Located in: `C:\TerminologyLogs\WeeklyUpdate_YYYYMMDD_HHMMSS.log`

Contains:
- Full console output
- Detailed error messages
- Timestamps for each step
- Configuration used

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "TRUD_API credential not found" | Run credential setup command above |
| "SQL Server connection failed" | Check serverInstance in config |
| "Download failed" | Verify internet connectivity and TRUD API key |
| "Import failed" | Check database permissions and disk space |
| "Email not sent" | Verify SMTP settings and credentials |
| "DMWB export failed" | Ensure Access Database Engine (32-bit) is installed |
| "DMWB export timeout" | Export takes ~50 mins for 53M+ rows; increase terminal timeout |
| "PCD tables missing" | Run `Load-PCD-Refset-Content.ps1` in MSSQL/ first |
| "PCD source files not found" | Ensure PCD .txt files exist in `C:\SNOMEDCT\Downloads\` |

### Manual Recovery

If an automated run fails:

```powershell
# Re-run with verbose output
.\Weekly-TerminologyUpdate.ps1 -Force -Verbose

# Check the log file for details
Get-Content "C:\TerminologyLogs\WeeklyUpdate_*.log" | Select-Object -Last 100

# Run individual components manually
cd MSSQL
.\Check-NewRelease.ps1 -Verbose
.\Download-SnomedReleases.ps1 -Verbose
.\Generate-AndRun-AllSnapshots.ps1

cd ..\DMD
.\Check-NewDMDRelease.ps1 -Verbose
.\Download-DMDReleases.ps1 -Verbose
cd StandaloneImports
.\Run-AllImports.ps1 -ServerInstance "YOUR_SERVER"

# DMWB manual recovery
cd ..\..\DMWB
.\Check-NewDMWBRelease.ps1
.\Download-DMWBReleases.ps1
.\Export-DmwbToSqlServer.ps1 -ServerInstance "YOUR_SERVER" -DatabaseName "DMWB_Export"

# PCD manual recovery
cd ..\MSSQL
.\Load-PCD-Refset-Content.ps1
.\Quick-PCD-Validation.ps1
```

---

## Release Schedule

| Terminology | Update Frequency | Typical Release Day |
|-------------|------------------|---------------------|
| **DM+D** | Weekly | Monday 4:00 AM |
| **SNOMED CT UK Clinical** | 6 monthly | January, July |
| **SNOMED CT UK Drug Ext** | Monthly | Mid-month |
| **UK Primary Care** | Quarterly | Variable |
| **DMWB** | Annually | Variable |
| **PCD Refsets** | Quarterly | With QOF cycle changes |

**Recommended Schedule:** Run weekly on Saturday at 12:00 PM to catch all updates including DM+D releases.

---

## Security Considerations

- ✅ Credentials stored in Windows Credential Manager (encrypted)
- ✅ No plaintext passwords in scripts or config files
- ✅ SQL Server uses Windows Authentication
- ✅ SMTP supports TLS encryption
- ✅ Log files contain no sensitive data

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-23 | Initial automated update system |
| | | - Unified orchestrator for SNOMED CT + DMD |
| | | - HTML email notifications |
| | | - Two-stage DMD validation |
| | | - Windows Task Scheduler integration |
| 2.0.0 | 2026-06-28 | DMWB and PCD integration |
| | | - Added DMWB update phase (check, download, export, validate) |
| | | - Added PCD refset validation phase |
| | | - New `-SkipDMWB` and `-SkipPCD` parameters |
| | | - DMWB Access database export to SQL Server (46 tables, 53M+ rows) |
| | | - PCD validation against source files (5 tables) |
| | | - Azure Blob Storage JSON dashboard export |
| | | - Azure SQL reporting tables (dmwb_updates, pcd_validations) |
| | | - Updated email report with DMWB and PCD sections |
