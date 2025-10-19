# Import-DMDData-Batched.ps1
# Imports DM+D data using batched SQL INSERT statements to avoid memory issues

param(
    [int]$BatchSize = 500
)

Import-Module SqlServer -ErrorAction Stop

$ServerInstance = "SILENTPRIORY\SQLEXPRESS"
$Database = "dmd"
$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_10.1.0_20251013000001"

# Helper function to escape SQL values
function Escape-SqlValue {
    param(
        [string]$value,
        [ValidateSet('string','date','decimal','number')]
        [string]$type = 'string'
    )
    if ([string]::IsNullOrWhiteSpace($value)) { return 'NULL' }
    switch ($type) {
        'decimal' { return $value }
        'number'  { return $value }
        'date'    { return "'" + $value.Replace("'","''") + "'" }
        default   { return "'" + $value.Replace("'","''") + "'" }
    }
}

# Helper function to convert boolean flags
function Convert-BoolFlag {
    param([string]$value)
    if ($value -eq '1') { return '1' }
    return '0'
}

# Helper function to get existing keys from a table
function Get-ExistingKeys {
    param(
        [string]$TableName,
        [string]$KeyColumn
    )
    
    $query = "SELECT $KeyColumn FROM $TableName"
    $results = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query -TrustServerCertificate -ErrorAction SilentlyContinue
    
    if ($results) {
        $keys = @{}
        foreach ($row in $results) {
            $keys[$row.$KeyColumn] = $true
        }
        return $keys
    }
    return @{}
}

# Helper function to execute batched INSERTs
function Invoke-BatchedInsert {
    param(
        [string]$TableName,
        [string]$Columns,
        [string[]]$Values,
        [int]$BatchSize
    )
    
    $totalRecords = $Values.Count
    $batchCount = [Math]::Ceiling($totalRecords / $BatchSize)
    
    Write-Host "Importing $totalRecords records into $TableName in $batchCount batches..."
    
    for ($i = 0; $i -lt $batchCount; $i++) {
        $start = $i * $BatchSize
        $end = [Math]::Min($start + $BatchSize, $totalRecords)
        $batchValues = $Values[$start..($end-1)]
        
        $sql = "INSERT INTO $TableName $Columns VALUES `n" + ($batchValues -join ",`n")
        
        try {
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql -TrustServerCertificate -ErrorAction Stop
            Write-Host "  Batch $($i+1)/$batchCount complete ($end/$totalRecords records)"
        }
        catch {
            Write-Error "Failed to insert batch $($i+1): $_"
            throw
        }
    }
}

# Import VTMs
Write-Host "Processing Virtual Therapeutic Moieties (VTMs)..."
$vtmFile = Join-Path $XmlPath "f_vtm2_3091025.xml"
if (Test-Path $vtmFile) {
    [xml]$vtmXml = Get-Content $vtmFile
    
    # Get existing VTM IDs from database
    Write-Host "  Checking for existing VTM records..."
    $existingVtmIds = Get-ExistingKeys -TableName "vtm" -KeyColumn "vtmid"
    $seenVtmIds = @{}
    
    $values = @()
    $duplicatesSkipped = 0
    
    foreach ($vtm in $vtmXml.VIRTUAL_THERAPEUTIC_MOIETIES.VTM) {
        $vtmId = $vtm.VTMID
        
        # Skip if already in database or already seen in this XML
        if ($existingVtmIds.ContainsKey($vtmId) -or $seenVtmIds.ContainsKey($vtmId)) {
            $duplicatesSkipped++
            continue
        }
        
        $seenVtmIds[$vtmId] = $true
        $invalid = Convert-BoolFlag $vtm.INVALID
        $values += "($(Escape-SqlValue $vtmId),$invalid,$(Escape-SqlValue $vtm.NM),$(Escape-SqlValue $vtm.ABBREVNM),$(Escape-SqlValue $vtm.VTMIDPREV),$(Escape-SqlValue $vtm.VTMIDDT -type date))"
    }
    
    if ($duplicatesSkipped -gt 0) {
        Write-Host "  Skipped $duplicatesSkipped duplicate VTM records"
    }
    
    if ($values.Count -gt 0) {
        Invoke-BatchedInsert -TableName "vtm" -Columns "(vtmid,invalid,nm,abbrevnm,vtmidprev,vtmiddt)" -Values $values -BatchSize $BatchSize
    } else {
        Write-Host "  No new VTM records to import"
    }
}

