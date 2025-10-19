# DM+D Bulk Import using BCP (Bulk Copy Program)
# This script imports DM+D data using BCP which is much more efficient for large datasets

param(
    [string]$BaseDir = "C:\DMD",
    [string]$Server = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd"
)

$currentReleasesDir = Join-Path $BaseDir "CurrentReleases"
$bcpDir = Join-Path $BaseDir "bcp_data"

Write-Host "=== DM+D Bulk Import using BCP ===" -ForegroundColor Cyan
Write-Host "Base Directory: $BaseDir"
Write-Host "BCP Data Directory: $bcpDir"

# Create BCP directory if it doesn't exist
if (-not (Test-Path $bcpDir)) {
    New-Item -ItemType Directory -Path $bcpDir | Out-Null
}

# Helper functions
function Export-ToBcpFile {
    param(
        [string]$XmlFile,
        [string]$OutputFile,
        [scriptblock]$ProcessNode
    )
    
    Write-Host "Processing $([System.IO.Path]::GetFileName($XmlFile))..."
    [xml]$xml = Get-Content -Path $XmlFile -Encoding UTF8
    
    $output = New-Object System.Text.StringBuilder
    $count = 0
    
    & $ProcessNode $xml
    
    [System.IO.File]::WriteAllText($OutputFile, $output.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "  Exported $count records to $([System.IO.Path]::GetFileName($OutputFile))"
    
    return $count
}

function Escape-BcpValue {
    param([string]$value)
    if ($null -eq $value -or $value -eq '') {
        return ''
    }
    # Escape special characters for tab-delimited format
    return $value.Replace("`t", " ").Replace("`n", " ").Replace("`r", "")
}

# Clear existing data
Write-Host "`nClearing existing data..." -ForegroundColor Yellow
$clearSql = @"
DELETE FROM ampp;
DELETE FROM amp;
DELETE FROM vmpp;
DELETE FROM vmp;
DELETE FROM vtm;
DELETE FROM lookup;
"@

sqlcmd -S $Server -d $Database -E -C -Q $clearSql

Write-Host "`nExporting XML data to BCP format..." -ForegroundColor Yellow

# Process VTMs
$vtmFile = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "f_vtm2_*.xml" | Select-Object -First 1
if ($vtmFile) {
    $vtmBcp = Join-Path $bcpDir "vtm.txt"
    $vtmCount = Export-ToBcpFile -XmlFile $vtmFile.FullName -OutputFile $vtmBcp -ProcessNode {
        param($xml)
        foreach ($vtm in $xml.VIRTUAL_THERAPEUTIC_MOIETIES.VTM) {
            $script:count++
            $invalid = if ($vtm.INVALID -eq '1') { '1' } else { '0' }
            $abbrevnm = Escape-BcpValue $vtm.ABBREVNM
            $vtmidprev = if ($vtm.VTMIDPREV) { $vtm.VTMIDPREV } else { '' }
            $vtmiddt = if ($vtm.VTMIDDT) { $vtm.VTMIDDT } else { '' }
            
            [void]$script:output.AppendLine("$($vtm.VTMID)`t$invalid`t$(Escape-BcpValue $vtm.NM)`t$abbrevnm`t$vtmidprev`t$vtmiddt")
        }
    }
}

# Process VMPs
$vmpFile = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "f_vmp2_*.xml" | Select-Object -First 1
if ($vmpFile) {
    $vmpBcp = Join-Path $bcpDir "vmp.txt"
    Write-Host "Processing VMPs (this may take a few minutes)..." -ForegroundColor Yellow
    
    $vmpCount = Export-ToBcpFile -XmlFile $vmpFile.FullName -OutputFile $vmpBcp -ProcessNode {
        param($xml)
        foreach ($vmp in $xml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
            $script:count++
            if ($script:count % 1000 -eq 0) {
                Write-Host "  Processed $($script:count) VMPs..." -NoNewline -ForegroundColor Gray
                Write-Host "`r" -NoNewline
            }
            
            $line = "$($vmp.VPID)`t" +
                    "$(if ($vmp.VPIDDT) { $vmp.VPIDDT } else { '' })`t" +
                    "$(if ($vmp.VPIDPREV) { $vmp.VPIDPREV } else { '' })`t" +
                    "$(if ($vmp.VTMID) { $vmp.VTMID } else { '' })`t" +
                    "$(if ($vmp.INVALID -eq '1') { '1' } else { '0' })`t" +
                    "$(Escape-BcpValue $vmp.NM)`t" +
                    "$(Escape-BcpValue $vmp.ABBREVNM)`t" +
                    "$(if ($vmp.BASISCD) { $vmp.BASISCD } else { '' })`t" +
                    "$(if ($vmp.NMDT) { $vmp.NMDT } else { '' })`t" +
                    "$(Escape-BcpValue $vmp.NMPREV)`t" +
                    "$(if ($vmp.BASIS_PREVCD) { $vmp.BASIS_PREVCD } else { '' })`t" +
                    "$(if ($vmp.NMCHANGECD) { $vmp.NMCHANGECD } else { '' })`t" +
                    "$(if ($vmp.COMPRODCD) { $vmp.COMPRODCD } else { '' })`t" +
                    "$(if ($vmp.PRES_STATCD) { $vmp.PRES_STATCD } else { '' })`t" +
                    "$(if ($vmp.SUG_F -eq '1') { '1' } else { '0' })`t" +
                    "$(if ($vmp.GLU_F -eq '1') { '1' } else { '0' })`t" +
                    "$(if ($vmp.PRES_F -eq '1') { '1' } else { '0' })`t" +
                    "$(if ($vmp.CFC_F -eq '1') { '1' } else { '0' })`t" +
                    "$(if ($vmp.NON_AVAILCD) { $vmp.NON_AVAILCD } else { '' })`t" +
                    "$(if ($vmp.NON_AVAILDT) { $vmp.NON_AVAILDT } else { '' })`t" +
                    "$(if ($vmp.DF_INDCD) { $vmp.DF_INDCD } else { '' })`t" +
                    "$(if ($vmp.UDFS) { $vmp.UDFS } else { '' })`t" +
                    "$(if ($vmp.UDFS_UOMCD) { $vmp.UDFS_UOMCD } else { '' })`t" +
                    "$(if ($vmp.UNIT_DOSE_UOMCD) { $vmp.UNIT_DOSE_UOMCD } else { '' })"
            
            [void]$script:output.AppendLine($line)
        }
    }
}

# Process Lookups
$lookupFile = Get-ChildItem -Path $currentReleasesDir -Recurse -Filter "f_lookup2_*.xml" | Select-Object -First 1
if ($lookupFile) {
    $lookupBcp = Join-Path $bcpDir "lookup.txt"
    $lookupCount = Export-ToBcpFile -XmlFile $lookupFile.FullName -OutputFile $lookupBcp -ProcessNode {
        param($xml)
        foreach ($info in $xml.LOOKUP.INFO) {
            $script:count++
            $cdprev = if ($info.CDPREV) { $info.CDPREV } else { '' }
            $cddt = if ($info.CDDT) { $info.CDDT } else { '' }
            
            [void]$script:output.AppendLine("$($info.CD)`t$(Escape-BcpValue $info.CDTYPE)`t$cddt`t$cdprev`t$(Escape-BcpValue $info.DESC)")
        }
    }
}

Write-Host "`n`nImporting data using BCP..." -ForegroundColor Yellow

# Import VTMs
if (Test-Path $vtmBcp) {
    Write-Host "Importing VTMs..."
    bcp dmd.dbo.vtm in $vtmBcp -S $Server -T -c -t"`t" -r"`n" -C 65001 -b 1000 -h "CHECK_CONSTRAINTS"
}

# Import VMPs
if (Test-Path $vmpBcp) {
    Write-Host "Importing VMPs..."
    bcp dmd.dbo.vmp in $vmpBcp -S $Server -T -c -t"`t" -r"`n" -C 65001 -b 1000 -h "CHECK_CONSTRAINTS"
}

# Import Lookups
if (Test-Path $lookupBcp) {
    Write-Host "Importing Lookups..."
    bcp dmd.dbo.lookup in $lookupBcp -S $Server -T -c -t"`t" -r"`n" -C 65001 -b 1000 -h "CHECK_CONSTRAINTS"
}

Write-Host "`n=== Import Complete ===" -ForegroundColor Green
Write-Host "`nChecking record counts..."
sqlcmd -S $Server -d $Database -E -C -Q "SELECT 'VTMs' as Table_Name, COUNT(*) as Record_Count FROM vtm UNION ALL SELECT 'VMPs', COUNT(*) FROM vmp UNION ALL SELECT 'Lookups', COUNT(*) FROM lookup"

Write-Host "`nRun Validate-DMDImport.ps1 to verify the import."
