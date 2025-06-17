# SNOMED CT Database Loader

This repository provides scripts specifically for building and maintaining a **SNOMED CT database instance** using the **Monolith**, **UK Primary Care**, and **Primary Care Domain (PCD)** snapshots released via **NHS TRUD**. I created this in an effort to learn how to maintain and use the different downloads available from the TRUD.

It supports loading data into a variety of databases, with a full end-to-end **automated workflow for Microsoft SQL Server**, including:

- Checking for new releases via the TRUD API
- Downloading and extracting release files
- Generating and executing `BULK INSERT` SQL scripts for snapshot import
- Loading Primary Care Domain (PCD) reference sets and mappings

## Supported Targets
- [**MSSQL** – Fully automated (PowerShell-driven)](https://github.com/KhanInformatics/snomed-database-loader/tree/master/MSSQL)

## Key Features

### Core SNOMED CT Data
- **International Release (Monolith)** - Complete SNOMED CT terminology
- **UK Primary Care Snapshot** - UK-specific primary care extensions

### Primary Care Domain (PCD) Support
- **PCD Refset Content** - Primary care domain reference sets mapped to outputs
- **Ruleset Mappings** - Full name mappings for PCD rulesets (e.g., vaccination programmes, clinical areas)
- **Service Mappings** - Service type classifications (Core Contract, Enhanced Services, etc.)
- **Output Descriptions** - Detailed descriptions of PCD outputs and indicators

> ⚠️ This repository is **not** a general-purpose RF2 loader. It is purpose-built for loading the **Monolith**, **UK Primary Care Snapshot**, and **Primary Care Domain** releases into a local database instance for analytics, reporting, or interoperability work.

Contributions are welcome — feel free to fork the repo and submit a pull request if you'd like to add or improve support for other environments.

## Complete Workflow

### Initial Setup
1. **Database Preparation**
   - Create empty `SNOMEDCT` database in SQL Server
   - Execute `MSSQL/create-database-mssql.sql` to create schema
   - Store TRUD API key in Windows Credential Manager

2. **File Structure Setup**
   - Create `C:\SNOMEDCT` folder
   - Place PCD source files in `C:\SNOMEDCT\Downloads\` folder

### Standard Data Loading
1. **Core SNOMED CT Data**
   ```powershell
   cd MSSQL
   .\Check-NewRelease.ps1          # Check for new releases
   .\Download-SnomedReleases.ps1   # Download and extract
   .\Generate-AndRun-AllSnapshots.ps1  # Import core data
   ```

2. **Primary Care Domain Data**
   ```powershell
   .\Load-PCD-Refset-Content.ps1   # Import PCD reference sets
   .\Quick-PCD-Validation.ps1      # Validate import
   ```

### Data Validation and Queries
- Use queries in `/Queries/` folder to explore and validate data
- PCD-specific queries available for primary care domain analysis
- Standard SNOMED CT queries for core terminology exploration

### Maintenance
- Re-run `Check-NewRelease.ps1` periodically for SNOMED CT updates
- PCD data updates require manual file replacement and re-import
- Use validation scripts after any data updates
