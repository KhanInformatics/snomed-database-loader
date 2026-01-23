# SNOMED CT Database using SQL Server

SQL Server scripts to create and populate a Microsoft SQL Server database with a SNOMED CT terminology release, including Primary Care Domain (PCD) reference sets.

## Minimum Specification

- Microsoft SQL Server 2008 or later

## Creating the SNOMED CT Database Schema

1. Create an empty database named **SNOMEDCT**.
2. Manually execute the `create-database-mssql.sql` script against it.

## Data Sources Supported

This implementation supports loading data from multiple NHS TRUD releases:

### Core SNOMED CT Data
- **International Release (Monolith)** - Complete SNOMED CT terminology (TRUD Item 1799)
- **UK Primary Care Snapshot** - UK-specific primary care extensions (TRUD Item 659)
- **UK Drug Extension** - SNOMED CT UK Drug Extension, RF2 format (TRUD Item 105)
- **International Edition (Standalone)** - Pure International SNOMED CT without UK extensions (TRUD Item 4)

### Primary Care Domain (PCD) Data
- **PCD Refset Content** - Reference sets organized by output and version
- **Ruleset Mappings** - Full name mappings for clinical areas (e.g., Asthma, Diabetes, Vaccination programmes)
- **Service Mappings** - Service classifications (Core Contract, Enhanced Services, Network Contract DES, etc.)
- **Output Descriptions** - Detailed descriptions and metadata for PCD indicators

## Loading PCD Data

Use the dedicated `Load-PCD-Refset-Content.ps1` script to import Primary Care Domain data:

```powershell
.\Load-PCD-Refset-Content.ps1
```

This script creates and populates the following tables:
- `PCD_Refset_Content_by_Output` - Primary refset content organized by output
- `PCD_Refset_Content_V2` - Alternative refset content structure
- `PCD_Ruleset_Full_Name_Mappings_V2` - Clinical area and programme mappings
- `PCD_Service_Full_Name_Mappings_V2` - Service type classifications
- `PCD_Output_Descriptions_V2` - Output descriptions and metadata

### PCD Data Validation

After loading PCD data, use the validation script to verify data integrity:

```powershell
.\Quick-PCD-Validation.ps1
```

This script compares record counts between source files and database tables to ensure complete and accurate imports.

## Loading International Edition (Separate Database)

If you need access to the pure International SNOMED CT terminology without UK extensions (e.g., for international description IDs), you can load the International Edition into a separate database.

### Step 1: Subscribe to International Edition on TRUD

1. Go to [TRUD International Edition](https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/categories/4/items/4/releases)
2. Subscribe to **Item 4: SNOMED CT International Edition**
3. The download script will automatically include it

### Step 2: Create the International Database

```powershell
# Run the database creation script
sqlcmd -S "SILENTPRIORY\SQLEXPRESS" -i "create-database-international.sql"
```

This creates a separate database named `snomedct_int` with the same table structure as the main database.

### Step 3: Download and Import

```powershell
# Download all releases (now includes International Edition - Item 4)
.\Download-SnomedReleases.ps1

# Generate and run the import for International Edition only
.\Generate-AndRun-InternationalSnapshot.ps1
```

### Why Use a Separate International Database?

- **International Description IDs** - The UK Monolith contains UK Extension descriptions but may not include all International descriptions
- **Cross-referencing** - Compare UK vs International content
- **Description ID Lookups** - Find International description text by ID (e.g., `207516010`)

### Example Query

```sql
-- Search for a description by ID in International Edition
USE snomedct_int;
SELECT id, conceptid, CAST(term AS VARCHAR(200)) as term 
FROM curr_description_f 
WHERE id = '207516010';
```

## Differences from the PostgreSQL Version

- T-SQL checks for table presence.
- Uses `uniqueidentifier` instead of `uuid`.

## File Structure

We recommend creating a dedicated folder `C:\SNOMEDCT`. You only need to create the `C:\SNOMEDCT` folder; the automation scripts will build and populate the necessary sub‑folders automatically the first time they run. For PCD data, ensure the following files are present in the Downloads folder:

