
# SNOMED CT Database using SQL Sql Sever

SQL Server scripts to create and populate a Microsoft SQL Server database with a SNOMED CT terminology release.

## Minimum Specification

- Microsoft SQL Server 2008 or later

## Creating the SNOMED CT Database Schema

1. Create an empty database named **SNOMEDCT**.
2. Manually execute the `create-database-mssql.sql` script against it.

## Differences from the PostgreSQL Version

- T-SQL checks for table presence.
- Uses `uniqueidentifier` instead of `uuid`.

## File Structure

We recommend creating a dedicated folder `C:\SNOMEDCT` and placing all files from this repository there. Your file system might look like this:

```
C:\
└── SNOMEDCT
    ├── Check-NewRelease.ps1
    ├── Download-SnomedReleases.ps1
    ├── Generate-AndRun-AllSnapshots.ps1
    ├── create_snomed_tables.sql
    ├── create-database-mssql.sql
    └── README.md
```

Within this folder:

- **Check-NewRelease.ps1** – Checks the TRUD API for new SNOMED CT releases  
- **Download-SnomedReleases.ps1** – Downloads and extracts the release files  
- **Generate-AndRun-AllSnapshots.ps1** – Builds and runs the SQL import script  
- **create_snomed_tables.sql** – Defines the schema for SNOMED CT tables  
- **create-database-mssql.sql** – Creates the `SNOMEDCT` database (if desired)  
- **README.md** – This readme file

During automated operation, additional folders will be created:

- **Downloads** – Temporary location for downloaded ZIP files  
- **CurrentReleases** – Contains extracted releases before importing  

## Manual Installation

1. Unpack the full version of the SNOMED CT files (both Monolith and Primary Care Snapshot) into a folder named `SNOMEDCT`.
2. Create the database schema by executing `create_snomed_tables.sql`.
3. Run `Generate-MonolithSnapshot.ps1` to generate `import.sql`.
4. Execute `import.sql` to perform the full snapshot import.

## Automatic Installation

The automatic installation process uses three PowerShell scripts that work together to detect new TRUD releases, download them, and import the data into the SNOMED CT database.

### Script Overview

1. **Check-NewRelease.ps1**  
   - **Purpose:**  
     Checks the TRUD API for the latest release of each SNOMED CT item (e.g. Monolith and UK Primary Care).
   - **Process:**  
     - Retrieves the TRUD API key securely from Windows Credential Manager.
     - Constructs the TRUD API URL using the API key and item number.
     - Compares the current release ID (or release date) with a locally stored record (in `LastRelease.json`).
     - If a new release is detected (or if no previous record exists), it triggers the download and import scripts.

2. **Download-SnomedReleases.ps1**  
   - **Purpose:**  
     Downloads the latest TRUD release files (ZIP archives), extracts them, and organizes the extracted data into a folder named **CurrentReleases**.
   - **Process:**  
     - Downloads each ZIP file to a temporary folder (e.g. `C:\SNOMEDCT\Downloads`).
     - Unzips the downloaded files.
     - Moves the extracted folders into the **CurrentReleases** folder.
     - Deletes the original ZIP files after extraction.

3. **Generate-AndRun-AllSnapshots.ps1**  
   - **Purpose:**  
     Automatically generates a SQL script (`import.sql`) containing BULK INSERT statements to import SNOMED CT data, and then executes it to update the database.
   - **Process:**  
     - Recursively searches the **CurrentReleases** folder for folders named `Snapshot`.
     - Uses a mapping (based on file name prefixes) to create BULK INSERT statements for the corresponding tables.
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