# Import VMPs
Write-Host "`nProcessing Virtual Medicinal Products (VMPs)..."
$vmpFile = Join-Path $XmlPath "f_vmp2_3091025.xml"
if (Test-Path $vmpFile) {
    [xml]$vmpXml = Get-Content $vmpFile
    
    # Get existing VMP IDs from database
    Write-Host "  Checking for existing VMP records..."
    $existingVmpIds = Get-ExistingKeys -TableName "vmp" -KeyColumn "vpid"
    $seenVmpIds = @{}
    
    $values = @()
    $duplicatesSkipped = 0
    
    foreach ($vmp in $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
        $vmpId = $vmp.VPID
        
        # Skip if already in database or already seen in this XML
        if ($existingVmpIds.ContainsKey($vmpId) -or $seenVmpIds.ContainsKey($vmpId)) {
            $duplicatesSkipped++
            continue
        }
        
        $seenVmpIds[$vmpId] = $true
        $invalid = Convert-BoolFlag $vmp.INVALID
        $sugF = Convert-BoolFlag $vmp.SUG_F
        $gluF = Convert-BoolFlag $vmp.GLU_F
        $presF = Convert-BoolFlag $vmp.PRES_F
        $cfcF = Convert-BoolFlag $vmp.CFC_F
        
        $values += "($(Escape-SqlValue $vmpId),$(Escape-SqlValue $vmp.VPIDDT -type date),$(Escape-SqlValue $vmp.VPIDPREV),$(Escape-SqlValue $vmp.VTMID),$invalid,$(Escape-SqlValue $vmp.NM),$(Escape-SqlValue $vmp.ABBREVNM),$(Escape-SqlValue $vmp.BASISCD),$(Escape-SqlValue $vmp.NMDT -type date),$(Escape-SqlValue $vmp.NMPREV),$(Escape-SqlValue $vmp.BASIS_PREVCD),$(Escape-SqlValue $vmp.NMCHANGECD),$(Escape-SqlValue $vmp.COMPRODCD),$(Escape-SqlValue $vmp.PRES_STATCD),$sugF,$gluF,$presF,$cfcF,$(Escape-SqlValue $vmp.NON_AVAILCD),$(Escape-SqlValue $vmp.NON_AVAILDT -type date),$(Escape-SqlValue $vmp.DF_INDCD),$(Escape-SqlValue $vmp.UDFS -type decimal),$(Escape-SqlValue $vmp.UDFS_UOMCD),$(Escape-SqlValue $vmp.UNIT_DOSE_UOMCD))"
    }
    
    if ($duplicatesSkipped -gt 0) {
        Write-Host "  Skipped $duplicatesSkipped duplicate VMP records"
    }
    
    if ($values.Count -gt 0) {
        Invoke-BatchedInsert -TableName "vmp" -Columns "(vpid,vpiddt,vpidprev,vtmid,invalid,nm,abbrevnm,basiscd,nmdt,nmprev,basis_prevcd,nmchangecd,comprodcd,pres_statcd,sug_f,glu_f,pres_f,cfc_f,non_availcd,non_availdt,df_indcd,udfs,udfs_uomcd,unit_dose_uomcd)" -Values $values -BatchSize $BatchSize
    } else {
        Write-Host "  No new VMP records to import"
    }
}

