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

### PCD V2 Table Schema (SQL Server)

After recent fixes, the PCD reference set content table matches the actual six-column data structure from the source file:

- `PCD_Refset_Content_V2`
   - `Cluster_ID` VARCHAR(50)
   - `Cluster_Description` VARCHAR(500)
   - `SNOMED_code` VARCHAR(255)
   - `SNOMED_code_description` VARCHAR(500)
   - `PCD_Refset_ID` VARCHAR(50)
   - `Service_and_Ruleset` VARCHAR(500)

Recommended indexes:
- `IX_PCD_Refset_Content_V2_SNOMED_code (SNOMED_code)`
- `IX_PCD_Refset_Content_V2_PCD_Refset_ID (PCD_Refset_ID)`
- `IX_PCD_Refset_Content_V2_Cluster_ID (Cluster_ID)`

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

#### Handy Query Examples

- **List unique ref sets by cluster:**
   ```sql
   SELECT DISTINCT
         Cluster_ID,
         Cluster_Description,
         PCD_Refset_ID
   FROM PCD_Refset_Content_V2
   ORDER BY Cluster_ID, PCD_Refset_ID;
   ```

- **Get codes for selected clusters** (see `Queries/GetCodesAllclusters.sql` for complete examples):
   ```sql
   -- Example: smoking-related clusters only
   DECLARE @ClusterList TABLE (
         Cluster_ID NVARCHAR(50),
         Cluster_Description NVARCHAR(300),
         PCD_Refset_ID NVARCHAR(50)
   );
   INSERT INTO @ClusterList VALUES
         ('SMOK_COD','Smoking habit codes','^999005651000230102'),
         ('SMOKINVITE_COD','Invite for smoking care review codes','^999012531000230102'),
         ('SMOKPCADEC_COD','Codes indicating the patient has chosen not to receive smoking quality indicator care','^999012171000230106'),
         ('SMOKPCAPU_COD','Codes for smoking quality indicator care unsuitable for patient','^999012211000230109'),
         ('SMOKSTATDEC_COD','Codes indicating the patient has chosen not to give their smoking status','^999012251000230108');

   SELECT cl.Cluster_ID, cl.Cluster_Description, prc.SNOMED_code, prc.SNOMED_code_description
   FROM @ClusterList cl
   INNER JOIN PCD_Refset_Content_V2 prc 
      ON (prc.Cluster_ID = cl.Cluster_ID 
          OR REPLACE(prc.PCD_Refset_ID, '^', '') = REPLACE(cl.PCD_Refset_ID, '^', ''))
   ORDER BY cl.Cluster_ID, prc.SNOMED_code;
   ```

> **Note:** The `Queries/` folder contains additional examples including COPD, CHD, and other clinical area cluster queries. See `Queries/Readme.md` for more detailed query patterns and explanations of duplicate rows when joining with Output_ID/Output_Description columns.

### Maintenance
- Re-run `Check-NewRelease.ps1` periodically for SNOMED CT updates
- PCD data updates require manual file replacement and re-import
- Use validation scripts after any data updates