- `20250521_PCD_Refset_Content_by_Output.txt`
- `20250521_PCD_Refset_Content_V2.txt` 
- `20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt`
- `20250521_PCD_Service_Full_Name_Mappings_V2.txt`
- `20250521_PCD_Output_Descriptions_V2.txt`

A typical layout (after one full import cycle) looks like this:

```
C:\
└── SNOMEDCT
    ├── Downloads                 # Contains PCD source files and temporary .zip files
    │   ├── 20250521_PCD_Refset_Content_by_Output.txt
    │   ├── 20250521_PCD_Refset_Content_V2.txt
    │   ├── 20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt
    │   ├── 20250521_PCD_Service_Full_Name_Mappings_V2.txt
    │   └── 20250521_PCD_Output_Descriptions_V2.txt
    ├── CurrentReleases           # Extracted RF2 releases awaiting import
    │   ├── SnomedCT_InternationalRF2_YYYYMMDD
    │   │   └── Snapshot
    │   └── SnomedCT_UKClinicalRF2_YYYYMMDD
    ├── import.sql                # Auto‑generated BULK INSERT script
    ├── CheckNewRelease.log       # Execution log created by Check-NewRelease.ps1
    └── LastRelease.json          # Tracks the latest release processed
```

### What Each Folder / File Is For

- **Downloads** – Temporary holding area for the raw `.zip` files downloaded from TRUD; the automation deletes them after extraction.  
- **CurrentReleases** – Extracted RF2 content, stored in date‑stamped sub‑folders so you can review what will be imported.  
- **import.sql** – Auto‑generated BULK INSERT script created by *Generate‑AndRun‑AllSnapshots.ps1*.  
- **LastRelease.json** – Records the release IDs already imported so they aren't processed twice.  
- **CheckNewRelease.log** – Log file produced each time *Check‑NewRelease.ps1* runs (helpful for troubleshooting).

During automated operation, additional folders will be created:

- **Downloads** – Temporary location for downloaded ZIP files  
- **CurrentReleases** – Contains extracted releases before importing
  - Monolith release folder (e.g., `uk_sct2mo_39.6.0_20250312000001Z`)
  - UK Primary Care release folder (e.g., `uk_sct2pc_54.0.0_20241205000000Z`)
  - UK Drug Extension release folder (e.g., `uk_sct2drug_XX.X.X_YYYYMMDDHHMMSS`)  

## Manual Installation

1. Unpack the full version of the SNOMED CT files (both Monolith and Primary Care Snapshot) into a folder named `SNOMEDCT`.
2. Create the database schema by executing `create_snomed_tables.sql`.
3. Run `Generate-MonolithSnapshot.ps1` to generate `import.sql`.
4. Execute `import.sql` to perform the full snapshot import.

## Automatic Installation

The automatic installation process uses three PowerShell scripts that work together to detect new TRUD releases, download them, and import the data into the SNOMED CT database.

### Script Overview

**Automation Flow:**
```
Check-NewRelease.ps1 → Download-SnomedReleases.ps1 → Generate-AndRun-AllSnapshots.ps1
```

1. **Check-NewRelease.ps1** *(Main Entry Point)*  
   - **Purpose:**  
     Checks the TRUD API for the latest release of each SNOMED CT item (e.g. Monolith and UK Primary Care) and orchestrates the full import workflow.
   - **Process:**  
     - Retrieves the TRUD API key securely from Windows Credential Manager.
     - Constructs the TRUD API URL using the API key and item number.
     - Compares the current release ID (or release date) with a locally stored record (in `LastRelease.json`).
     - If a new release is detected (or if no previous record exists):
       1. Automatically calls **Download-SnomedReleases.ps1** to download the releases.
       2. Automatically calls **Generate-AndRun-AllSnapshots.ps1** to import the data.
       3. Runs validation queries and logs row counts for key tables to `CheckNewRelease.log`.

2. **Download-SnomedReleases.ps1**  
   - **Purpose:**  
     Downloads the latest TRUD release files (ZIP archives), extracts them, and organizes the extracted data into a folder named **CurrentReleases**.
   - **Process:**  
     - Downloads SNOMED CT International (Monolith) - TRUD Item 1799
     - Downloads UK Primary Care Snapshot - TRUD Item 659
     - Downloads UK Drug Extension - TRUD Item 105
     - Downloads each ZIP file to a temporary folder (e.g. `C:\SNOMEDCT\Downloads`).
     - Unzips the downloaded files.
     - Moves the extracted folders into the **CurrentReleases** folder.
     - Deletes the original ZIP files after extraction.

