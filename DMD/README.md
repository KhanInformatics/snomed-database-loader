# DM+D Database Loader

This directory provides scripts specifically for building and maintaining a **DM+D (Dictionary of Medicines and Devices)** database instance using the **NHS DM+D** releases and **supplementary data** downloaded via **NHS TRUD**. This workstream is designed to complement the existing SNOMED CT loader with comprehensive medicines and devices data.

## What is DM+D?

The NHS Dictionary of Medicines and Devices (dm+d) is the NHS standard for uniquely identifying and communicating medicinal product and medical device information used in patient care across clinical IT systems. It provides:

- **Structured product hierarchy**: VTM → VMP → AMP → VMPP → AMPP
- **Clinical classifications**: BNF codes, ATC codes, SNOMED CT mappings
- **Commercial information**: Suppliers, licensing, pricing data
- **Prescribing support**: Sugar-free options, controlled drug classifications
- **Weekly updates**: Fresh data every Monday at 4:00 AM

## Supported Data Sources

- **[NHSBSA dm+d](https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/categories/6/items/105)** - Main dm+d data in vendor-neutral XML format
- **[NHSBSA dm+d supplementary](https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/categories/6/items/108)** - ATC and BNF codes linked to primary care products

## Key Features

### Core DM+D Entities
- **VTM (Virtual Therapeutic Moiety)** - Active ingredients/therapeutic substances
- **VMP (Virtual Medical Product)** - Generic product concepts  
- **AMP (Actual Medical Product)** - Specific branded/generic products
- **VMPP (Virtual Medical Product Pack)** - Generic pack size concepts
- **AMPP (Actual Medical Product Pack)** - Specific commercial packs

### Clinical Classifications
- **BNF Codes** - British National Formulary classifications
- **ATC Codes** - Anatomical Therapeutic Chemical classifications
- **SNOMED CT** - Integration with clinical terminology
- **Prescribing Status** - Controlled drugs, prescription requirements

### Commercial Data  
- **Supplier Information** - Manufacturer and supplier details
- **Licensing Authority** - Regulatory approval information
- **Drug Tariff** - NHS reimbursement information
- **GTIN Codes** - Global Trade Item Numbers for supply chain

## Database Schema

The DM+D database follows the official NHS DM+D Data Model R2 v4.0 structure:

### Core Tables
```
vtm              - Virtual Therapeutic Moieties (active ingredients)
├── vmp          - Virtual Medical Products (generic products)  
    ├── amp      - Actual Medical Products (branded products)
    └── vmpp     - Virtual Medical Product Packs (generic packs)
        └── ampp - Actual Medical Product Packs (commercial packs)
```

### Supporting Tables
```
lookup           - Reference data for coded fields
vmp_ingredient   - Ingredient compositions and strengths
vmp_drugroute    - Administration routes
vmp_drugform     - Pharmaceutical forms
dmd_bnf          - BNF code mappings
dmd_atc          - ATC code mappings  
dmd_snomed       - SNOMED CT mappings
gtin             - Global Trade Item Numbers
ampp_price       - AMPP price, date, previous price and price basis (key: appid)
vmpp_drugtariffinfo - VMPP tariff price, date, previous price and category (key: vppid)
```

### Pack prices and Drug Tariff

`StandaloneImports/Run-AllImports.ps1` imports both pricing sections after packs
and lookups. `Import-PackPrices.ps1` can also upgrade an existing database without
recreating it:

```powershell
$release = 'C:\DMD\CurrentReleases\nhsbsa_dmd_9.0.0_20260907000001' # choose your full release
.\StandaloneImports\Import-PackPrices.ps1 -XmlPath $release -ServerInstance 'SILENTPRIORY\SQLEXPRESS' -DatabaseName dmd
.\Validate-PackPrices.ps1 -XmlPath $release -ServerInstance 'SILENTPRIORY\SQLEXPRESS' -Database dmd
```

The importer creates missing tables using `Ensure-PackPriceSchema.sql`, then
refreshes both tables in one transaction. It updates existing IDs and removes
pricing rows absent from the supplied full snapshot. Both sources must be present
and nonempty; duplicate IDs, malformed values, missing parent packs and unknown
lookup codes fail the import. A failure rolls back both pricing tables.

