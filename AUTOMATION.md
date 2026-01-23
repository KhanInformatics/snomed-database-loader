# Automated Weekly Terminology Updates

This document describes the automated update system for SNOMED CT and DM+D databases from NHS TRUD.

## Overview

The automation system provides unattended weekly updates for both terminology databases with:
- ✅ Automatic new release detection via TRUD API
- ✅ Secure credential storage in Windows Credential Manager
- ✅ Full data validation after each import
- ✅ HTML email reports with detailed statistics
- ✅ Comprehensive logging for audit and troubleshooting

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WEEKLY TERMINOLOGY UPDATE SYSTEM                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌──────────────────────────────────────────────────────┐
│  Task Scheduler │────▶│          Weekly-TerminologyUpdate.ps1                │
│  (Monday 5 AM)  │     │              Main Orchestrator                       │
└─────────────────┘     └──────────────────────────────────────────────────────┘
                                            │
                        ┌───────────────────┴───────────────────┐
                        ▼                                       ▼
         ┌──────────────────────────┐            ┌──────────────────────────┐
         │     SNOMED CT Phase      │            │       DMD Phase          │
         │                          │            │                          │
         │  ┌────────────────────┐  │            │  ┌────────────────────┐  │
         │  │ 1. Check Release   │  │            │  │ 1. Check Release   │  │
         │  │    (TRUD API)      │  │            │  │    (TRUD API)      │  │
         │  └─────────┬──────────┘  │            │  └─────────┬──────────┘  │
         │            ▼             │            │            ▼             │
         │  ┌────────────────────┐  │            │  ┌────────────────────┐  │
         │  │ 2. Download        │  │            │  │ 2. Download        │  │
         │  │    (if new)        │  │            │  │    (if new)        │  │
         │  └─────────┬──────────┘  │            │  └─────────┬──────────┘  │
         │            ▼             │            │            ▼             │
         │  ┌────────────────────┐  │            │  ┌────────────────────┐  │
         │  │ 3. Import          │  │            │  │ 3. Import          │  │
         │  │    (BULK INSERT)   │  │            │  │    (XML → SQL)     │  │
         │  └─────────┬──────────┘  │            │  └─────────┬──────────┘  │
         │            ▼             │            │            ▼             │
         │  ┌────────────────────┐  │            │  ┌────────────────────┐  │
         │  │ 4. Validate        │  │            │  │ 4. Validate        │  │
         │  │    (Row counts)    │  │            │  │    (XML vs DB)     │  │
         │  └────────────────────┘  │            │  └────────────────────┘  │
         │                          │            │            ▼             │
         │                          │            │  ┌────────────────────┐  │
         │                          │            │  │ 5. Cross-validate  │  │
         │                          │            │  │    (DMD ↔ SNOMED)  │  │
         │                          │            │  └────────────────────┘  │
         └────────────┬─────────────┘            └────────────┬─────────────┘
                      │                                       │
                      └───────────────────┬───────────────────┘
                                          ▼
                        ┌──────────────────────────────────────┐
                        │         Results Aggregation          │
                        │  • Table counts & changes            │
                        │  • Validation statistics             │
                        │  • Error collection                  │
                        └─────────────────┬────────────────────┘
                                          ▼
                      ┌────────────────────────────────────────┐
                      │         Send-UpdateReport.ps1          │
                      │  • HTML email with results             │
                      │  • Color-coded status indicators       │
                      │  • Detailed step-by-step summary       │
                      └────────────────────────────────────────┘
                                          │
                                          ▼
                      ┌────────────────────────────────────────┐
                      │              Log File                  │
                      │   C:\TerminologyLogs\WeeklyUpdate_     │
                      │      YYYYMMDD_HHMMSS.log               │
                      └────────────────────────────────────────┘
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
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          │                          ▼
   ┌─────────────┐                   │                  ┌─────────────┐
   │ Skip SNOMED │───── YES ─────────┼──────────────────│  Skip DMD   │
   │     ?       │                   │                  │     ?       │
   └──────┬──────┘                   │                  └──────┬──────┘
          │ NO                       │                         │ NO
          ▼                          │                         ▼
   ┌─────────────────┐               │               ┌─────────────────┐
   │  Check SNOMED   │               │               │   Check DMD     │
   │  TRUD API       │               │               │   TRUD API      │
   └────────┬────────┘               │               └────────┬────────┘
            │                        │                        │
            ▼                        │                        ▼
   ┌─────────────────┐               │               ┌─────────────────┐
   │ New Release OR  │               │               │ New Release OR  │
   │    Force?       │               │               │    Force?       │
   └────────┬────────┘               │               └────────┬────────┘
            │                        │                        │
       YES  │  NO                    │                   YES  │  NO
            │   │                    │                        │   │
            ▼   │                    │                        ▼   │
   ┌─────────────┴───┐               │               ┌─────────────┴───┐
   │ Download SNOMED │               │               │  Download DMD   │
   │ - Monolith      │               │               │  - Main release │
   │ - UK PrimaryCare│               │               │  - Bonus data   │
   │ - UK Drug Ext   │               │               └────────┬────────┘
   └────────┬────────┘               │                        │
            │                        │                        ▼
            ▼                        │               ┌─────────────────┐
   ┌─────────────────┐               │               │   Import DMD    │
   │  Import SNOMED  │               │               │ Run-AllImports  │
   │ Generate-AndRun │               │               │   (~5 mins)     │
   │ -AllSnapshots   │               │               └────────┬────────┘
   └────────┬────────┘               │                        │
            │                        │                        ▼
            ▼                        │               ┌─────────────────┐
   ┌─────────────────┐               │               │ Validate DMD    │
   │ Validate SNOMED │               │               │ Random samples  │
   │ (Row counts)    │               │               │ vs XML source   │
   └────────┬────────┘               │               └────────┬────────┘
            │                        │                        │
            │                        │                        ▼
            │                        │               ┌─────────────────┐
            │                        │               │Cross-validate   │
            │                        │               │DMD → SNOMED CT  │
            │                        │               │(verify concepts)│
            │                        │               └────────┬────────┘
            │                        │                        │
            └───────────┬────────────┴────────────────────────┘
                        │
                        ▼
             ┌─────────────────────┐
             │  Aggregate Results  │
             │  - Success/Failure  │
             │  - Table statistics │
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
│   └── Generate-AndRun-AllSnapshots.ps1  # Import to SQL Server
│
└── DMD/                            # DM+D scripts
    ├── Check-NewDMDRelease.ps1     # Check TRUD for new releases
    ├── Download-DMDReleases.ps1    # Download from TRUD
    ├── Validate-RandomSamples.ps1  # Validate XML vs DB
    └── StandaloneImports/
        └── Run-AllImports.ps1      # Import all DMD data
