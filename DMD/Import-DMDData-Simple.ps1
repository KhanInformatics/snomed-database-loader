# DM+D Simple Import Script - Row-by-Row Approach
# This version processes each record individually to avoid batch failures
# Slower but more reliable for debugging data issues

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [string]$DataPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_10.1.0_20251013000001",
    [switch]$TrustServerCertificate
)

Write-Host "=== DM+D Simple Import (Row-by-Row) ===" -ForegroundColor Cyan
Write-Host "Server: $ServerInstance"
Write-Host "Database: $Database"
Write-Host "Data Path: $DataPath"

# Function to escape SQL values based on type
function Escape-SqlValue {
    param([string]$value, [string]$type = 'string')
    
    if ($null -eq $value -or $value -eq '') {
        return 'NULL'
    }
    
    switch ($type) {
        'string' {
            return "'" + $value.Replace("'", "''").Replace("`0", "") + "'"
        }
        'number' {
            if ($value -match '^\d+$') { return $value } else { return 'NULL' }
        }
        'decimal' {
            if ($value -match '^\d+\.?\d*$') { return $value } else { return 'NULL' }
        }
        'date' {
            if ($value -match '^\d{4}-\d{2}-\d{2}$') {
                return "'$value'"
            } else {
                return 'NULL'
            }
        }
        default {
            return "'" + $value.Replace("'", "''") + "'"
        }
    }
}

# Function to convert flag to BIT
function Convert-BoolFlag {
    param([string]$value)
    if ($value -eq '1') { return 1 } else { return 0 }
}