# Import AMPs
Write-Host "`nProcessing Actual Medicinal Products (AMPs)..."
$ampFile = Join-Path $XmlPath "f_amp2_3091025.xml"
if (Test-Path $ampFile) {
    [xml]$ampXml = Get-Content $ampFile
    
    # Get existing AMP IDs from database
    Write-Host "  Checking for existing AMP records..."
    $existingAmpIds = Get-ExistingKeys -TableName "amp" -KeyColumn "apid"
    $seenAmpIds = @{}
    
    $values = @()
    $duplicatesSkipped = 0
    
    foreach ($amp in $ampXml.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP) {
        $ampId = $amp.APID
        
        # Skip if already in database or already seen in this XML
        if ($existingAmpIds.ContainsKey($ampId) -or $seenAmpIds.ContainsKey($ampId)) {
            $duplicatesSkipped++
            continue
        }
        
        $seenAmpIds[$ampId] = $true
        $invalid = if ($amp.INVALID) { Convert-BoolFlag $amp.INVALID } else { '0' }
        $desc_f = if ($amp.DESC) { '1' } else { '0' }
        $ema_f = if ($amp.EMA) { '1' } else { '0' }
        $parallel_import_f = if ($amp.PARALLEL_IMPORT) { '1' } else { '0' }
        
        $values += "($(Escape-SqlValue $ampId),$invalid,$(Escape-SqlValue $amp.VPID),$(Escape-SqlValue $amp.NM),$(Escape-SqlValue $amp.ABBREVNM),$desc_f,$(Escape-SqlValue $amp.NMDT -type date),$(Escape-SqlValue $amp.NM_PREV),$(Escape-SqlValue $amp.SUPPCD),$(Escape-SqlValue $amp.LIC_AUTHCD),$(Escape-SqlValue $amp.LIC_AUTH_PREVCD),$(Escape-SqlValue $amp.LIC_AUTHCHANGECD),$(Escape-SqlValue $amp.LIC_AUTHCHANGEDT -type date),$(Escape-SqlValue $amp.COMBPRODCD),$(Escape-SqlValue $amp.FLAVOURCD),$ema_f,$parallel_import_f,$(Escape-SqlValue $amp.AVAIL_RESTRICTCD))"
    }
    
    if ($duplicatesSkipped -gt 0) {
        Write-Host "  Skipped $duplicatesSkipped duplicate AMP records"
    }
    
    if ($values.Count -gt 0) {
        Invoke-BatchedInsert -TableName "amp" -Columns "(apid,invalid,vpid,nm,abbrevnm,desc_f,nmdt,nm_prev,suppcd,lic_authcd,lic_auth_prevcd,lic_authchangecd,lic_authchangedt,combprodcd,flavourcd,ema_f,parallel_import_f,avail_restrictcd)" -Values $values -BatchSize $BatchSize
    } else {
        Write-Host "  No new AMP records to import"
    }
}

# Import VMPPs
Write-Host "`nProcessing Virtual Medicinal Product Packs (VMPPs)..."
$vmppFile = Join-Path $XmlPath "f_vmpp2_3091025.xml"
if (Test-Path $vmppFile) {
    [xml]$vmppXml = Get-Content $vmppFile
    
    # Get existing VMPP IDs from database
    Write-Host "  Checking for existing VMPP records..."
    $existingVmppIds = Get-ExistingKeys -TableName "vmpp" -KeyColumn "vppid"
    $seenVmppIds = @{}
    
    $values = @()
    $duplicatesSkipped = 0
    
    foreach ($vmpp in $vmppXml.VIRTUAL_MED_PRODUCT_PACK.VMPPS.VMPP) {
        $vmppId = $vmpp.VPPID
        
        # Skip if already in database or already seen in this XML
        if ($existingVmppIds.ContainsKey($vmppId) -or $seenVmppIds.ContainsKey($vmppId)) {
            $duplicatesSkipped++
            continue
        }
        
        $seenVmppIds[$vmppId] = $true
        $invalid = if ($vmpp.INVALID) { Convert-BoolFlag $vmpp.INVALID } else { '0' }
        $qtyval = if ($vmpp.QTYVAL) { Escape-SqlValue $vmpp.QTYVAL -type decimal } else { 'NULL' }
        $qty_uomcd = if ($vmpp.QTY_UOMCD) { Escape-SqlValue $vmpp.QTY_UOMCD } else { 'NULL' }
        $combpackcd = if ($vmpp.COMBPACKCD) { Escape-SqlValue $vmpp.COMBPACKCD } else { 'NULL' }
        
        $values += "($(Escape-SqlValue $vmppId),$invalid,$(Escape-SqlValue $vmpp.NM),$(Escape-SqlValue $vmpp.VPID),$qtyval,$qty_uomcd,$combpackcd)"
    }
    
    if ($duplicatesSkipped -gt 0) {
        Write-Host "  Skipped $duplicatesSkipped duplicate VMPP records"
    }
    
    if ($values.Count -gt 0) {
        Invoke-BatchedInsert -TableName "vmpp" -Columns "(vppid,invalid,nm,vpid,qtyval,qty_uomcd,combpackcd)" -Values $values -BatchSize $BatchSize
    } else {
        Write-Host "  No new VMPP records to import"
    }
}