Amounts retain the XML integer values. Zero and SQL `NULL` are distinct; a zero
price must not be assumed to mean a free pack. Interpret AMPP `price_basiscd`
using `lookup.type = 'PRICE_BASIS'`, and tariff `pay_catcd` using
`lookup.type = 'DT_PAYMENT_CATEGORY'`. Each table stores the current supplied
snapshot and its supplied previous-price field, not a complete price history.

The exact validator compares **every field and row in both directions**, and
throws on missing tables, stale prices or extra/missing records. It checks pack
references and lookup codes too. The release checker runs it before saving
`LastImportedRelease.json`; the weekly orchestrator also runs it on weeks with no
new release and includes both pricing tables in row counts and changes. A failed
pricing check marks the weekly result failed. To add pricing to an older database,
run the standalone import above once using its already-loaded release.

Validation stages pack IDs in a unique clustered index and compares ordered
rows, including NULL values, without hashing entire releases. This avoids large
query-memory grants on SQL Server Express under memory pressure. SQL failures
name the affected table and operation; the 180-second timeout remains bounded.

`Validate-DMDImport.ps1` includes pricing counts, zero/missing amounts and
referential checks. Add `-XmlPath $release` for the full XML comparison.

Example joins (raw source amounts):

```sql
SELECT a.appid, a.nm, p.price, p.pricedt, p.price_prev, l.descr AS price_basis
FROM dbo.ampp a
JOIN dbo.ampp_price p ON p.appid = a.appid
LEFT JOIN dbo.lookup l ON l.type = 'PRICE_BASIS' AND l.cd = p.price_basiscd;

SELECT v.vppid, v.nm, t.price, t.dt, t.prevprice, l.descr AS payment_category
FROM dbo.vmpp v
JOIN dbo.vmpp_drugtariffinfo t ON t.vppid = v.vppid
LEFT JOIN dbo.lookup l ON l.type = 'DT_PAYMENT_CATEGORY' AND l.cd = t.pay_catcd;
```

## Complete Workflow

### Initial Setup
1. **Prerequisites**
   - SQL Server instance available
   - TRUD API key stored in Windows Credential Manager as 'TRUD_API'
   - PowerShell 5.1+ with SqlServer module

2. **One-Command Setup**
   ```powershell
   cd DMD
   .\Complete-DMDWorkflow.ps1
   ```

### Manual Step-by-Step Process

1. **Check for New Releases**
   ```powershell
   .\Check-NewDMDRelease.ps1
   ```

2. **Download DM+D Data**
   ```powershell
   .\Download-DMDReleases.ps1
   ```

3. **Create Database Schema**
   ```powershell
   # Run the corrected schema creation script
   sqlcmd -S "YourServer\Instance" -E -i "create-database-dmd.sql"
   ```

4. **Import All Data**
   ```powershell
   # Use the standalone imports for complete data loading
   cd StandaloneImports
   .\Run-AllImports.ps1 -ServerInstance "YourServer\Instance"
   ```

5. **Validate Import**
   ```powershell
   # Validate with random sampling
   cd ..
   .\Validate-RandomSamples.ps1 -SamplesPerTable 5
   
   # Or run full validation
   .\Validate-DMDImport.ps1 -ServerInstance "YourServer\Instance"
   ```

### Regular Maintenance

DM+D releases are published weekly (typically Mondays at 4:00 AM):

```powershell
# Weekly update routine
.\Check-NewDMDRelease.ps1           # Check for updates
.\Download-DMDReleases.ps1          # Download if new release found
cd StandaloneImports
.\Run-AllImports.ps1                # Import all data (~5 minutes)
cd ..
.\Validate-RandomSamples.ps1        # Validate data integrity
```

## File Structure