3. **Generate-AndRun-AllSnapshots.ps1**  
   - **Purpose:**  
     Automatically generates a SQL script (`import.sql`) containing BULK INSERT statements to import SNOMED CT data from all three sources (Monolith, UK Primary Care, and UK Drug Extension), and then executes it to update the database.
   - **Process:**  
     - Recursively searches the **CurrentReleases** folder for folders named `Snapshot`.
     - Uses a mapping (based on file name prefixes) to create BULK INSERT statements for the corresponding tables.
     - Handles all RF2 file types including drug extension concepts, descriptions, and relationships.
     - Writes a global header (which truncates existing data) and all BULK INSERT statements to `import.sql`.
     - Executes the SQL script (using `sqlcmd` or `Invoke-Sqlcmd`) to load the data into the `SNOMEDCT` database.

### How the Process Works Together

- **Step 1:** Run **Check-NewRelease.ps1**  
  Checks for new releases from TRUD. If a new release is found (or if no record exists), it updates `LastRelease.json` with the new release ID and automatically calls the other scripts.

- **Step 2:** **Download-SnomedReleases.ps1**  
  Downloads the new release ZIP files, unzips them, and places the extracted data in **CurrentReleases**.

- **Step 3:** **Generate-AndRun-AllSnapshots.ps1**  
  Locates `Snapshot` folders within **CurrentReleases**, creates an SQL import script, and executes it to load data into your database.

## Securely Storing the TRUD API Key

Instead of saving your TRUD API key in plain text, store it securely in Windows Credential Manager using the PowerShell `CredentialManager` module.

### 1. Install the CredentialManager Module

Open PowerShell and run:

```powershell
Install-Module -Name CredentialManager -Scope CurrentUser
```

### 2. Store Your API Key

Replace `"your_api_key_here"` with your actual key:

```powershell
New-StoredCredential -Target "TRUD_API" -UserName "dummy" -Password "your_api_key_here" -Persist LocalMachine
```

> **Note:**  
> The `UserName` parameter is required by the module but isn’t used for the API key, so you can safely use a dummy value.

### 3. Updating the TRUD API Key

If your API key changes, run the same command with the new key:

```powershell
New-StoredCredential -Target "TRUD_API" -UserName "dummy" -Password "your_new_api_key_here" -Persist LocalMachine
```

Once updated, your scripts that retrieve the API key using `Get-StoredCredential` will automatically use the new key.

## Checking the TRUD API Key

If you are having issues with the TRUD API key, you can use this snippet to display the stored API key using powershell:

```powershell
# Requires the CredentialManager module
Import-Module CredentialManager

# Retrieve the stored TRUD API key
$cred = Get-StoredCredential -Target "TRUD_API"

if ($cred) {
    # Convert SecureString to plain text
    $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
    )
    Write-Host "TRUD API Key:" -ForegroundColor Cyan
    Write-Host $plainText -ForegroundColor Green
} else {
    Write-Host "TRUD_API credential not found." -ForegroundColor Red
}
```

This snippet displays your TRUD API key in green text if it is found, or an error message in red if it is not.

## PCD Database Tables

The Primary Care Domain (PCD) import creates five tables containing reference sets and mappings for primary care indicators:

### Core Content Tables

#### `PCD_Refset_Content_by_Output`
Contains the main PCD reference set content organized by output indicators.
- **Output_ID** - Unique identifier for the output/indicator
- **SNOMED_Code** - SNOMED CT concept code
- **Output_Description** - Description of the clinical output/indicator
- **PCD_Refset_ID** - PCD reference set identifier  
- **Cluster** - Clinical grouping/cluster identifier
- **Usage**: Primary table for mapping SNOMED codes to primary care outputs