# Import AMPPs
Write-Host "`nProcessing Actual Medicinal Product Packs (AMPPs)..."
$amppFile = Join-Path $XmlPath "f_ampp2_3091025.xml"
if (Test-Path $amppFile) {
    [xml]$amppXml = Get-Content $amppFile
    
    # Get existing AMPP IDs from database
    Write-Host "  Checking for existing AMPP records..."
    $existingAmppIds = Get-ExistingKeys -TableName "ampp" -KeyColumn "appid"
    $seenAmppIds = @{}
    
    $values = @()
    $duplicatesSkipped = 0
    
    foreach ($ampp in $amppXml.ACTUAL_MEDICINAL_PROD_PACKS.AMPPS.AMPP) {
        $amppId = $ampp.APPID
        
        # Skip if already in database or already seen in this XML
        if ($existingAmppIds.ContainsKey($amppId) -or $seenAmppIds.ContainsKey($amppId)) {
            $duplicatesSkipped++
            continue
        }
        
        $seenAmppIds[$amppId] = $true
        $invalid = if ($ampp.INVALID) { Convert-BoolFlag $ampp.INVALID } else { '0' }
        $legal_catcd = if ($ampp.LEGAL_CATCD) { Escape-SqlValue $ampp.LEGAL_CATCD } else { 'NULL' }
        $subp = if ($ampp.SUBP) { Escape-SqlValue $ampp.SUBP } else { 'NULL' }
        $disccd = if ($ampp.DISCCD) { Escape-SqlValue $ampp.DISCCD } else { 'NULL' }
        $hosp_f = if ($ampp.HOSP_F) { Convert-BoolFlag $ampp.HOSP_F } else { '0' }
        $broken_bulk_f = if ($ampp.BROKEN_BULK_F) { Convert-BoolFlag $ampp.BROKEN_BULK_F } else { '0' }
        $nurse_f = if ($ampp.NURSE_F) { Convert-BoolFlag $ampp.NURSE_F } else { '0' }
        $enurse_f = if ($ampp.ENURSE_F) { Convert-BoolFlag $ampp.ENURSE_F } else { '0' }
        $dent_f = if ($ampp.DENT_F) { Convert-BoolFlag $ampp.DENT_F } else { '0' }
        
        $values += "($(Escape-SqlValue $amppId),$invalid,$(Escape-SqlValue $ampp.VPPID),$(Escape-SqlValue $ampp.APID),$(Escape-SqlValue $ampp.NM),$legal_catcd,$subp,$disccd,$hosp_f,$broken_bulk_f,$nurse_f,$enurse_f,$dent_f)"
    }
    
    if ($duplicatesSkipped -gt 0) {
        Write-Host "  Skipped $duplicatesSkipped duplicate AMPP records"
    }
    
    if ($values.Count -gt 0) {
        Invoke-BatchedInsert -TableName "ampp" -Columns "(appid,invalid,vppid,apid,nm,legal_catcd,subp,disccd,hosp_f,broken_bulk_f,nurse_f,enurse_f,dent_f)" -Values $values -BatchSize $BatchSize
    } else {
        Write-Host "  No new AMPP records to import"
    }
}

# Import Lookups (grouped sections under <LOOKUP>)
Write-Host "`nProcessing Lookup tables..."
$lookupFile = Join-Path $XmlPath "f_lookup2_3091025.xml"
if (Test-Path $lookupFile) {
    [xml]$lookupXml = Get-Content $lookupFile
    
    # Get existing lookup keys (type + cd combination)
    Write-Host "  Checking for existing Lookup records..."
    $existingLookups = @{}
    $lookupQuery = "SELECT type, cd FROM lookup"
    $existingLookupResults = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $lookupQuery -TrustServerCertificate -ErrorAction SilentlyContinue
    if ($existingLookupResults) {
        foreach ($row in $existingLookupResults) {
            $key = "$($row.type)|$($row.cd)"
            $existingLookups[$key] = $true
        }
    }
    
    $seenLookups = @{}
    $values = @()
    $duplicatesSkipped = 0

    # Iterate over each child section of LOOKUP (e.g., FORM, ROUTE, SUPPLIER, etc.)
    $sections = @()
    foreach ($node in $lookupXml.LOOKUP.ChildNodes) {
        if ($null -ne $node -and $node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            $sections += $node
        }
    }

    foreach ($section in $sections) {
        $typeName = $section.Name
        # Some sections may not have INFO children; guard accordingly
        $infos = @()
        if ($section.INFO) { $infos = $section.INFO }
        foreach ($info in $infos) {
            $cd = [string]$info.CD
            $desc = [string]$info.DESC
            # Only insert if we have a code and description
            if (-not [string]::IsNullOrWhiteSpace($cd) -and -not [string]::IsNullOrWhiteSpace($desc)) {
                $key = "$typeName|$cd"
                
                # Skip if already in database or already seen
                if ($existingLookups.ContainsKey($key) -or $seenLookups.ContainsKey($key)) {
                    $duplicatesSkipped++
                    continue
                }
                
                $seenLookups[$key] = $true
                $values += "($(Escape-SqlValue $typeName),$(Escape-SqlValue $cd),$(Escape-SqlValue $desc))"
            }
        }
    }

    if ($duplicatesSkipped -gt 0) {
        Write-Host "  Skipped $duplicatesSkipped duplicate Lookup records"
    }

    if ($values.Count -gt 0) {
        Invoke-BatchedInsert -TableName "lookup" -Columns "(type,cd,descr)" -Values $values -BatchSize $BatchSize
    } else {
        if ($duplicatesSkipped -eq 0) {
            Write-Warning "No lookup records found to import."
        } else {
            Write-Host "  No new Lookup records to import"
        }
    }
}

