# Comprehensive DM+D Database Validation Against NHS England CSV Files
# Compares database contents with NHS England's extracted CSV files

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [string]$CsvPath = "C:\dmdDataLoader\csv",
    [string]$OutputReport = "C:\DMD\csv-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
)

$ErrorActionPreference = "Continue"
$script:TotalIssues = 0
$script:TotalChecks = 0

# Output both to console and file
function Write-Report {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $OutputReport -Value $Message
}

# Parse CSV with proper null handling (|| is delimiter)
function Import-CsvWithPipe {
    param(
        [string]$Path,
        [string[]]$Headers
    )
    
    if (-not (Test-Path $Path)) {
        return @()
    }
    
    $lines = Get-Content $Path
    $objects = @()
    
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        $fields = $line -split '\|'
        $obj = [PSCustomObject]@{}
        
        for ($i = 0; $i -lt $Headers.Count; $i++) {
            $value = if ($i -lt $fields.Count -and $fields[$i] -ne '') { $fields[$i] } else { $null }
            $obj | Add-Member -NotePropertyName $Headers[$i] -NotePropertyValue $value
        }
        
        $objects += $obj
    }
    
    return $objects
}

# Compare counts
function Compare-Counts {
    param(
        [string]$EntityName,
        [string]$TableName,
        [string]$CsvFile,
        [string[]]$CsvHeaders
    )
    
    $script:TotalChecks++
    Write-Report "`n=== $EntityName Validation ===" -Color Cyan
    
    # Get database count
    $dbQuery = "SELECT COUNT(*) as cnt FROM $TableName"
    $dbCount = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $dbQuery -TrustServerCertificate).cnt
    
    # Get CSV count
    $csvPath = Join-Path $CsvPath $CsvFile
    if (-not (Test-Path $csvPath)) {
        Write-Report "⚠️ WARNING: CSV file not found: $CsvFile" -Color Yellow
        return
    }
    
    $csvData = Import-CsvWithPipe -Path $csvPath -Headers $CsvHeaders
    $csvCount = $csvData.Count
    
    Write-Report "Database count: $dbCount"
    Write-Report "CSV count:      $csvCount"
    
    if ($dbCount -eq $csvCount) {
        Write-Report "✅ Count match!" -Color Green
    } else {
        Write-Report "❌ Count mismatch! Difference: $($csvCount - $dbCount)" -Color Red
        $script:TotalIssues++
    }
    
    return @{
        DbCount = $dbCount
        CsvCount = $csvCount
        CsvData = $csvData
    }
}

# Validate specific records
function Validate-Records {
    param(
        [string]$EntityName,
        [string]$TableName,
        [string]$KeyColumn,
        [array]$CsvData,
        [hashtable]$FieldMapping,
        [int]$SampleSize = 100
    )
    
    $script:TotalChecks++
    Write-Report "`n--- Record-Level Validation ---" -Color Yellow
    
    # Sample random records
    $sample = $CsvData | Get-Random -Count ([Math]::Min($SampleSize, $CsvData.Count))
    
    $mismatches = 0
    $matches = 0
    $notFound = 0
    
    foreach ($csvRecord in $sample) {
        $keyValue = $csvRecord.$KeyColumn
        if ($null -eq $keyValue) { continue }
        
        # Build WHERE clause
        $whereClause = "$KeyColumn = $keyValue"
        
        # Query database
        $dbQuery = "SELECT * FROM $TableName WHERE $whereClause"
        $dbRecord = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $dbQuery -TrustServerCertificate
        
        if (-not $dbRecord) {
            $notFound++
            Write-Report "  ❌ Record not found in database: $KeyColumn = $keyValue" -Color Red
            continue
        }
        
        # Compare fields
        $fieldMismatch = $false
        foreach ($csvField in $FieldMapping.Keys) {
            $dbField = $FieldMapping[$csvField]
            $csvValue = $csvRecord.$csvField
            $dbValue = $dbRecord.$dbField
            
            # Normalize null/empty
            if ([string]::IsNullOrWhiteSpace($csvValue)) { $csvValue = $null }
            if ([string]::IsNullOrWhiteSpace($dbValue)) { $dbValue = $null }
            
            # Compare (handle type conversions)
            if ($csvValue -ne $dbValue) {
                # Try numeric comparison
                if ($null -ne $csvValue -and $null -ne $dbValue) {
                    try {
                        $csvNum = [decimal]$csvValue
                        $dbNum = [decimal]$dbValue
                        if ($csvNum -eq $dbNum) { continue }
                    } catch {}
                }
                
                if (-not $fieldMismatch) {
                    Write-Report "  ⚠️ Field mismatch for $KeyColumn = $keyValue" -Color Yellow
                    $fieldMismatch = $true
                }
                Write-Report "    Field: $dbField | CSV: '$csvValue' | DB: '$dbValue'" -Color Gray
            }
        }
        
        if ($fieldMismatch) {
            $mismatches++
        } else {
            $matches++
        }
    }
    
    Write-Report "`nSample validation results ($($sample.Count) records checked):"
    Write-Report "  ✅ Matches:       $matches" -Color Green
    Write-Report "  ⚠️ Mismatches:    $mismatches" -Color $(if ($mismatches -gt 0) { "Yellow" } else { "Green" })
    Write-Report "  ❌ Not found:     $notFound" -Color $(if ($notFound -gt 0) { "Red" } else { "Green" })
    
    if ($mismatches -gt 0 -or $notFound -gt 0) {
        $script:TotalIssues++
    }
}