#### `PCD_Refset_Content_V2`
Alternative structure for PCD reference set content with different organization.
- **SNOMED_Code** - SNOMED CT concept code
- **Output_Description** - Description of the clinical output
- **Output_Type** - Classification of the output type
- **PCD_Refset_ID** - PCD reference set identifier
- **Usage**: Alternative view of PCD content for different use cases

### Mapping and Reference Tables

#### `PCD_Ruleset_Full_Name_Mappings_V2`
Maps ruleset IDs to their full descriptive names.
- **Ruleset_ID** - Short identifier (e.g., '6IN1', 'Asthma')
- **Ruleset_Short_Name** - Short descriptive name
- **Ruleset_Full_Name** - Complete descriptive name (e.g., '6-in-1 Vaccination Programme')
- **Usage**: Provides human-readable names for clinical areas and programmes

#### `PCD_Service_Full_Name_Mappings_V2`
Maps service type codes to their full descriptions.
- **Service_ID** - Service code (e.g., 'CC', 'ES', 'NCD')
- **Service_Short_Name** - Abbreviated service name
- **Service_Full_Name** - Complete service description (e.g., 'Core Contract (CC)')
- **Usage**: Classifies different types of primary care services

#### `PCD_Output_Descriptions_V2`  
Provides detailed descriptions and metadata for PCD outputs.
- **Output_ID** - Unique output identifier
- **Output_Description** - Detailed description of the output/indicator
- **Output_Type** - Classification or type of the output
- **Usage**: Comprehensive metadata for understanding PCD indicators

### Data Relationships

```
PCD_Refset_Content_by_Output
├── Links to PCD_Output_Descriptions_V2 (via Output_ID)
└── Contains SNOMED codes for clinical concepts

PCD_Refset_Content_V2
├── Alternative structure for same content
└── Links to PCD_Output_Descriptions_V2 (via Output_ID)

PCD_Ruleset_Full_Name_Mappings_V2
└── Provides names for clinical programmes/areas

PCD_Service_Full_Name_Mappings_V2
└── Classifies service delivery types
```

## Additional PowerShell Scripts

### PCD-Specific Scripts

#### `Load-PCD-Refset-Content.ps1`
**Purpose:** Loads Primary Care Domain reference sets and mappings into the database.

**Features:**
- Creates PCD database tables with appropriate schemas
- Imports data from 5 different PCD source files
- Handles multiple delimiter formats (tab-separated, comma-separated)
- Provides detailed progress reporting and error handling
- Includes data quality validation and record counting
- Automatically truncates tables before import to prevent duplicates

**Usage:**
```powershell
.\Load-PCD-Refset-Content.ps1 [-server "ServerName"] [-database "DatabaseName"]
```

#### `Quick-PCD-Validation.ps1`
**Purpose:** Validates PCD data imports by comparing source files with database tables.

**Features:**
- Compares record counts between source files and database tables
- Displays sample records from both source and database
- Provides summary report of validation results
- Identifies missing or duplicate records
- Generates timestamped validation reports

**Usage:**
```powershell
.\Quick-PCD-Validation.ps1 [-server "ServerName"] [-database "DatabaseName"]
```

**Example Output:**
```
PCD Data Import Validation Report
Generated: 06/17/2025 20:12:24

Validating: PCD_Refset_Content_by_Output
  Source: 318427 records
  Sample: 6IN1001 3IN1VAC_COD 3-in-1 Diphtheria, tetanus, and polio vaccine...
  Table: 318427 records
  Status: Perfect match

SUMMARY:
  Successful: 5
  Issues: 0
All validations passed!
```

### Integration with Existing Workflow

The PCD scripts complement the existing SNOMED CT workflow:

1. **Standard SNOMED CT Import** (existing scripts)
   - `Check-NewRelease.ps1` - Check for new TRUD releases
   - `Download-SnomedReleases.ps1` - Download and extract releases  
   - `Generate-AndRun-AllSnapshots.ps1` - Import core SNOMED CT data

2. **PCD Import** (new scripts)
   - `Load-PCD-Refset-Content.ps1` - Import PCD reference sets
   - `Quick-PCD-Validation.ps1` - Validate PCD imports

This allows you to maintain both core SNOMED CT terminology and primary care domain extensions in a single database instance.


