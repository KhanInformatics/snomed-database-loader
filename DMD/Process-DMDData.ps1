# Process DM+D XML Data and Generate Import Scripts
# Save this as Process-DMDData.ps1

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [switch]$GenerateOnly = $false,
    [switch]$ExecuteOnly = $false
)

# Get the base directory where the releases are stored
$baseDir = "C:\DMD"
$currentReleasesDir = Join-Path $baseDir "CurrentReleases"
$outputFile = "C:\DMD\import-dmd.sql"

Write-Host "=== DM+D XML Data Processor ===" -ForegroundColor Cyan
Write-Host "Base Directory: $baseDir"
Write-Host "Current Releases: $currentReleasesDir"

if (-not (Test-Path $currentReleasesDir)) {
    Write-Error "CurrentReleases folder not found at $currentReleasesDir. Please run Download-DMDReleases.ps1 first."
    exit
}

# Function to escape SQL string values
function Escape-SqlString($value) {
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    # Replace single quotes with double single quotes and wrap in quotes
    return "'" + $value.ToString().Replace("'", "''") + "'"
}

# Function to format decimal values
function Format-SqlDecimal($value) {
    if ($null -eq $value -or $value -eq '' -or $value -eq '0' -or $value -eq '0.0') {
        return 'NULL'
    }
    return $value.ToString()
}

# Function to format bit values  
function Format-SqlBit($value) {
    if ($null -eq $value -or $value -eq '') {
        return '0'
    }
    if ($value.ToString().ToLower() -in @('true', '1', 'yes', 'y')) {
        return '1'
    }
    return '0'
}

# Function to format date values
function Format-SqlDate($value) {
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    try {
        $date = [DateTime]::ParseExact($value, "yyyyMMdd", $null)
        return "'" + $date.ToString("yyyy-MM-dd") + "'"
    } catch {
        return 'NULL'
    }
}

# Find DM+D XML files recursively
Write-Host "Searching for DM+D XML files..."
$xmlFiles = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "*.xml" | Where-Object { 
    $_.Name -notlike "*schema*" -and $_.Name -notlike "*example*" 
}

if ($xmlFiles.Count -eq 0) {
    Write-Error "No XML files found in $currentReleasesDir"
    exit
}

Write-Host "Found $($xmlFiles.Count) XML files to process:"
foreach ($file in $xmlFiles) {
    Write-Host "  $($file.FullName)"
}