# Check for duplicates in database
function Check-Duplicates {
    param(
        [string]$TableName,
        [string]$KeyColumn
    )
    
    $script:TotalChecks++
    Write-Report "`n--- Duplicate Check ---" -Color Yellow
    
    $dupQuery = @"
SELECT $KeyColumn, COUNT(*) as cnt 
FROM $TableName 
GROUP BY $KeyColumn 
HAVING COUNT(*) > 1
"@
    
    $duplicates = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $dupQuery -TrustServerCertificate
    
    if ($duplicates.Count -gt 0) {
        Write-Report "  ❌ Found $($duplicates.Count) duplicate keys in $TableName" -Color Red
        foreach ($dup in ($duplicates | Select-Object -First 5)) {
            Write-Report "    $KeyColumn = $($dup.$KeyColumn) (count: $($dup.cnt))" -Color Gray
        }
        $script:TotalIssues++
    } else {
        Write-Report "  ✅ No duplicates found" -Color Green
    }
}

# Check referential integrity
function Check-ReferentialIntegrity {
    param(
        [string]$ChildTable,
        [string]$ChildColumn,
        [string]$ParentTable,
        [string]$ParentColumn
    )
    
    $script:TotalChecks++
    Write-Report "`n--- Referential Integrity: $ChildTable.$ChildColumn -> $ParentTable.$ParentColumn ---" -Color Yellow
    
    $riQuery = @"
SELECT COUNT(*) as cnt
FROM $ChildTable c
WHERE c.$ChildColumn IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM $ParentTable p WHERE p.$ParentColumn = c.$ChildColumn
)
"@
    
    $orphans = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $riQuery -TrustServerCertificate).cnt
    
    if ($orphans -gt 0) {
        Write-Report "  ❌ Found $orphans orphaned records" -Color Red
        $script:TotalIssues++
    } else {
        Write-Report "  ✅ All references valid" -Color Green
    }
}

# Main validation script
Write-Report "=============================================" -Color Cyan
Write-Report "DM+D CSV Validation Report" -Color Cyan
Write-Report "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Cyan
Write-Report "Server: $ServerInstance" -Color Cyan
Write-Report "Database: $Database" -Color Cyan
Write-Report "CSV Path: $CsvPath" -Color Cyan
Write-Report "=============================================" -Color Cyan

# 1. Validate VTMs
$vtmResult = Compare-Counts -EntityName "Virtual Therapeutic Moieties (VTM)" `
    -TableName "vtm" `
    -CsvFile "f_vtm.csv" `
    -CsvHeaders @("vtmid", "vtmidprev", "vtmiddt", "nm", "abbrevnm", "vtmidold", "invalid")

if ($vtmResult.CsvData.Count -gt 0) {
    Validate-Records -EntityName "VTM" -TableName "vtm" -KeyColumn "vtmid" `
        -CsvData $vtmResult.CsvData `
        -FieldMapping @{
            "vtmid" = "vtmid"
            "nm" = "nm"
            "invalid" = "invalid"
        }
    
    Check-Duplicates -TableName "vtm" -KeyColumn "vtmid"
}

# 2. Validate VMPs
$vmpResult = Compare-Counts -EntityName "Virtual Medicinal Products (VMP)" `
    -TableName "vmp" `
    -CsvFile "f_vmp_VmpType.csv" `
    -CsvHeaders @("vpid", "vpiddt", "vpidprev", "vtmid", "invalid", "nm", "abbrevnm", "basiscd", 
                  "nmdt", "nmprev", "basis_prevcd", "nmchangecd", "comprodcd", "pres_statcd", 
                  "sug_f", "glu_f", "pres_f", "cfc_f", "non_availcd", "non_availdt", "df_indcd", 
                  "udfs", "udfs_uomcd", "unit_dose_uomcd")