```
DMD/
├── README.md                       # This documentation
├── create-database-dmd.sql         # Corrected database schema (Nov 2025)
├── Complete-DMDWorkflow.ps1        # One-command setup script
├── Check-NewDMDRelease.ps1         # Check for new TRUD releases  
├── Download-DMDReleases.ps1        # Download from TRUD
├── Clear-DMDTables.ps1             # Clear all DM+D tables
├── Validate-DMDImport.ps1          # Validate imported data
├── Validate-RandomSamples.ps1      # Random sample validation
├── Cleanup-ObsoleteFiles.ps1       # Repository cleanup utility
├── SampleQueries.sql               # Sample queries
├── IMPLEMENTATION_SUMMARY.md       # Implementation notes
├── StandaloneImports/              # ⭐ All import scripts
│   ├── Run-AllImports.ps1          # Main import orchestrator
│   ├── Import-VTM.ps1              # Virtual Therapeutic Moieties
│   ├── Import-VMP.ps1              # Virtual Medical Products
│   ├── Import-AMP.ps1              # Actual Medical Products
│   ├── Import-VMPP.ps1             # Virtual Product Packs
│   ├── Import-AMPP.ps1             # Actual Product Packs
│   ├── Import-Ingredient.ps1       # Ingredient substances
│   ├── Import-Lookup.ps1           # Reference data
│   ├── Import-VMP-Ingredients.ps1  # VMP ingredient relationships
│   ├── Import-VMP-DrugRoutes.ps1   # Administration routes
│   ├── Import-VMP-DrugForms.ps1    # Pharmaceutical forms
│   ├── Import-BNF.ps1              # BNF codes
│   ├── Import-ATC.ps1              # ATC codes
│   ├── Import-GTIN.ps1             # Barcode data
│   └── README.md                   # Import documentation
├── SQL/                            # Additional SQL scripts
└── Queries/                        # Sample queries and analysis
    └── SampleQueries.sql           # Basic exploration queries
```

## Configuration

### TRUD API Credentials
Store your TRUD API key in Windows Credential Manager:
```powershell
# Using PowerShell
Import-Module CredentialManager
New-StoredCredential -Target "TRUD_API" -UserName "your-email@domain.com" -Password "your-api-key"
```

### Database Connection
Default settings target `SILENTPRIORY\SQLEXPRESS` with database name `dmd`. Override with parameters:
```powershell
.\Process-DMDData.ps1 -ServerInstance "YourServer\Instance" -Database "your_dmd_db"
```

## Query Examples

### Basic Product Hierarchy
```sql
-- Find all products containing "insulin"
SELECT 
    'VTM' as level, vtmid as id, nm as name
FROM vtm WHERE nm LIKE '%insulin%' AND invalid = 0
UNION ALL
SELECT 
    'VMP' as level, vpid as id, nm as name  
FROM vmp WHERE nm LIKE '%insulin%' AND invalid = 0
ORDER BY level, name;
```

### Prescribing Analysis
```sql
-- Sugar-free alternatives
SELECT 
    t.nm as ingredient,
    v.nm as product,
    CASE WHEN v.sug_f = 1 THEN 'Sugar-free' ELSE 'Regular' END as type
FROM vmp v
JOIN vtm t ON v.vtmid = t.vtmid
WHERE v.invalid = 0 AND t.nm LIKE '%paracetamol%'
ORDER BY v.sug_f DESC;
```

### Market Analysis  
```sql
-- Top suppliers by product count
SELECT TOP 10
    l.desc_val as supplier,
    COUNT(a.apid) as product_count
FROM amp a
JOIN lookup l ON a.suppcd = l.cd AND l.cdtype = 'SUPPLIER'
WHERE a.invalid = 0
GROUP BY l.desc_val
ORDER BY product_count DESC;
```

## Integration with SNOMED CT

The DM+D loader is designed to work alongside the existing SNOMED CT loader:

### Combined Setup
```powershell
# Set up both databases
cd MSSQL
.\Complete-SnomedWorkflow.ps1

cd ..\DMD  
.\Complete-DMDWorkflow.ps1
```