# ============================================================================
# Import Ingredient Substances (reference table)
# ============================================================================
Write-Host "`n=== Importing Ingredient Substances ===" -ForegroundColor Cyan
$ingredientFile = "$XmlPath\f_ingredient2_3091025.xml"
if (Test-Path $ingredientFile) {
    $ingXml = [xml](Get-Content $ingredientFile)
    $ingValues = @()
    
    foreach ($ing in $ingXml.INGREDIENT_SUBSTANCES.ING) {
        $isid = [string]$ing.ISID
        $isiddt = [string]$ing.ISIDDT
        $isidprev = [string]$ing.ISIDPREV
        $nm = [string]$ing.NM
        $invalid = [string]$ing.INVALID
        
        if (-not [string]::IsNullOrWhiteSpace($isid)) {
            $ingValues += "($(Escape-SqlValue $isid),$(Escape-SqlValue $isiddt),$(Escape-SqlValue $isidprev),$(Escape-SqlValue $nm),$(Convert-BoolFlag $invalid))"
        }
    }
    
    if ($ingValues.Count -gt 0) {
        Invoke-BatchedInsert -TableName "ingredient" -Columns "(isid,isiddt,isidprev,nm,invalid)" -Values $ingValues -BatchSize $BatchSize
    } else {
        Write-Warning "No ingredient substance records found."
    }
} else {
    Write-Warning "Ingredient file not found: $ingredientFile"
}

# ============================================================================
# Import VMP child tables (ingredients, routes, forms)
# ============================================================================
Write-Host "`n=== Importing VMP Child Tables ===" -ForegroundColor Cyan

# VMP Ingredients
Write-Host "`nImporting VMP ingredients..." -ForegroundColor Green
$vmpXml = [xml](Get-Content "$XmlPath\f_vmp2_3091025.xml")
$ingredientValues = @()

foreach ($vmp in $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
    $vpid = [string]$vmp.VPID
    if ([string]::IsNullOrWhiteSpace($vpid)) { continue }
    
    if ($vmp.VIRTUAL_PRODUCT_INGREDIENT) {
        foreach ($vpi in $vmp.VIRTUAL_PRODUCT_INGREDIENT.VPI) {
            $isid = [string]$vpi.ISID
            $basis_strntcd = [string]$vpi.BASIS_STRNTCD
            $bs_subid = [string]$vpi.BS_SUBID
            $strnt_nmrtr_val = [string]$vpi.STRNT_NMRTR_VAL
            $strnt_nmrtr_uomcd = [string]$vpi.STRNT_NMRTR_UOMCD
            $strnt_dnmtr_val = [string]$vpi.STRNT_DNMTR_VAL
            $strnt_dnmtr_uomcd = [string]$vpi.STRNT_DNMTR_UOMCD
            
            if (-not [string]::IsNullOrWhiteSpace($isid)) {
                $ingredientValues += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $isid),$(Escape-SqlValue $basis_strntcd),$(Escape-SqlValue $bs_subid),$(Escape-SqlValue $strnt_nmrtr_val),$(Escape-SqlValue $strnt_nmrtr_uomcd),$(Escape-SqlValue $strnt_dnmtr_val),$(Escape-SqlValue $strnt_dnmtr_uomcd))"
            }
        }
    }
}