# Import VTMs
Write-Host "`nImporting Virtual Therapeutic Moieties (VTMs)..." -ForegroundColor Yellow
$vtmFile = Join-Path $DataPath "f_vtm2_3091025.xml"
if (Test-Path $vtmFile) {
    [xml]$vtmXml = Get-Content $vtmFile
    $vtmCount = 0
    $vtmErrors = 0
    
    foreach ($vtm in $vtmXml.VIRTUAL_THERAPEUTIC_MOIETIES.VTM) {
        try {
            $invalid = Convert-BoolFlag $vtm.INVALID
            $sql = "INSERT INTO vtm (vtmid,invalid,nm,abbrevnm,vtmidprev,vtmiddt) VALUES ($(Escape-SqlValue $vtm.VTMID),$invalid,$(Escape-SqlValue $vtm.NM),$(Escape-SqlValue $vtm.ABBREVNM),$(Escape-SqlValue $vtm.VTMIDPREV),$(Escape-SqlValue $vtm.VTMIDDT -type date))"
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop | Out-Null
            $vtmCount++
            
            if ($vtmCount % 100 -eq 0) {
                Write-Host "  Processed $vtmCount VTMs..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
        } catch {
            $vtmErrors++
            if ($vtmErrors -le 10) {
                Write-Warning "Error importing VTM $($vtm.VTMID): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "✅ Imported $vtmCount VTMs ($vtmErrors errors)" -ForegroundColor Green
}

# Import VMPs with detailed error reporting
Write-Host "`nImporting Virtual Medical Products (VMPs)..." -ForegroundColor Yellow
$vmpFile = Join-Path $DataPath "f_vmp2_3091025.xml"
if (Test-Path $vmpFile) {
    [xml]$vmpXml = Get-Content $vmpFile
    $vmpCount = 0
    $vmpErrors = 0
    $vmpIndex = 0
    
    foreach ($vmp in $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
        $vmpIndex++
        
        try {
            # Check if this VPID already exists (handle duplicates in XML)
            $checkSql = "SELECT COUNT(*) as cnt FROM vmp WHERE vpid = $(Escape-SqlValue $vmp.VPID)"
            $exists = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $checkSql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop
            
            if ($exists.cnt -gt 0) {
                # Skip duplicate - already imported
                continue
            }
            
            $invalid = Convert-BoolFlag $vmp.INVALID
            $sugF = Convert-BoolFlag $vmp.SUG_F
            $gluF = Convert-BoolFlag $vmp.GLU_F
            $presF = Convert-BoolFlag $vmp.PRES_F
            $cfcF = Convert-BoolFlag $vmp.CFC_F
            
            $sql = "INSERT INTO vmp (vpid,vpiddt,vpidprev,vtmid,invalid,nm,abbrevnm,basiscd,nmdt,nmprev,basis_prevcd,nmchangecd,comprodcd,pres_statcd,sug_f,glu_f,pres_f,cfc_f,non_availcd,non_availdt,df_indcd,udfs,udfs_uomcd,unit_dose_uomcd) VALUES ($(Escape-SqlValue $vmp.VPID),$(Escape-SqlValue $vmp.VPIDDT -type date),$(Escape-SqlValue $vmp.VPIDPREV),$(Escape-SqlValue $vmp.VTMID),$invalid,$(Escape-SqlValue $vmp.NM),$(Escape-SqlValue $vmp.ABBREVNM),$(Escape-SqlValue $vmp.BASISCD),$(Escape-SqlValue $vmp.NMDT -type date),$(Escape-SqlValue $vmp.NMPREV),$(Escape-SqlValue $vmp.BASIS_PREVCD),$(Escape-SqlValue $vmp.NMCHANGECD),$(Escape-SqlValue $vmp.COMPRODCD),$(Escape-SqlValue $vmp.PRES_STATCD),$sugF,$gluF,$presF,$cfcF,$(Escape-SqlValue $vmp.NON_AVAILCD),$(Escape-SqlValue $vmp.NON_AVAILDT -type date),$(Escape-SqlValue $vmp.DF_INDCD),$(Escape-SqlValue $vmp.UDFS -type decimal),$(Escape-SqlValue $vmp.UDFS_UOMCD),$(Escape-SqlValue $vmp.UNIT_DOSE_UOMCD))"
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop | Out-Null
            $vmpCount++
            
            if ($vmpCount % 100 -eq 0) {
                Write-Host "  Processed $vmpCount VMPs (index $vmpIndex)..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
        } catch {
            $vmpErrors++
            if ($vmpErrors -le 20) {
                Write-Warning "Error at index $vmpIndex importing VMP $($vmp.VPID) ($($vmp.NM)): $($_.Exception.Message)"
            }
            
            # Stop if too many consecutive errors
            if ($vmpErrors -gt 100) {
                Write-Error "Too many errors encountered. Stopping VMP import at index $vmpIndex."
                break
            }
        }
    }
    
    Write-Host "✅ Imported $vmpCount VMPs ($vmpErrors errors)" -ForegroundColor Green
}

# Import AMPs
Write-Host "`nImporting Actual Medical Products (AMPs)..." -ForegroundColor Yellow  
$ampFile = Join-Path $DataPath "f_amp2_3091025.xml"
if (Test-Path $ampFile) {
    [xml]$ampXml = Get-Content $ampFile
    $ampCount = 0
    $ampErrors = 0
    
    foreach ($amp in $ampXml.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP) {
        try {
            $invalid = Convert-BoolFlag $amp.INVALID
            $descF = Convert-BoolFlag $amp.DESC_F
            $emaF = Convert-BoolFlag $amp.EMA_F
            $parallelImportF = Convert-BoolFlag $amp.PARALLEL_IMPORT_F
            
            $sql = "INSERT INTO amp (apid,invalid,vpid,nm,abbrevnm,desc_f,nmdt,nm_prev,suppcd,lic_authcd,lic_auth_prevcd,lic_authchangecd,lic_authchangedt,combprodcd,flavourcd,ema_f,parallel_import_f,avail_restrictcd) VALUES ($(Escape-SqlValue $amp.APID),$invalid,$(Escape-SqlValue $amp.VPID),$(Escape-SqlValue $amp.NM),$(Escape-SqlValue $amp.ABBREVNM),$descF,$(Escape-SqlValue $amp.NMDT -type date),$(Escape-SqlValue $amp.NM_PREV),$(Escape-SqlValue $amp.SUPPCD),$(Escape-SqlValue $amp.LIC_AUTHCD),$(Escape-SqlValue $amp.LIC_AUTH_PREVCD),$(Escape-SqlValue $amp.LIC_AUTHCHANGECD),$(Escape-SqlValue $amp.LIC_AUTHCHANGEDT -type date),$(Escape-SqlValue $amp.COMBPRODCD),$(Escape-SqlValue $amp.FLAVOURCD),$emaF,$parallelImportF,$(Escape-SqlValue $amp.AVAIL_RESTRICTCD))"
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop | Out-Null
            $ampCount++
            
            if ($ampCount % 500 -eq 0) {
                Write-Host "  Processed $ampCount AMPs..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
        } catch {
            $ampErrors++
            if ($ampErrors -le 10) {
                Write-Warning "Error importing AMP $($amp.APID): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "✅ Imported $ampCount AMPs ($ampErrors errors)" -ForegroundColor Green
}

# Import VMPPs
Write-Host "`nImporting Virtual Medical Product Packs (VMPPs)..." -ForegroundColor Yellow
$vmppFile = Join-Path $DataPath "f_vmpp2_3091025.xml"
if (Test-Path $vmppFile) {
    [xml]$vmppXml = Get-Content $vmppFile
    $vmppCount = 0
    $vmppErrors = 0
    
    foreach ($vmpp in $vmppXml.VIRTUAL_MED_PRODUCT_PACK.VMPPS.VMPP) {
        try {
            $invalid = Convert-BoolFlag $vmpp.INVALID
            
            $sql = "INSERT INTO vmpp (vppid,invalid,nm,abbrevnm,vpid,qtyval,qty_uomcd,combpackcd) VALUES ($(Escape-SqlValue $vmpp.VPPID),$invalid,$(Escape-SqlValue $vmpp.NM),$(Escape-SqlValue $vmpp.ABBREVNM),$(Escape-SqlValue $vmpp.VPID),$(Escape-SqlValue $vmpp.QTYVAL -type decimal),$(Escape-SqlValue $vmpp.QTY_UOMCD),$(Escape-SqlValue $vmpp.COMBPACKCD))"
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop | Out-Null
            $vmppCount++
            
            if ($vmppCount % 500 -eq 0) {
                Write-Host "  Processed $vmppCount VMPPs..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
        } catch {
            $vmppErrors++
            if ($vmppErrors -le 10) {
                Write-Warning "Error importing VMPP $($vmpp.VPPID): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "✅ Imported $vmppCount VMPPs ($vmppErrors errors)" -ForegroundColor Green
}

# Import AMPPs
Write-Host "`nImporting Actual Medical Product Packs (AMPPs)..." -ForegroundColor Yellow
$amppFile = Join-Path $DataPath "f_ampp2_3091025.xml"
if (Test-Path $amppFile) {
    [xml]$amppXml = Get-Content $amppFile
    $amppCount = 0
    $amppErrors = 0
    
    foreach ($ampp in $amppXml.ACTUAL_MEDICINAL_PROD_PACKS.AMPPS.AMPP) {
        try {
            $invalid = Convert-BoolFlag $ampp.INVALID
            $hospF = Convert-BoolFlag $ampp.HOSP_F
            $brokenBulkF = Convert-BoolFlag $ampp.BROKEN_BULK_F
            $nurseF = Convert-BoolFlag $ampp.NURSE_F
            $enurseF = Convert-BoolFlag $ampp.ENURSE_F
            $dentF = Convert-BoolFlag $ampp.DENT_F
            
            $sql = "INSERT INTO ampp (appid,invalid,vppid,apid,nm,abbrevnm,legal_catcd,subp,disccd,hosp_f,broken_bulk_f,nurse_f,enurse_f,dent_f,prod_order_no) VALUES ($(Escape-SqlValue $ampp.APPID),$invalid,$(Escape-SqlValue $ampp.VPPID),$(Escape-SqlValue $ampp.APID),$(Escape-SqlValue $ampp.NM),$(Escape-SqlValue $ampp.ABBREVNM),$(Escape-SqlValue $ampp.LEGAL_CATCD),$(Escape-SqlValue $ampp.SUBP),$(Escape-SqlValue $ampp.DISCCD),$hospF,$brokenBulkF,$nurseF,$enurseF,$dentF,$(Escape-SqlValue $ampp.PROD_ORDER_NO))"
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop | Out-Null
            $amppCount++
            
            if ($amppCount % 1000 -eq 0) {
                Write-Host "  Processed $amppCount AMPPs..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
        } catch {
            $amppErrors++
            if ($amppErrors -le 10) {
                Write-Warning "Error importing AMPP $($ampp.APPID): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "✅ Imported $amppCount AMPPs ($amppErrors errors)" -ForegroundColor Green
}

# Import Lookup data
Write-Host "`nImporting Lookup values..." -ForegroundColor Yellow
$lookupFile = Join-Path $DataPath "f_lookup2_3091025.xml"
if (Test-Path $lookupFile) {
    [xml]$lookupXml = Get-Content $lookupFile
    $lookupCount = 0
    $lookupErrors = 0
    
    foreach ($info in $lookupXml.LOOKUP.INFO) {
        try {
            $sql = "INSERT INTO lookup (type,cd,descr) VALUES ($(Escape-SqlValue $info.TYPE),$(Escape-SqlValue $info.CD),$(Escape-SqlValue $info.DESC))"
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate -ErrorAction Stop | Out-Null
            $lookupCount++
            
            if ($lookupCount % 500 -eq 0) {
                Write-Host "  Processed $lookupCount lookup values..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
        } catch {
            $lookupErrors++
            if ($lookupErrors -le 10) {
                Write-Warning "Error importing lookup $($info.TYPE)/$($info.CD): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "✅ Imported $lookupCount lookup values ($lookupErrors errors)" -ForegroundColor Green
}

Write-Host "`n=== Import Complete ===" -ForegroundColor Cyan
Write-Host "Run Validate-DMDImport.ps1 to verify the import."