### Cross-Reference Queries
```sql
-- Link DM+D products to SNOMED CT concepts
SELECT 
    v.nm as dmd_product,
    ds.snomed_conceptid,
    d.term as snomed_term
FROM vmp v
JOIN dmd_snomed ds ON v.vpid = ds.dmd_id AND ds.dmd_type = 'VMP'  
JOIN snomedct.dbo.curr_description_f d ON ds.snomed_conceptid = d.conceptid
WHERE v.invalid = 0 AND d.active = '1' AND d.typeid = '900000000000003001';
```

## Troubleshooting

### Common Issues

**XML Processing Errors**
- Check XML file structure in `C:\DMD\CurrentReleases`
- Verify files are properly extracted from ZIP archives
- Review encoding (should be UTF-8)

**Database Connection Issues**  
- Verify SQL Server instance name and accessibility
- Check Windows Authentication or SQL credentials
- Ensure SqlServer PowerShell module is installed

**Performance Optimization**
```sql
-- Create additional indexes for common queries
CREATE INDEX IX_vmp_nm_include ON vmp(nm) INCLUDE (vpid, vtmid, invalid);
CREATE INDEX IX_amp_nm_include ON amp(nm) INCLUDE (apid, vpid, invalid);
```

**Data Validation Failures**
- Run `Validate-DMDImport.ps1` to identify specific issues
- Check referential integrity between hierarchy levels
- Review data completeness reports

### Log Files
- Workflow logs: `C:\DMD\workflow.log`
- Validation reports: `C:\DMD\validation-report-*.txt`  
- Release tracking: `C:\DMD\last_checked_releases.json`

## API Integration

### PowerShell Module Development
```powershell
# Example function to search DM+D
function Get-DMDProduct {
    param([string]$SearchTerm, [string]$Level = 'VMP')
    
    $query = "SELECT TOP 50 * FROM $Level.ToLower() WHERE nm LIKE '%$SearchTerm%' AND invalid = 0"
    Invoke-Sqlcmd -ServerInstance $DMDServer -Database 'dmd' -Query $query
}
```

### REST API Wrapper
Consider building REST API endpoints for common DM+D queries to support web applications and integration systems.

## Best Practices

### Data Refresh Strategy
- **Production**: Weekly automated updates on Tuesday mornings  
- **Development**: Monthly updates or as needed
- **Testing**: Use static datasets for consistent test results

### Performance Considerations
- Enable database compression for large tables
- Partition historical data by date ranges
- Consider read replicas for reporting workloads

### Security
- Use Windows Authentication where possible
- Implement row-level security for multi-tenant scenarios  
- Audit access to commercial pricing data

## Extensions and Customization

### Additional Data Sources
- **EPD (Electronic Prescription Database)** - Prescription volume data
- **Drug Tariff** - Current pricing information
- **Yellow Card** - Adverse event reporting data

### Custom Views
```sql
-- Create convenience views for common queries
CREATE VIEW vw_prescribable_products AS
SELECT 
    v.vpid,
    v.nm as product_name,
    t.nm as active_ingredient,
    COUNT(a.apid) as available_brands
FROM vmp v
LEFT JOIN vtm t ON v.vtmid = t.vtmid
LEFT JOIN amp a ON v.vpid = a.vpid AND a.invalid = 0
WHERE v.invalid = 0 AND v.pres_f = 1
GROUP BY v.vpid, v.nm, t.nm;
```

## Contributions

This DM+D loader complements the existing SNOMED CT infrastructure. Contributions welcome for:
- Additional database platforms (MySQL, PostgreSQL)  
- Enhanced XML parsing for edge cases
- Clinical decision support queries
- Integration with prescribing systems

## Support and Documentation

### NHS Resources
- **DM+D Browser**: https://services.nhsbsa.nhs.uk/dmd-browser/
- **Technical Specification**: Available via TRUD
- **Data Model Documentation**: NHS DM+D Data Model R2 v4.0

### Contact Points
- **Content queries**: dmdenquiries@nhsbsa.nhs.uk  
- **Technical support**: information.standards@nhs.net
- **TRUD access**: https://isd.digital.nhs.uk/trud

---

> 📝 **Note**: This DM+D loader is designed for building local database instances for analytics, reporting, or system integration. It is not a general-purpose pharmaceutical database but specifically targets NHS DM+D data structures and use cases.