if ($ingredientValues.Count -gt 0) {
    Invoke-BatchedInsert -TableName "vmp_ingredient" -Columns "(vpid,isid,basis_strntcd,bs_subid,strnt_nmrtr_val,strnt_nmrtr_uomcd,strnt_dnmtr_val,strnt_dnmtr_uomcd)" -Values $ingredientValues -BatchSize $BatchSize
} else {
    Write-Warning "No VMP ingredient records found."
}

# VMP Drug Routes
Write-Host "`nImporting VMP drug routes..." -ForegroundColor Green
$routeValues = @()

foreach ($vmp in $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
    $vpid = [string]$vmp.VPID
    if ([string]::IsNullOrWhiteSpace($vpid)) { continue }
    
    if ($vmp.DRUG_ROUTE) {
        foreach ($route in $vmp.DRUG_ROUTE.ROUTECD) {
            $routecd = [string]$route
            if (-not [string]::IsNullOrWhiteSpace($routecd)) {
                $routeValues += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $routecd))"
            }
        }
    }
}

if ($routeValues.Count -gt 0) {
    Invoke-BatchedInsert -TableName "vmp_drugroute" -Columns "(vpid,routecd)" -Values $routeValues -BatchSize $BatchSize
} else {
    Write-Warning "No VMP drug route records found."
}

# VMP Drug Forms
Write-Host "`nImporting VMP drug forms..." -ForegroundColor Green
$formValues = @()

foreach ($vmp in $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
    $vpid = [string]$vmp.VPID
    if ([string]::IsNullOrWhiteSpace($vpid)) { continue }
    
    if ($vmp.DRUG_FORM) {
        foreach ($form in $vmp.DRUG_FORM.FORMCD) {
            $formcd = [string]$form
            if (-not [string]::IsNullOrWhiteSpace($formcd)) {
                $formValues += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $formcd))"
            }
        }
    }
}

if ($formValues.Count -gt 0) {
    Invoke-BatchedInsert -TableName "vmp_drugform" -Columns "(vpid,formcd)" -Values $formValues -BatchSize $BatchSize
} else {
    Write-Warning "No VMP drug form records found."
}

# ============================================================================
# Import BNF and ATC codes from supplementary data
# ============================================================================
Write-Host "`n=== Importing BNF and ATC Codes ===" -ForegroundColor Cyan

$bnfPath = "$XmlPath\..\nhsbsa_dmdbonus_10.1.0_20251013000001\BNF\f_bnf1_0091025.xml"
if (Test-Path $bnfPath) {
    $bnfXml = [xml](Get-Content $bnfPath)
    
    # Import BNF codes
    Write-Host "`nImporting BNF codes..." -ForegroundColor Green
    $bnfValues = @()
    
    foreach ($vmp in $bnfXml.BNF_DETAILS.VMPS.VMP) {
        $vpid = [string]$vmp.VPID
        $bnf = [string]$vmp.BNF
        
        if (-not [string]::IsNullOrWhiteSpace($vpid) -and -not [string]::IsNullOrWhiteSpace($bnf)) {
            $bnfValues += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $bnf))"
        }
    }
    
    if ($bnfValues.Count -gt 0) {
        Invoke-BatchedInsert -TableName "dmd_bnf" -Columns "(vpid,bnf_code)" -Values $bnfValues -BatchSize $BatchSize
    } else {
        Write-Warning "No BNF records found."
    }
    
    # Import ATC codes
    Write-Host "`nImporting ATC codes..." -ForegroundColor Green
    $atcValues = @()
    
    foreach ($vmp in $bnfXml.BNF_DETAILS.VMPS.VMP) {
        $vpid = [string]$vmp.VPID
        $atc = [string]$vmp.ATC
        
        if (-not [string]::IsNullOrWhiteSpace($vpid) -and -not [string]::IsNullOrWhiteSpace($atc)) {
            $atcValues += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $atc))"
        }
    }
    
    if ($atcValues.Count -gt 0) {
        Invoke-BatchedInsert -TableName "dmd_atc" -Columns "(vpid,atc_code)" -Values $atcValues -BatchSize $BatchSize
    } else {
        Write-Warning "No ATC records found."
    }
} else {
    Write-Warning "BNF file not found at: $bnfPath"
}

Write-Host "`nImport complete!"
Write-Host "Run Validate-DMDImport.ps1 to verify the import."
