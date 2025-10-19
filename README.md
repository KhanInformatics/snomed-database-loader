# NHS Terminology Database Loaders

This repository provides comprehensive scripts for building and maintaining **NHS terminology databases** using releases from **NHS TRUD**. It includes automated workflows for both **SNOMED CT** and **DM+D (Dictionary of Medicines and Devices)** data.

## Supported Terminologies

### SNOMED CT Database Loader
- **Monolith**: Complete international SNOMED CT terminology
- **UK Primary Care**: UK-specific primary care extensions  
- **Primary Care Domain (PCD)**: Primary care reference sets and mappings

### DM+D Database Loader  
- **NHS DM+D**: Complete medicines and devices hierarchy
- **Supplementary Data**: BNF codes, ATC classifications, GTIN mappings
- **Commercial Data**: Suppliers, licensing, Drug Tariff information

Both workflows support loading data into SQL Server with full end-to-end automation including:

- Checking for new releases via the TRUD API
- Downloading and extracting release files  
- Processing data files and generating import scripts
- Data validation and integrity checking

## Supported Targets
- [**MSSQL/SNOMED CT** – Fully automated (PowerShell-driven)](https://github.com/KhanInformatics/snomed-database-loader/tree/master/MSSQL)
- [**DMD** – Complete DM+D workflow (PowerShell-driven)](https://github.com/KhanInformatics/snomed-database-loader/tree/master/DMD)

## Quick Start

### SNOMED CT Database  
```powershell
cd MSSQL
.\Complete-SnomedWorkflow.ps1
```

### DM+D Database
```powershell  
cd DMD
.\Complete-DMDWorkflow.ps1
```

### Both Databases
```powershell
# Set up SNOMED CT first
cd MSSQL  
.\Complete-SnomedWorkflow.ps1

# Then set up DM+D
cd ..\DMD
.\Complete-DMDWorkflow.ps1
```

## Key Features

### SNOMED CT Workstream (`MSSQL/`)
- **International Release (Monolith)** - Complete SNOMED CT terminology
- **UK Primary Care Snapshot** - UK-specific primary care extensions  
- **Primary Care Domain (PCD)** - Reference sets mapped to outputs and indicators
- **RF2 Format Processing** - Concepts, descriptions, relationships, and reference sets
- **Automated BULK INSERT** - High-performance SQL Server loading

### DM+D Workstream (`DMD/`)
- **Complete Product Hierarchy** - VTM → VMP → AMP → VMPP → AMPP structure
- **Clinical Classifications** - BNF codes, ATC codes, SNOMED CT mappings
- **Commercial Information** - Suppliers, licensing authorities, Drug Tariff data
- **Prescribing Support** - Controlled drugs, sugar-free alternatives, pack sizes
- **XML Processing** - Native handling of NHS DM+D XML format

> 💡 **Integration Ready**: Both workstreams use the same TRUD API credentials and can be cross-referenced via SNOMED CT mappings for comprehensive clinical terminology coverage.

### DM+D Database Schema

The DM+D database implements the official NHS DM+D Data Model R2 v4.0:

**Core Entity Tables:**
- `vtm` - Virtual Therapeutic Moieties (active ingredients)
- `vmp` - Virtual Medical Products (generic products)  
- `amp` - Actual Medical Products (branded products)
- `vmpp` - Virtual Medical Product Packs (generic packs)
- `ampp` - Actual Medical Product Packs (commercial packs)

**Clinical Data:**
- `vmp_ingredient` - Active ingredient compositions and strengths
- `vmp_drugroute` - Administration routes (oral, injection, etc.)
- `vmp_drugform` - Pharmaceutical forms (tablet, capsule, etc.)
- `dmd_bnf` - British National Formulary classifications
- `dmd_atc` - Anatomical Therapeutic Chemical codes
- `dmd_snomed` - SNOMED CT concept mappings

**Commercial Data:**
- `lookup` - Reference data for suppliers, licensing authorities, etc.
- `gtin` - Global Trade Item Numbers for supply chain integration
- `ampp_drugtariffinfo` - NHS Drug Tariff pricing information

### SNOMED CT Schema (PCD V2)

The PCD reference set content table matches the actual six-column data structure:

- `PCD_Refset_Content_V2` - Primary care domain indicators
   - `Cluster_ID`, `Cluster_Description` - Clinical area groupings
   - `SNOMED_code`, `SNOMED_code_description` - Linked terminology
   - `PCD_Refset_ID`, `Service_and_Ruleset` - QOF and service mappings

Contributions are welcome — feel free to fork the repo and submit a pull request if you'd like to add or improve support for other environments or database platforms.

## Complete Workflows

### Prerequisites (Both Workstreams)
- **SQL Server** - Local or remote instance with sufficient storage
- **TRUD API Key** - Stored in Windows Credential Manager as 'TRUD_API'  
- **PowerShell 5.1+** - With SqlServer module installed
- **Storage Space** - ~5GB for SNOMED CT, ~2GB for DM+D

### SNOMED CT Workflow (`MSSQL/`)

**Automated Setup:**
```powershell
cd MSSQL
.\Complete-SnomedWorkflow.ps1
```

**Manual Steps:**
1. **Check and Download**
   ```powershell
   .\Check-NewRelease.ps1          # Check for updates
   .\Download-SnomedReleases.ps1   # Download from TRUD
   ```

2. **Import Data**  
   ```powershell
   .\Generate-AndRun-AllSnapshots.ps1  # Core SNOMED CT data
   .\Load-PCD-Refset-Content.ps1       # Primary Care Domain
   ```

### DM+D Workflow (`DMD/`)

**Automated Setup:**
```powershell
cd DMD  
.\Complete-DMDWorkflow.ps1
```

**Manual Steps:**
1. **Check and Download**
   ```powershell
   .\Check-NewDMDRelease.ps1       # Check for updates
   .\Download-DMDReleases.ps1      # Download from TRUD
   ```

2. **Process and Import**
   ```powershell  
   .\Process-DMDData.ps1           # Process XML and import
   .\Validate-DMDImport.ps1        # Validate data integrity
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

## Integration and Cross-Referencing

The SNOMED CT and DM+D databases are designed to work together:

### Linked Clinical Terminology
```sql  
-- Find SNOMED CT concepts for DM+D products
SELECT 
    v.nm as dmd_product_name,
    ds.snomed_conceptid,
    d.term as snomed_preferred_term
FROM dmd.dbo.vmp v
JOIN dmd.dbo.dmd_snomed ds ON v.vpid = ds.dmd_id 
JOIN snomedct.dbo.curr_description_f d ON ds.snomed_conceptid = d.conceptid
WHERE v.invalid = 0 AND d.active = '1' AND d.typeid = '900000000000003001';
```

### Primary Care Integration
```sql
-- Link PCD indicators to DM+D therapeutic areas  
SELECT 
    p.Cluster_Description as pcd_indicator,
    v.nm as related_dmd_product,
    t.nm as therapeutic_ingredient
FROM snomedct.dbo.PCD_Refset_Content_V2 p
JOIN dmd.dbo.dmd_snomed ds ON p.SNOMED_code = ds.snomed_conceptid
JOIN dmd.dbo.vmp v ON ds.dmd_id = v.vpid AND ds.dmd_type = 'VMP'
JOIN dmd.dbo.vtm t ON v.vtmid = t.vtmid
WHERE v.invalid = 0 AND t.invalid = 0;
```

## Maintenance and Updates

### Regular Update Schedule
- **SNOMED CT**: Check monthly (releases every 6 months + UK updates)
- **DM+D**: Check weekly (releases every Monday at 4:00 AM)  
- **PCD**: Check quarterly (updates as QOF requirements change)

### Automated Monitoring
```powershell
# Create scheduled tasks for automated checking
schtasks /create /tn "Check SNOMED Updates" /tr "C:\Scripts\MSSQL\Check-NewRelease.ps1" /sc weekly /d MON /st 08:00
schtasks /create /tn "Check DM+D Updates" /tr "C:\Scripts\DMD\Check-NewDMDRelease.ps1" /sc weekly /d MON /st 08:30
```

### Backup and Recovery
- **Full Backup**: Both databases after successful updates
- **Differential**: Daily backups during active development
- **Transaction Log**: Every 15 minutes for production systems
- **Restore Testing**: Monthly validation of backup integrity

## Use Cases and Applications

### Clinical Decision Support
- **Drug-Drug Interactions**: Cross-reference active ingredients
- **Therapeutic Alternatives**: Find products with same VTM  
- **Prescribing Guidance**: Sugar-free, gluten-free options
- **Dose Calculations**: Unit dose information from DM+D

### Quality Improvement  
- **QOF Reporting**: PCD indicators linked to prescribing data
- **Formulary Management**: BNF classification analysis
- **Cost Analysis**: Drug Tariff pricing with utilization data
- **Audit Support**: Prescribing pattern analysis

### Integration Projects
- **EPR Systems**: Terminology services for clinical systems
- **Prescribing Systems**: Product selection and validation
- **Pharmacy Systems**: Dispensing and stock management
- **Reporting Platforms**: Clinical and financial analytics