# Generate SQL import script
if (-not $ExecuteOnly) {
    Write-Host "`nGenerating SQL import script..."

    # SQL Header
    $sqlHeader = @"
-- DM+D Data Import Script
-- Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
USE $Database;
GO

-- Disable constraints for faster loading
ALTER TABLE vmp NOCHECK CONSTRAINT ALL;
ALTER TABLE amp NOCHECK CONSTRAINT ALL;  
ALTER TABLE vmpp NOCHECK CONSTRAINT ALL;
ALTER TABLE ampp NOCHECK CONSTRAINT ALL;
ALTER TABLE vmp_ingredient NOCHECK CONSTRAINT ALL;
ALTER TABLE vmp_drugroute NOCHECK CONSTRAINT ALL;
ALTER TABLE vmp_drugform NOCHECK CONSTRAINT ALL;
ALTER TABLE dt_payment_category NOCHECK CONSTRAINT ALL;
ALTER TABLE ampp_drugtariffinfo NOCHECK CONSTRAINT ALL;
ALTER TABLE dmd_bnf NOCHECK CONSTRAINT ALL;
ALTER TABLE dmd_atc NOCHECK CONSTRAINT ALL;
ALTER TABLE gtin NOCHECK CONSTRAINT ALL;

-- Clear existing data
TRUNCATE TABLE gtin;
TRUNCATE TABLE dmd_atc;
TRUNCATE TABLE dmd_bnf;
TRUNCATE TABLE ampp_drugtariffinfo;
TRUNCATE TABLE dt_payment_category;
TRUNCATE TABLE vmp_drugform;
TRUNCATE TABLE vmp_drugroute;
TRUNCATE TABLE vmp_ingredient;
DELETE FROM ampp;
DELETE FROM vmpp;
DELETE FROM amp;
DELETE FROM vmp;
DELETE FROM vtm;
TRUNCATE TABLE lookup;

PRINT 'Starting DM+D data import...';

"@

    Set-Content -Path $outputFile -Value $sqlHeader

    foreach ($xmlFile in $xmlFiles) {
        Write-Host "Processing XML file: $($xmlFile.Name)..."
        
        try {
            [xml]$xmlContent = Get-Content -Path $xmlFile.FullName -Encoding UTF8
            
            # Add file processing comment
            Add-Content -Path $outputFile -Value "`n-- Processing file: $($xmlFile.Name)"
            
            # Process VTMs (Virtual Therapeutic Moieties)
            if ($xmlContent.VIRTUAL_THERAPEUTIC_MOIETIES.VTM) {
                Write-Host "  Processing VTMs..."
                Add-Content -Path $outputFile -Value "`n-- VTM (Virtual Therapeutic Moiety) data"
                foreach ($vtm in $xmlContent.VIRTUAL_THERAPEUTIC_MOIETIES.VTM) {
                    $sql = "INSERT INTO vtm (vtmid, invalid, nm, abbrevnm, vtmidprev, vtmiddt) VALUES (" +
                           "$($vtm.VTMID), " +
                           "$(Format-SqlBit $vtm.INVALID), " +
                           "$(Escape-SqlString $vtm.NM), " +
                           "$(Escape-SqlString $vtm.ABBREVNM), " +
                           "$(if($vtm.VTMIDPREV) { $vtm.VTMIDPREV } else { 'NULL' }), " +
                           "$(Format-SqlDate $vtm.VTMIDDT));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
            
            # Process VMPs (Virtual Medical Products)
            if ($xmlContent.VIRTUAL_MEDICINAL_PRODUCTS.VMPS.VMP) {
                Write-Host "  Processing VMPs..."
                Add-Content -Path $outputFile -Value "`n-- VMP (Virtual Medical Product) data"
                foreach ($vmp in $xmlContent.VIRTUAL_MEDICINAL_PRODUCTS.VMPS.VMP) {
                    $sql = "INSERT INTO vmp (vpid, vpiddt, vpidprev, vtmid, invalid, nm, abbrevnm, basiscd, nmdt, nmprev, basis_prevcd, nmchangecd, comprodcd, pres_statcd, sug_f, glu_f, pres_f, cfc_f, non_availcd, non_availdt, df_indcd, udfs, udfs_uomcd, unit_dose_uomcd) VALUES (" +
                           "$($vmp.VPID), " +
                           "$(Format-SqlDate $vmp.VPIDDT), " +
                           "$(if($vmp.VPIDPREV) { $vmp.VPIDPREV } else { 'NULL' }), " +
                           "$(if($vmp.VTMID) { $vmp.VTMID } else { 'NULL' }), " +
                           "$(Format-SqlBit $vmp.INVALID), " +
                           "$(Escape-SqlString $vmp.NM), " +
                           "$(Escape-SqlString $vmp.ABBREVNM), " +
                           "$(if($vmp.BASISCD) { $vmp.BASISCD } else { 'NULL' }), " +
                           "$(Format-SqlDate $vmp.NMDT), " +
                           "$(Escape-SqlString $vmp.NMPREV), " +
                           "$(if($vmp.BASIS_PREVCD) { $vmp.BASIS_PREVCD } else { 'NULL' }), " +
                           "$(if($vmp.NMCHANGECD) { $vmp.NMCHANGECD } else { 'NULL' }), " +
                           "$(if($vmp.COMPRODCD) { $vmp.COMPRODCD } else { 'NULL' }), " +
                           "$(if($vmp.PRES_STATCD) { $vmp.PRES_STATCD } else { 'NULL' }), " +
                           "$(Format-SqlBit $vmp.SUG_F), " +
                           "$(Format-SqlBit $vmp.GLU_F), " +
                           "$(Format-SqlBit $vmp.PRES_F), " +
                           "$(Format-SqlBit $vmp.CFC_F), " +
                           "$(if($vmp.NON_AVAILCD) { $vmp.NON_AVAILCD } else { 'NULL' }), " +
                           "$(Format-SqlDate $vmp.NON_AVAILDT), " +
                           "$(if($vmp.DF_INDCD) { $vmp.DF_INDCD } else { 'NULL' }), " +
                           "$(if($vmp.UDFS) { $vmp.UDFS } else { 'NULL' }), " +
                           "$(if($vmp.UDFS_UOMCD) { $vmp.UDFS_UOMCD } else { 'NULL' }), " +
                           "$(if($vmp.UNIT_DOSE_UOMCD) { $vmp.UNIT_DOSE_UOMCD } else { 'NULL' }));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
            
            # Process AMPs (Actual Medical Products)  
            if ($xmlContent.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP) {
                Write-Host "  Processing AMPs..."
                Add-Content -Path $outputFile -Value "`n-- AMP (Actual Medical Product) data"
                foreach ($amp in $xmlContent.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP) {
                    $sql = "INSERT INTO amp (apid, vpid, invalid, nm, abbrevnm, desc, nmdt, nm_prev, sup_cd, lic_authcd, lic_auth_prevcd, lic_authchangecd, de_dt, discdt, flavour_cd, ema, parallel_import, avail_restrictcd) VALUES (" +
                           "$($amp.APID), " +
                           "$(if($amp.VPID) { $amp.VPID } else { 'NULL' }), " +
                           "$(Format-SqlBit $amp.INVALID), " +
                           "$(Escape-SqlString $amp.NM), " +
                           "$(Escape-SqlString $amp.ABBREVNM), " +
                           "$(Escape-SqlString $amp.DESC), " +
                           "$(Format-SqlDate $amp.NMDT), " +
                           "$(Escape-SqlString $amp.NM_PREV), " +
                           "$(if($amp.SUP_CD) { $amp.SUP_CD } else { 'NULL' }), " +
                           "$(if($amp.LIC_AUTHCD) { $amp.LIC_AUTHCD } else { 'NULL' }), " +
                           "$(if($amp.LIC_AUTH_PREVCD) { $amp.LIC_AUTH_PREVCD } else { 'NULL' }), " +
                           "$(if($amp.LIC_AUTHCHANGECD) { $amp.LIC_AUTHCHANGECD } else { 'NULL' }), " +
                           "$(Format-SqlDate $amp.DE_DT), " +
                           "$(Format-SqlDate $amp.DISCDT), " +
                           "$(if($amp.FLAVOUR_CD) { $amp.FLAVOUR_CD } else { 'NULL' }), " +
                           "$(Format-SqlBit $amp.EMA), " +
                           "$(Format-SqlBit $amp.PARALLEL_IMPORT), " +
                           "$(if($amp.AVAIL_RESTRICTCD) { $amp.AVAIL_RESTRICTCD } else { 'NULL' }));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
                
                # Process VMPs (Virtual Medical Products)
                if ($dmdBody.VMPS.VMP) {
                    Write-Host "  Processing VMPs..."
                    Add-Content -Path $outputFile -Value "`n-- VMP (Virtual Medical Product) data"
                    foreach ($vmp in $dmdBody.VMPS.VMP) {
                        $sql = "INSERT INTO vmp (vpid, vpiddt, vpidprev, vtmid, invalid, nm, abbrevnm, basiscd, nmdt, nmprev, basis_prevcd, nmchangecd, comprodcd, pres_statcd, sug_f, glu_f, pres_f, cfc_f, non_availcd, non_availdt, df_indcd, udfs, udfs_uomcd, unit_dose_uomcd) VALUES (" +
                               "$($vmp.VPID), " +
                               "$(Format-SqlDate $vmp.VPIDDT), " +
                               "$(if($vmp.VPIDPREV) { $vmp.VPIDPREV } else { 'NULL' }), " +
                               "$(if($vmp.VTMID) { $vmp.VTMID } else { 'NULL' }), " +
                               "$(Format-SqlBit $vmp.INVALID), " +
                               "$(Escape-SqlString $vmp.NM), " +
                               "$(Escape-SqlString $vmp.ABBREVNM), " +
                               "$(if($vmp.BASISCD) { $vmp.BASISCD } else { 'NULL' }), " +
                               "$(Format-SqlDate $vmp.NMDT), " +
                               "$(Escape-SqlString $vmp.NMPREV), " +
                               "$(if($vmp.BASIS_PREVCD) { $vmp.BASIS_PREVCD } else { 'NULL' }), " +
                               "$(if($vmp.NMCHANGECD) { $vmp.NMCHANGECD } else { 'NULL' }), " +
                               "$(if($vmp.COMPRODCD) { $vmp.COMPRODCD } else { 'NULL' }), " +
                               "$(if($vmp.PRES_STATCD) { $vmp.PRES_STATCD } else { 'NULL' }), " +
                               "$(Format-SqlBit $vmp.SUG_F), " +
                               "$(Format-SqlBit $vmp.GLU_F), " +
                               "$(Format-SqlBit $vmp.PRES_F), " +
                               "$(Format-SqlBit $vmp.CFC_F), " +
                               "$(if($vmp.NON_AVAILCD) { $vmp.NON_AVAILCD } else { 'NULL' }), " +
                               "$(Format-SqlDate $vmp.NON_AVAILDT), " +
                               "$(if($vmp.DF_INDCD) { $vmp.DF_INDCD } else { 'NULL' }), " +
                               "$(Format-SqlDecimal $vmp.UDFS), " +
                               "$(if($vmp.UDFS_UOMCD) { $vmp.UDFS_UOMCD } else { 'NULL' }), " +
                               "$(if($vmp.UNIT_DOSE_UOMCD) { $vmp.UNIT_DOSE_UOMCD } else { 'NULL' }));"
                        Add-Content -Path $outputFile -Value $sql
                    }
                }
                
                # Process AMPs (Actual Medical Products)
                if ($dmdBody.AMPS.AMP) {
                    Write-Host "  Processing AMPs..."
                    Add-Content -Path $outputFile -Value "`n-- AMP (Actual Medical Product) data"
                    foreach ($amp in $dmdBody.AMPS.AMP) {
                        $sql = "INSERT INTO amp (apid, invalid, vpid, nm, abbrevnm, desc_f, nmdt, nm_prev, suppcd, lic_authcd, lic_auth_prevcd, lic_authchangecd, lic_authchangedt, combprodcd, flavourcd, ema_f, parallel_import_f, avail_restrictcd) VALUES (" +
                               "$($amp.APID), " +
                               "$(Format-SqlBit $amp.INVALID), " +
                               "$(if($amp.VPID) { $amp.VPID } else { 'NULL' }), " +
                               "$(Escape-SqlString $amp.NM), " +
                               "$(Escape-SqlString $amp.ABBREVNM), " +
                               "$(Format-SqlBit $amp.DESC_F), " +
                               "$(Format-SqlDate $amp.NMDT), " +
                               "$(Escape-SqlString $amp.NM_PREV), " +
                               "$(if($amp.SUPPCD) { $amp.SUPPCD } else { 'NULL' }), " +
                               "$(if($amp.LIC_AUTHCD) { $amp.LIC_AUTHCD } else { 'NULL' }), " +
                               "$(if($amp.LIC_AUTH_PREVCD) { $amp.LIC_AUTH_PREVCD } else { 'NULL' }), " +
                               "$(if($amp.LIC_AUTHCHANGECD) { $amp.LIC_AUTHCHANGECD } else { 'NULL' }), " +
                               "$(Format-SqlDate $amp.LIC_AUTHCHANGEDT), " +
                               "$(if($amp.COMBPRODCD) { $amp.COMBPRODCD } else { 'NULL' }), " +
                               "$(if($amp.FLAVOURCD) { $amp.FLAVOURCD } else { 'NULL' }), " +
                               "$(Format-SqlBit $amp.EMA_F), " +
                               "$(Format-SqlBit $amp.PARALLEL_IMPORT_F), " +
                               "$(if($amp.AVAIL_RESTRICTCD) { $amp.AVAIL_RESTRICTCD } else { 'NULL' }));"
                        Add-Content -Path $outputFile -Value $sql
                    }
                }
                
                # Process VMPPs (Virtual Medical Product Packs)
                if ($dmdBody.VMPPS.VMPP) {
                    Write-Host "  Processing VMPPs..."
                    Add-Content -Path $outputFile -Value "`n-- VMPP (Virtual Medical Product Pack) data"
                    foreach ($vmpp in $dmdBody.VMPPS.VMPP) {
                        $sql = "INSERT INTO vmpp (vppid, invalid, nm, abbrevnm, vpid, qtyval, qty_uomcd, combpackcd) VALUES (" +
                               "$($vmpp.VPPID), " +
                               "$(Format-SqlBit $vmpp.INVALID), " +
                               "$(Escape-SqlString $vmpp.NM), " +
                               "$(Escape-SqlString $vmpp.ABBREVNM), " +
                               "$(if($vmpp.VPID) { $vmpp.VPID } else { 'NULL' }), " +
                               "$(Format-SqlDecimal $vmpp.QTYVAL), " +
                               "$(if($vmpp.QTY_UOMCD) { $vmpp.QTY_UOMCD } else { 'NULL' }), " +
                               "$(if($vmpp.COMBPACKCD) { $vmpp.COMBPACKCD } else { 'NULL' }));"
                        Add-Content -Path $outputFile -Value $sql
                    }
                }
                
                # Process AMPPs (Actual Medical Product Packs)
                if ($dmdBody.AMPPS.AMPP) {
                    Write-Host "  Processing AMPPs..."
                    Add-Content -Path $outputFile -Value "`n-- AMPP (Actual Medical Product Pack) data"
                    foreach ($ampp in $dmdBody.AMPPS.AMPP) {
                        $sql = "INSERT INTO ampp (appid, invalid, vppid, apid, nm, abbrevnm, legal_catcd, subp, disccd, hosp_f, broken_bulk_f, nurse_f, enurse_f, dent_f, prod_order_no) VALUES (" +
                               "$($ampp.APPID), " +
                               "$(Format-SqlBit $ampp.INVALID), " +
                               "$(if($ampp.VPPID) { $ampp.VPPID } else { 'NULL' }), " +
                               "$(if($ampp.APID) { $ampp.APID } else { 'NULL' }), " +
                               "$(Escape-SqlString $ampp.NM), " +
                               "$(Escape-SqlString $ampp.ABBREVNM), " +
                               "$(if($ampp.LEGAL_CATCD) { $ampp.LEGAL_CATCD } else { 'NULL' }), " +
                               "$(Format-SqlDecimal $ampp.SUBP), " +
                               "$(if($ampp.DISCCD) { $ampp.DISCCD } else { 'NULL' }), " +
                               "$(Format-SqlBit $ampp.HOSP_F), " +
                               "$(Format-SqlBit $ampp.BROKEN_BULK_F), " +
                               "$(Format-SqlBit $ampp.NURSE_F), " +
                               "$(Format-SqlBit $ampp.ENURSE_F), " +
                               "$(Format-SqlBit $ampp.DENT_F), " +
                               "$(Escape-SqlString $ampp.PROD_ORDER_NO));"
                        Add-Content -Path $outputFile -Value $sql
                    }
                }
                
                # Process Lookup data
                if ($dmdBody.LOOKUPS.LOOKUP) {
                    Write-Host "  Processing Lookups..."
                    Add-Content -Path $outputFile -Value "`n-- Lookup data"
                    foreach ($lookup in $dmdBody.LOOKUPS.LOOKUP) {
                        $sql = "INSERT INTO lookup (cd, cdtype, cddt, cdprev, desc_val) VALUES (" +
                               "$($lookup.CD), " +
                               "$(Escape-SqlString $lookup.CDTYPE), " +
                               "$(Format-SqlDate $lookup.CDDT), " +
                               "$(if($lookup.CDPREV) { $lookup.CDPREV } else { 'NULL' }), " +
                               "$(Escape-SqlString $lookup.DESC));"
                        Add-Content -Path $outputFile -Value $sql
                    }
                }
            }
            
            # Check for supplementary data (BNF/ATC file format)
            if ($xmlContent.SUPPLYBODY -or $xmlFile.Name -like "*supplementary*" -or $xmlFile.Name -like "*bnf*" -or $xmlFile.Name -like "*atc*") {
                Write-Host "  Processing supplementary data (BNF/ATC)..."
                
                # This would need to be adapted based on the actual structure of supplementary files
                # The structure may vary, so this is a placeholder for the common patterns
                
                if ($xmlContent.SelectNodes("//BNF")) {
                    Add-Content -Path $outputFile -Value "`n-- BNF (British National Formulary) data"
                    foreach ($bnf in $xmlContent.SelectNodes("//BNF")) {
                        if ($bnf.VPID -and $bnf.CD) {
                            $sql = "INSERT INTO dmd_bnf (vpid, bnf_code) VALUES ($($bnf.VPID), $(Escape-SqlString $bnf.CD));"
                            Add-Content -Path $outputFile -Value $sql
                        }
                    }
                }
                
                if ($xmlContent.SelectNodes("//ATC")) {
                    Add-Content -Path $outputFile -Value "`n-- ATC (Anatomical Therapeutic Chemical) data"
                    foreach ($atc in $xmlContent.SelectNodes("//ATC")) {
                        if ($atc.VPID -and $atc.CD) {
                            $sql = "INSERT INTO dmd_atc (vpid, atc_code) VALUES ($($atc.VPID), $(Escape-SqlString $atc.CD));"
                            Add-Content -Path $outputFile -Value $sql
                        }
                    }
                }
            }
            
        } catch {
            Write-Warning "Error processing $($xmlFile.Name): $($_.Exception.Message)"
        }
    }

    # SQL Footer  
    $sqlFooter = @"

-- Re-enable constraints
ALTER TABLE vmp CHECK CONSTRAINT ALL;
ALTER TABLE amp CHECK CONSTRAINT ALL;
ALTER TABLE vmpp CHECK CONSTRAINT ALL;
ALTER TABLE ampp CHECK CONSTRAINT ALL;
ALTER TABLE vmp_ingredient CHECK CONSTRAINT ALL;
ALTER TABLE vmp_drugroute CHECK CONSTRAINT ALL;
ALTER TABLE vmp_drugform CHECK CONSTRAINT ALL;
ALTER TABLE dt_payment_category CHECK CONSTRAINT ALL;
ALTER TABLE ampp_drugtariffinfo CHECK CONSTRAINT ALL;
ALTER TABLE dmd_bnf CHECK CONSTRAINT ALL;
ALTER TABLE dmd_atc CHECK CONSTRAINT ALL;
ALTER TABLE gtin CHECK CONSTRAINT ALL;

-- Update statistics
UPDATE STATISTICS vtm;
UPDATE STATISTICS vmp;
UPDATE STATISTICS amp;
UPDATE STATISTICS vmpp;
UPDATE STATISTICS ampp;
UPDATE STATISTICS lookup;

PRINT 'DM+D data import completed successfully';
PRINT 'Records imported:';
SELECT 'VTMs' as Table_Name, COUNT(*) as Record_Count FROM vtm
UNION ALL
SELECT 'VMPs', COUNT(*) FROM vmp  
UNION ALL
SELECT 'AMPs', COUNT(*) FROM amp
UNION ALL
SELECT 'VMPPs', COUNT(*) FROM vmpp
UNION ALL
SELECT 'AMPPs', COUNT(*) FROM ampp
UNION ALL
SELECT 'Lookups', COUNT(*) FROM lookup;
"@

    Add-Content -Path $outputFile -Value $sqlFooter
    Write-Host "✅ SQL import script generated: $outputFile"
}

# Execute the SQL script if requested
if (-not $GenerateOnly) {
    Write-Host "`nExecuting SQL import script..."
    
    try {
        $sqlcmdCommand = "sqlcmd -S `"$ServerInstance`" -d `"$Database`" -i `"$outputFile`""
        Write-Host "Executing: $sqlcmdCommand"
        Invoke-Expression $sqlcmdCommand
        Write-Host "✅ DM+D data import completed successfully!"
    } catch {
        Write-Error "Error executing SQL script: $($_.Exception.Message)"
        Write-Host "You can manually execute the script: $outputFile"
    }
}

Write-Host "`n=== DM+D Processing Complete ===" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1. Run Validate-DMDImport.ps1 to validate the imported data"
Write-Host "2. Use queries in the DMD\Queries folder to explore the data"