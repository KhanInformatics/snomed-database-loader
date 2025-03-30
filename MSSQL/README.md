# SNOMED CT Database

SQL Server scripts to create and populate a Microsoft SQL Server database with a SNOMED CT terminology release.

## Minimum Specification

- Microsoft SQL Server 2008 or later

## Creating the SNOMED CT Database Schema

1. Create an empty database SNOMEDCT
2. Manually execute the `create-database-mssql.sql` script against it.

## Differences from the PostgreSQL Version

- T-SQL checks for table presence
- Uses `uniqueidentifier` instead of `uuid`

## Manual Installation

1. Unpack the full version of the SNOMED CT files (both Monolith and Primary Care Snapshot) into a folder named `SNOMEDCT`.
2. Create the database schema by executing `create_snomed_tables.sql`.
3. Run `Generate-MonolithSnapshot.ps1` to generate `import.sql`.
4. Execute `import.sql` to perform the full snapshot import.

## Securely Storing the TRUD API Key

Instead of saving your TRUD API key in plain text, store it securely in Windows Credential Manager using the PowerShell `CredentialManager` module. Here's how:

### 1. Install the CredentialManager Module

Open PowerShell and run:

```powershell
Install-Module -Name CredentialManager -Scope CurrentUser
```

### 2. Store Your API Key

Run the following (replace `"your_api_key_here"` with your actual API key):

```powershell
New-StoredCredential -Target "TRUD_API" -UserName "dummy" -Password "your_api_key_here" -Persist LocalMachine
```

> **Note:**  
> The `UserName` parameter is required but not used for the API key, so you can safely use a dummy value.