```

---

## Configuration

### Config/TerminologyConfig.json

```json
{
    "paths": {
        "snomedBase": "C:\\SNOMEDCT",      // SNOMED CT downloads
        "dmdBase": "C:\\DMD",               // DMD downloads  
        "logsBase": "C:\\TerminologyLogs"   // Log files
    },
    "database": {
        "serverInstance": "SERVER\\INSTANCE",
        "snomedDatabase": "snomedct",
        "dmdDatabase": "dmd"
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
    "schedule": {
        "dayOfWeek": "Monday",
        "timeOfDay": "05:00"
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
.\Weekly-TerminologyUpdate.ps1 -SkipSNOMED

# Update only SNOMED CT
.\Weekly-TerminologyUpdate.ps1 -SkipDMD
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
   Started: 2026-01-23 05:00:00
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

===============================================================================
   SUMMARY
===============================================================================
  Duration:       00:08:45
  Updates Found:  2
  Overall Status: SUCCESS

Log file: C:\TerminologyLogs\WeeklyUpdate_20260123_050000.log
```

### Email Report

The HTML email report includes:
- ✅ Color-coded status (green=success, red=failure)
- 📊 Table row counts with change indicators (+/-)
- 📝 Detailed step-by-step execution log
- ⚠️ Error messages if any step failed

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
```

---

## Release Schedule

| Terminology | Update Frequency | Typical Release Day |
|-------------|------------------|---------------------|
| **DM+D** | Weekly | Monday 4:00 AM |
| **SNOMED CT UK Clinical** | 6 monthly | January, July |
| **SNOMED CT UK Drug Ext** | Monthly | Mid-month |
| **UK Primary Care** | Quarterly | Variable |

**Recommended Schedule:** Run weekly on Monday at 5:00 AM to catch DM+D updates promptly.

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
