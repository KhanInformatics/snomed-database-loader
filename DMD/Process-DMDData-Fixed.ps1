# DM+D XML Data Processor - Fixed Version
# Processes actual DM+D XML files into SQL Server database

param(
    [string]$BaseDir = "C:\DMD",
    [string]$Server = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd"
)

$currentReleasesDir = Join-Path $BaseDir "CurrentReleases"
$outputFile = Join-Path $BaseDir "import-dmd.sql"

Write-Host "=== DM+D XML Data Processor ==="
Write-Host "Base Directory: $BaseDir"
Write-Host "Current Releases: $currentReleasesDir"

# Helper functions
function Escape-SqlString($value) {
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    return "'" + $value.ToString().Replace("'", "''") + "'"
}

function Format-SqlBit($value) {
    if ($null -eq $value -or $value -eq '' -or $value -eq '0') {
        return '0'
    }
    return '1'
}

function Format-SqlDate($value) {
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    try {
        if ($value -match '^\d{4}-\d{2}-\d{2}$') {
            return "'$value'"
        }
        $date = [DateTime]::ParseExact($value, "yyyy-MM-dd", $null)
        return "'" + $date.ToString("yyyy-MM-dd") + "'"
    } catch {
        return 'NULL'
    }
}

# Find DM+D XML files
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

Write-Host "Generating SQL import script..."

# Create SQL header
$sqlHeader = @"
USE $Database;

-- Clear existing data
DELETE FROM ampp;
DELETE FROM amp;
DELETE FROM vmpp;
DELETE FROM vmp;
DELETE FROM vtm;
DELETE FROM lookup;
DELETE FROM ingredient;
DELETE FROM vtm_ingredient;

PRINT 'Starting DM+D data import...';

"@

Set-Content -Path $outputFile -Value $sqlHeader

