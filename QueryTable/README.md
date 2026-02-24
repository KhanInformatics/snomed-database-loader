# SNOMED CT UK Query Table and History Substitution Table

This folder contains scripts for downloading and importing the **SNOMED CT UK Query Table and History Substitution Table** (TRUD Item 276).

## What Is This?

The Query Table is an **enhanced transitive closure** that extends beyond standard ancestor-descendant relationships by incorporating inactive concept handling. It's the NHS-recommended approach for querying SNOMED CT in primary care systems.

### SQL Server Tables

After import, two tables are created in the `snomedct` database:

| Table Name | Description | Rows |
|------------|-------------|------|
| **`uk_query_table`** | Enhanced transitive closure (ancestor-descendant relationships) | ~23 million |
| **`uk_history_substitution`** | Mappings from inactive to active concepts | ~350K |

### Source Files (from TRUD)

| File | Description |
|------|-------------|
| `xres2_SNOMEDQueryTable_CORE-UK_YYYYMMDD.txt` | Query Table source data |
| `xres2_HistorySubstitutionTable_Concepts_GB1000000_YYYYMMDD.txt` | History Substitution source data |

### Why Use This Instead of Standard Transitive Closure?

| Feature | Standard Transitive Closure | UK Query Table |
|---------|----------------------------|----------------|
| Active concept relationships | ✅ | ✅ |
| Paths through inactive concepts | ❌ | ✅ |
| Historical data retrieval | Limited | Comprehensive |
| JGPIT Recommended | No | **Yes** |

## Quick Start

### 1. Download the Data

```powershell
.\Download-QueryTableReleases.ps1
```

This downloads from TRUD Item 276 and extracts to `C:\QueryTable\CurrentReleases\`

### 2. Create Tables

```powershell
# First time only - creates the tables in your snomedct database
.\Import-QueryTableData.ps1 -CreateTables
```

Or run the SQL script directly:
```powershell
sqlcmd -S localhost -d snomedct -i create-querytable-tables.sql
```

### 3. Import Data

```powershell
.\Import-QueryTableData.ps1
```

The import takes approximately 5-10 minutes depending on your hardware.

## File Locations

After downloading:
```
C:\QueryTable\
├── CurrentReleases\
│   └── uk_sctqths_XX.X.X_YYYYMMDDHHMMSS\
│       └── SnomedCT_UKClinicalRF2_PRODUCTION_...\
│           └── Resources\
│               ├── QueryTable\
│               │   └── xres2_SNOMEDQueryTable_CORE-UK_YYYYMMDD.txt
│               ├── HistorySubstitutionTable\
│               │   └── xres2_HistorySubstitutionTable_Concepts_GB1000000_YYYYMMDD.txt
│               └── Readme-en.txt
└── Downloads\  (temporary, cleaned after extraction)
```

## Table Schemas

### uk_query_table

| Column | Type | Description |
|--------|------|-------------|
| `supertypeId` | VARCHAR(18) | Ancestor concept ID |
| `subtypeId` | VARCHAR(18) | Descendant concept ID |
| `provenance` | TINYINT | 0 = direct, >0 = via substitution |

### uk_history_substitution

| Column | Type | Description |
|--------|------|-------------|
| `oldConceptId` | VARCHAR(18) | Inactive concept ID |
| `oldConceptStatus` | TINYINT | Status of old concept |
| `newConceptId` | VARCHAR(18) | Recommended replacement |
| `newConceptStatus` | TINYINT | Status of new concept |
| `path` | VARCHAR(255) | Substitution path |
| `isAmbiguous` | BIT | 1 if multiple valid substitutions |
| `iterations` | TINYINT | Hops in substitution chain |
| `oldConceptFSN` | NVARCHAR(512) | Old concept's FSN |
| `newConceptFSN` | NVARCHAR(512) | New concept's FSN |

## Sample Queries

See [SampleQueries.sql](SampleQueries.sql) for complete examples.

### Find All Types of Diabetes (Including Historical)

```sql
SELECT COUNT(DISTINCT subtypeId) AS diabetes_types
FROM uk_query_table
WHERE supertypeId = '73211009';  -- Diabetes mellitus
```

### Find Replacement for Inactive Concept

```sql
SELECT oldConceptId, oldConceptFSN, newConceptId, newConceptFSN
FROM uk_history_substitution
WHERE oldConceptId = '105000';
```

### Check if Concept A is Subtype of Concept B

```sql
SELECT CASE 
    WHEN EXISTS (
        SELECT 1 FROM uk_query_table 
        WHERE supertypeId = '64572001'   -- Disease
          AND subtypeId = '233604007'    -- Pneumonia
    ) THEN 'YES'
    ELSE 'NO'
END AS is_subtype;
```

## TRUD Reference

- **Item Number**: 276
- **Name**: SNOMED CT UK Query Table and History Substitution Table  
- **URL**: https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/categories/26/items/1805/releases
- **Release Cycle**: Monthly (aligned with UK Clinical Edition)

## Prerequisites

- SQL Server 2016 or later
- PowerShell 5.1 or later
- TRUD API key stored in Windows Credential Manager (target: `TRUD_API`)
- Existing `snomedct` database (or modify scripts for different database name)

## Troubleshooting

### API Key Issues

```powershell
# Verify stored credential
Get-StoredCredential -Target "TRUD_API"

# Re-store credential if needed
Import-Module CredentialManager
New-StoredCredential -Target "TRUD_API" -UserName "TRUD_API" -Password "your-api-key" -Persist LocalMachine
```

### Import Fails with Permission Error

Ensure SQL Server has read access to `C:\QueryTable\`. You may need to:
1. Run PowerShell as Administrator
2. Grant the SQL Server service account read access to the folder

### Large File Import Timeout

If the import times out, increase the batch size or timeout in the import script.

## Related Documentation

- [TRANSITIVE_CLOSURE.md](../DMWB/TRANSITIVE_CLOSURE.md) - Understanding transitive closure concepts
- [DELEN Portal](https://nhsengland.kahootz.com/t_c_home) - NHS England terminology documentation