if ($vmpResult.CsvData.Count -gt 0) {
    Validate-Records -EntityName "VMP" -TableName "vmp" -KeyColumn "vpid" `
        -CsvData $vmpResult.CsvData `
        -FieldMapping @{
            "vpid" = "vpid"
            "vtmid" = "vtmid"
            "nm" = "nm"
            "invalid" = "invalid"
        } `
        -SampleSize 200
    
    Check-Duplicates -TableName "vmp" -KeyColumn "vpid"
    Check-ReferentialIntegrity -ChildTable "vmp" -ChildColumn "vtmid" -ParentTable "vtm" -ParentColumn "vtmid"
}

# 3. Validate AMPs
$ampResult = Compare-Counts -EntityName "Actual Medicinal Products (AMP)" `
    -TableName "amp" `
    -CsvFile "f_amp_AmpType.csv" `
    -CsvHeaders @("apid", "apidprev", "vpid", "invalid", "nm", "abbrevnm", "desc_f", "nmdt", 
                  "nm_prev", "suppcd", "lic_authcd", "lic_auth_prevcd", "lic_authchangecd", 
                  "lic_authchangedt", "combprodcd", "flavourcd", "ema_f", "parallel_import_f", "avail_restrictcd")

if ($ampResult.CsvData.Count -gt 0) {
    Validate-Records -EntityName "AMP" -TableName "amp" -KeyColumn "apid" `
        -CsvData $ampResult.CsvData `
        -FieldMapping @{
            "apid" = "apid"
            "vpid" = "vpid"
            "nm" = "nm"
            "invalid" = "invalid"
            "suppcd" = "suppcd"
        } `
        -SampleSize 500
    
    Check-Duplicates -TableName "amp" -KeyColumn "apid"
    Check-ReferentialIntegrity -ChildTable "amp" -ChildColumn "vpid" -ParentTable "vmp" -ParentColumn "vpid"
}

# 4. Validate VMPPs
$vmppResult = Compare-Counts -EntityName "Virtual Medicinal Product Packs (VMPP)" `
    -TableName "vmpp" `
    -CsvFile "f_vmpp_VmppType.csv" `
    -CsvHeaders @("vppid", "vppidprev", "vppiddt", "vpid", "invalid", "nm", "abbrevnm", 
                  "qtyval", "qty_uomcd", "combpackcd")

if ($vmppResult.CsvData.Count -gt 0) {
    Validate-Records -EntityName "VMPP" -TableName "vmpp" -KeyColumn "vppid" `
        -CsvData $vmppResult.CsvData `
        -FieldMapping @{
            "vppid" = "vppid"
            "vpid" = "vpid"
            "nm" = "nm"
            "invalid" = "invalid"
        } `
        -SampleSize 200
    
    Check-Duplicates -TableName "vmpp" -KeyColumn "vppid"
    Check-ReferentialIntegrity -ChildTable "vmpp" -ChildColumn "vpid" -ParentTable "vmp" -ParentColumn "vpid"
}

# 5. Validate AMPPs
$amppResult = Compare-Counts -EntityName "Actual Medicinal Product Packs (AMPP)" `
    -TableName "ampp" `
    -CsvFile "f_ampp_AmppType.csv" `
    -CsvHeaders @("appid", "appidprev", "appiddt", "vppid", "apid", "invalid", "nm", "abbrevnm", 
                  "legal_catcd", "subp", "disccd", "hosp_f", "broken_bulk_f", "nurse_f", 
                  "enurse_f", "dent_f", "prod_order_no")

if ($amppResult.CsvData.Count -gt 0) {
    Validate-Records -EntityName "AMPP" -TableName "ampp" -KeyColumn "appid" `
        -CsvData $amppResult.CsvData `
        -FieldMapping @{
            "appid" = "appid"
            "vppid" = "vppid"
            "apid" = "apid"
            "nm" = "nm"
            "invalid" = "invalid"
        } `
        -SampleSize 500
    
    Check-Duplicates -TableName "ampp" -KeyColumn "appid"
    Check-ReferentialIntegrity -ChildTable "ampp" -ChildColumn "vppid" -ParentTable "vmpp" -ParentColumn "vppid"
    Check-ReferentialIntegrity -ChildTable "ampp" -ChildColumn "apid" -ParentTable "amp" -ParentColumn "apid"
}

# 6. Validate Ingredients
$ingResult = Compare-Counts -EntityName "Ingredient Substances" `
    -TableName "ingredient" `
    -CsvFile "f_ingredient.csv" `
    -CsvHeaders @("isid", "isiddt", "isidprev", "invalid", "nm")

if ($ingResult.CsvData.Count -gt 0) {
    Validate-Records -EntityName "Ingredient" -TableName "ingredient" -KeyColumn "isid" `
        -CsvData $ingResult.CsvData `
        -FieldMapping @{
            "isid" = "isid"
            "nm" = "nm"
            "invalid" = "invalid"
        }
    
    Check-Duplicates -TableName "ingredient" -KeyColumn "isid"
}

# 7. Validate VMP Ingredients
$vpiResult = Compare-Counts -EntityName "VMP Ingredients (VPI)" `
    -TableName "vmp_ingredient" `
    -CsvFile "f_vmp_VpiType.csv" `
    -CsvHeaders @("vpid", "isid", "basis_strntcd", "bs_subid", "strnt_nmrtr_val", 
                  "strnt_nmrtr_uomcd", "strnt_dnmtr_val", "strnt_dnmtr_uomcd")

if ($vpiResult.DbCount -gt 0 -or $vpiResult.CsvCount -gt 0) {
    if ($vpiResult.CsvData.Count -gt 0) {
        Validate-Records -EntityName "VMP Ingredient" -TableName "vmp_ingredient" -KeyColumn "vpid" `
            -CsvData $vpiResult.CsvData `
            -FieldMapping @{
                "vpid" = "vpid"
                "isid" = "isid"
            } `
            -SampleSize 200
        
        Check-ReferentialIntegrity -ChildTable "vmp_ingredient" -ChildColumn "vpid" -ParentTable "vmp" -ParentColumn "vpid"
        Check-ReferentialIntegrity -ChildTable "vmp_ingredient" -ChildColumn "isid" -ParentTable "ingredient" -ParentColumn "isid"
    }
}

# 8. Validate VMP Drug Routes
$routeResult = Compare-Counts -EntityName "VMP Drug Routes" `
    -TableName "vmp_drugroute" `
    -CsvFile "f_vmp_DrugRouteType.csv" `
    -CsvHeaders @("vpid", "routecd")

if ($routeResult.DbCount -gt 0 -or $routeResult.CsvCount -gt 0) {
    Check-ReferentialIntegrity -ChildTable "vmp_drugroute" -ChildColumn "vpid" -ParentTable "vmp" -ParentColumn "vpid"
}

# 9. Validate VMP Drug Forms
$formResult = Compare-Counts -EntityName "VMP Drug Forms" `
    -TableName "vmp_drugform" `
    -CsvFile "f_vmp_DrugFormType.csv" `
    -CsvHeaders @("vpid", "formcd")

if ($formResult.DbCount -gt 0 -or $formResult.CsvCount -gt 0) {
    Check-ReferentialIntegrity -ChildTable "vmp_drugform" -ChildColumn "vpid" -ParentTable "vmp" -ParentColumn "vpid"
}

# 10. Validate BNF Codes
$bnfResult = Compare-Counts -EntityName "BNF Codes" `
    -TableName "dmd_bnf" `
    -CsvFile "f_bnf_Vmp.csv" `
    -CsvHeaders @("vpid", "bnf_code")

if ($bnfResult.DbCount -gt 0 -or $bnfResult.CsvCount -gt 0) {
    Check-ReferentialIntegrity -ChildTable "dmd_bnf" -ChildColumn "vpid" -ParentTable "vmp" -ParentColumn "vpid"
}

# 11. Validate GTIN
$gtinResult = Compare-Counts -EntityName "GTIN Codes" `
    -TableName "gtin" `
    -CsvFile "f_gtin.csv" `
    -CsvHeaders @("appid", "gtin", "startdt", "enddt")

if ($gtinResult.DbCount -gt 0 -or $gtinResult.CsvCount -gt 0) {
    Check-ReferentialIntegrity -ChildTable "gtin" -ChildColumn "appid" -ParentTable "ampp" -ParentColumn "appid"
}

# Summary
Write-Report "`n=============================================" -Color Cyan
Write-Report "VALIDATION SUMMARY" -Color Cyan
Write-Report "=============================================" -Color Cyan
Write-Report "Total checks performed: $script:TotalChecks"
Write-Report "Total issues found:     $script:TotalIssues"

if ($script:TotalIssues -eq 0) {
    Write-Report "`n✅ ALL VALIDATIONS PASSED!" -Color Green
    Write-Report "Database contents match CSV files." -Color Green
} else {
    Write-Report "`n⚠️ VALIDATION ISSUES DETECTED" -Color Yellow
    Write-Report "Please review the issues above." -Color Yellow
}

Write-Report "`nReport saved to: $OutputReport" -Color Cyan
Write-Report "=============================================" -Color Cyan

# Return summary object
return [PSCustomObject]@{
    TotalChecks = $script:TotalChecks
    TotalIssues = $script:TotalIssues
    Status = if ($script:TotalIssues -eq 0) { "PASS" } else { "FAIL" }
    ReportPath = $OutputReport
}