foreach ($xmlFile in $xmlFiles) {
    Write-Host "Processing XML file: $($xmlFile.Name)..."
    
    try {
        [xml]$xmlContent = Get-Content -Path $xmlFile.FullName -Encoding UTF8
        
        Add-Content -Path $outputFile -Value "`n-- Processing file: $($xmlFile.Name)"
        
        # Process based on root element
        $rootElement = $xmlContent.DocumentElement.LocalName
        
        switch ($rootElement) {
            "VIRTUAL_THERAPEUTIC_MOIETIES" {
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
            
            "VIRTUAL_MED_PRODUCTS" {
                Write-Host "  Processing VMPs..."
                Add-Content -Path $outputFile -Value "`n-- VMP (Virtual Medical Product) data"
                
                foreach ($vmp in $xmlContent.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
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
            
            "ACTUAL_MEDICINAL_PRODUCTS" {
                Write-Host "  Processing AMPs..."
                Add-Content -Path $outputFile -Value "`n-- AMP (Actual Medical Product) data"
                
                foreach ($amp in $xmlContent.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP) {
                    $sql = "INSERT INTO amp (apid, vpid, invalid, nm, abbrevnm, desc_val, nmdt, nm_prev, sup_cd, lic_authcd, lic_auth_prevcd, lic_authchangecd, de_dt, discdt, flavour_cd, ema, parallel_import, avail_restrictcd) VALUES (" +
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
            
            "VIRTUAL_MED_PRODUCT_PACK" {
                Write-Host "  Processing VMPPs..."
                Add-Content -Path $outputFile -Value "`n-- VMPP (Virtual Medical Product Pack) data"
                
                foreach ($vmpp in $xmlContent.VIRTUAL_MED_PRODUCT_PACK.VMPPS.VMPP) {
                    $sql = "INSERT INTO vmpp (vppid, vpid, qtyval, qty_uomcd, combpackcd, invalid, nm, abbrevnm, basiscd, nmdt, nmprev, basis_prevcd, nmchangecd, comprodcd, pres_statcd, sug_f, glu_f, pres_f, cfc_f, non_availcd, non_availdt, df_indcd) VALUES (" +
                           "$($vmpp.VPPID), " +
                           "$(if($vmpp.VPID) { $vmpp.VPID } else { 'NULL' }), " +
                           "$(if($vmpp.QTYVAL) { $vmpp.QTYVAL } else { 'NULL' }), " +
                           "$(if($vmpp.QTY_UOMCD) { $vmpp.QTY_UOMCD } else { 'NULL' }), " +
                           "$(if($vmpp.COMBPACKCD) { $vmpp.COMBPACKCD } else { 'NULL' }), " +
                           "$(Format-SqlBit $vmpp.INVALID), " +
                           "$(Escape-SqlString $vmpp.NM), " +
                           "$(Escape-SqlString $vmpp.ABBREVNM), " +
                           "$(if($vmpp.BASISCD) { $vmpp.BASISCD } else { 'NULL' }), " +
                           "$(Format-SqlDate $vmpp.NMDT), " +
                           "$(Escape-SqlString $vmpp.NMPREV), " +
                           "$(if($vmpp.BASIS_PREVCD) { $vmpp.BASIS_PREVCD } else { 'NULL' }), " +
                           "$(if($vmpp.NMCHANGECD) { $vmpp.NMCHANGECD } else { 'NULL' }), " +
                           "$(if($vmpp.COMPRODCD) { $vmpp.COMPRODCD } else { 'NULL' }), " +
                           "$(if($vmpp.PRES_STATCD) { $vmpp.PRES_STATCD } else { 'NULL' }), " +
                           "$(Format-SqlBit $vmpp.SUG_F), " +
                           "$(Format-SqlBit $vmpp.GLU_F), " +
                           "$(Format-SqlBit $vmpp.PRES_F), " +
                           "$(Format-SqlBit $vmpp.CFC_F), " +
                           "$(if($vmpp.NON_AVAILCD) { $vmpp.NON_AVAILCD } else { 'NULL' }), " +
                           "$(Format-SqlDate $vmpp.NON_AVAILDT), " +
                           "$(if($vmpp.DF_INDCD) { $vmpp.DF_INDCD } else { 'NULL' }));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
            
            "ACTUAL_MEDICINAL_PROD_PACKS" {
                Write-Host "  Processing AMPPs..."
                Add-Content -Path $outputFile -Value "`n-- AMPP (Actual Medical Product Pack) data"
                
                foreach ($ampp in $xmlContent.ACTUAL_MEDICINAL_PROD_PACKS.AMPPS.AMPP) {
                    $sql = "INSERT INTO ampp (appid, invalid, vppid, apid, nm, abbrevnm, legal_catcd, subp, disccd, hosp_f, broken_bulk_f, nurse_f, enurse_f, dent_f, prod_order_no) VALUES (" +
                           "$($ampp.APPID), " +
                           "$(Format-SqlBit $ampp.INVALID), " +
                           "$(if($ampp.VPPID) { $ampp.VPPID } else { 'NULL' }), " +
                           "$(if($ampp.APID) { $ampp.APID } else { 'NULL' }), " +
                           "$(Escape-SqlString $ampp.NM), " +
                           "$(Escape-SqlString $ampp.ABBREVNM), " +
                           "$(if($ampp.LEGAL_CATCD) { $ampp.LEGAL_CATCD } else { 'NULL' }), " +
                           "$(if($ampp.SUBP) { $ampp.SUBP } else { 'NULL' }), " +
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
            
            "LOOKUP" {
                Write-Host "  Processing Lookups..."
                Add-Content -Path $outputFile -Value "`n-- Lookup data"
                
                foreach ($info in $xmlContent.LOOKUP.INFO) {
                    $sql = "INSERT INTO lookup (cd, cdtype, cddt, cdprev, desc_val) VALUES (" +
                           "$($info.CD), " +
                           "$(Escape-SqlString $info.CDTYPE), " +
                           "$(Format-SqlDate $info.CDDT), " +
                           "$(if($info.CDPREV) { $info.CDPREV } else { 'NULL' }), " +
                           "$(Escape-SqlString $info.DESC));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
            
            "INGREDIENT_SUBSTANCES" {
                Write-Host "  Processing Ingredients..."
                Add-Content -Path $outputFile -Value "`n-- Ingredient data"
                
                foreach ($ing in $xmlContent.INGREDIENT_SUBSTANCES.ING) {
                    $sql = "INSERT INTO ingredient (isid, isiddt, isidprev, invalid, nm) VALUES (" +
                           "$($ing.ISID), " +
                           "$(Format-SqlDate $ing.ISIDDT), " +
                           "$(if($ing.ISIDPREV) { $ing.ISIDPREV } else { 'NULL' }), " +
                           "$(Format-SqlBit $ing.INVALID), " +
                           "$(Escape-SqlString $ing.NM));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
            
            "VTM_INGREDIENTS" {
                Write-Host "  Processing VTM-Ingredient relationships..."
                Add-Content -Path $outputFile -Value "`n-- VTM-Ingredient relationship data"
                
                foreach ($vtming in $xmlContent.VTM_INGREDIENTS.VTMING) {
                    $sql = "INSERT INTO vtm_ingredient (vtmid, isid, basis_strntcd, bs_subid, strnt_nmrtr_val, strnt_nmrtr_uomcd, strnt_dnmtr_val, strnt_dnmtr_uomcd) VALUES (" +
                           "$($vtming.VTMID), " +
                           "$($vtming.ISID), " +
                           "$(if($vtming.BASIS_STRNTCD) { $vtming.BASIS_STRNTCD } else { 'NULL' }), " +
                           "$(if($vtming.BS_SUBID) { $vtming.BS_SUBID } else { 'NULL' }), " +
                           "$(if($vtming.STRNT_NMRTR_VAL) { $vtming.STRNT_NMRTR_VAL } else { 'NULL' }), " +
                           "$(if($vtming.STRNT_NMRTR_UOMCD) { $vtming.STRNT_NMRTR_UOMCD } else { 'NULL' }), " +
                           "$(if($vtming.STRNT_DNMTR_VAL) { $vtming.STRNT_DNMTR_VAL } else { 'NULL' }), " +
                           "$(if($vtming.STRNT_DNMTR_UOMCD) { $vtming.STRNT_DNMTR_UOMCD } else { 'NULL' }));"
                    Add-Content -Path $outputFile -Value $sql
                }
            }
            
            "HISTORY" {
                Write-Host "  Skipping History data (not imported to main tables)..."
            }
            
            default {
                Write-Warning "Unknown XML structure: $rootElement in file $($xmlFile.Name)"
            }
        }
        
    } catch {
        Write-Error "Error processing $($xmlFile.Name): $($_.Exception.Message)"
    }
}

# Add completion message
$sqlFooter = @"

PRINT 'DM+D data import completed successfully';

-- Record counts
SELECT 'VTMs' as Table_Name, COUNT(*) as Record_Count FROM vtm
UNION ALL
SELECT 'VMPs' as Table_Name, COUNT(*) as Record_Count FROM vmp
UNION ALL
SELECT 'AMPs' as Table_Name, COUNT(*) as Record_Count FROM amp
UNION ALL
SELECT 'VMPPs' as Table_Name, COUNT(*) as Record_Count FROM vmpp
UNION ALL
SELECT 'AMPPs' as Table_Name, COUNT(*) as Record_Count FROM ampp
UNION ALL
SELECT 'Lookups' as Table_Name, COUNT(*) as Record_Count FROM lookup
UNION ALL
SELECT 'Ingredients' as Table_Name, COUNT(*) as Record_Count FROM ingredient
UNION ALL
SELECT 'VTM-Ingredients' as Table_Name, COUNT(*) as Record_Count FROM vtm_ingredient;
"@

Add-Content -Path $outputFile -Value $sqlFooter

Write-Host "✅ SQL import script generated: $outputFile"

Write-Host "`nExecuting SQL import script..."
try {
    $result = sqlcmd -S $Server -d $Database -i $outputFile -E -C
    Write-Host $result
    Write-Host "✅ DM+D data import completed successfully!"
} catch {
    Write-Error "Failed to execute SQL script: $($_.Exception.Message)"
}

Write-Host "`n=== DM+D Processing Complete ==="
Write-Host "Next steps:"
Write-Host "1. Run Validate-DMDImport.ps1 to validate the imported data"
Write-Host "2. Use queries in the DMD\Queries folder to explore the data"