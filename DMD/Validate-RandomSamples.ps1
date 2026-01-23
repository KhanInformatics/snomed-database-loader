# Validate random samples from XML against database
param(
    [string]$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_11.1.0_20251110000001",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [int]$SamplesPerTable = 3
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RANDOM SAMPLE VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Auto-detect file names (they have release-specific suffixes)
$vtmFile = (Get-ChildItem -Path $XmlPath -Filter "f_vtm2_*.xml" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
$vmpFile = (Get-ChildItem -Path $XmlPath -Filter "f_vmp2_*.xml" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
$ampFile = (Get-ChildItem -Path $XmlPath -Filter "f_amp2_*.xml" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
$ingFile = (Get-ChildItem -Path $XmlPath -Filter "f_ingredient2_*.xml" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName

# VTM Validation
Write-Host "=== VTM (Virtual Therapeutic Moiety) ===" -ForegroundColor Yellow
if ($vtmFile -and (Test-Path $vtmFile)) {
    [xml]$vtmXml = Get-Content $vtmFile
    $allVtms = @($vtmXml.SelectNodes("//VTM"))
    $vtmSamples = $allVtms | Get-Random -Count $SamplesPerTable

    foreach ($vtm in $vtmSamples) {
        $vtmid = $vtm.VTMID
        $xmlNm = $vtm.NM
        $xmlInvalid = if ($vtm.INVALID) { $vtm.INVALID } else { "NULL" }
        
        if (-not $vtmid) { continue }  # Skip if empty
        
        Write-Host "`nXML:  VTMID=$vtmid | NM=$xmlNm | INVALID=$xmlInvalid" -ForegroundColor Gray
        
        $dbResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -TrustServerCertificate -Query "SELECT vtmid, nm, invalid FROM vtm WHERE vtmid = CAST($vtmid AS BIGINT)"
        
        if ($dbResult) {
            $dbInvalid = if ($dbResult.invalid) { $dbResult.invalid } else { "NULL" }
            Write-Host "DB:   VTMID=$($dbResult.vtmid) | NM=$($dbResult.nm) | INVALID=$dbInvalid" -ForegroundColor Gray
            
            if ($xmlNm -eq $dbResult.nm) {
                Write-Host "✓ MATCH" -ForegroundColor Green
            } else {
                Write-Host "✗ MISMATCH!" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ NOT FOUND IN DATABASE!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "VTM file not found in $XmlPath" -ForegroundColor Red
}

# VMP Validation
Write-Host "`n=== VMP (Virtual Medicinal Product) ===" -ForegroundColor Yellow
if ($vmpFile -and (Test-Path $vmpFile)) {
    [xml]$vmpXml = Get-Content $vmpFile
    $vmpSamples = $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP | Get-Random -Count $SamplesPerTable

    foreach ($vmp in $vmpSamples) {
        $vpid = $vmp.VPID
        $xmlNm = $vmp.NM
        $xmlVtmid = if ($vmp.VTMID) { $vmp.VTMID } else { "NULL" }
        
        Write-Host "`nXML:  VPID=$vpid | NM=$xmlNm | VTMID=$xmlVtmid" -ForegroundColor Gray
        
        $dbResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -TrustServerCertificate -Query "SELECT vpid, nm, vtmid FROM vmp WHERE vpid = CAST($vpid AS BIGINT)"
        
        if ($dbResult) {
            $dbVtmid = if ($null -ne $dbResult.vtmid -and $dbResult.vtmid -isnot [System.DBNull]) { $dbResult.vtmid } else { "NULL" }
            Write-Host "DB:   VPID=$($dbResult.vpid) | NM=$($dbResult.nm) | VTMID=$dbVtmid" -ForegroundColor Gray
            
            # Compare: Names must match exactly, but NULL/empty are equivalent for VTMID
            $nameMatch = $xmlNm -eq $dbResult.nm
            $vtmidMatch = ($xmlVtmid -eq $dbVtmid) -or (($xmlVtmid -eq "NULL" -or $xmlVtmid -eq "") -and ($dbVtmid -eq "NULL" -or $dbVtmid -eq ""))
            
            if ($nameMatch -and $vtmidMatch) {
                Write-Host "✓ MATCH" -ForegroundColor Green
            } else {
                Write-Host "✗ MISMATCH!" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ NOT FOUND IN DATABASE!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "VMP file not found in $XmlPath" -ForegroundColor Red
}

# AMP Validation
Write-Host "`n=== AMP (Actual Medicinal Product) ===" -ForegroundColor Yellow
if ($ampFile -and (Test-Path $ampFile)) {
    [xml]$ampXml = Get-Content $ampFile
    $ampSamples = $ampXml.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP | Get-Random -Count $SamplesPerTable

    foreach ($amp in $ampSamples) {
        $apid = $amp.APID
        $xmlNm = $amp.NM
        $xmlVpid = if ($amp.VPID) { $amp.VPID } else { "NULL" }
        
        Write-Host "`nXML:  APID=$apid | NM=$xmlNm | VPID=$xmlVpid" -ForegroundColor Gray
        
        $dbResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -TrustServerCertificate -Query "SELECT apid, nm, vpid FROM amp WHERE apid = CAST($apid AS BIGINT)"
        
        if ($dbResult) {
            $dbVpid = if ($dbResult.vpid) { $dbResult.vpid } else { "NULL" }
            Write-Host "DB:   APID=$($dbResult.apid) | NM=$($dbResult.nm) | VPID=$dbVpid" -ForegroundColor Gray
            
            # Compare: Names must match exactly, but NULL/empty are equivalent for VPID
            $nameMatch = $xmlNm -eq $dbResult.nm
            $vpidMatch = ($xmlVpid -eq $dbVpid) -or (($xmlVpid -eq "NULL" -or $xmlVpid -eq "") -and ($dbVpid -eq "NULL" -or $dbVpid -eq ""))
            
            if ($nameMatch -and $vpidMatch) {
                Write-Host "✓ MATCH" -ForegroundColor Green
            } else {
                Write-Host "✗ MISMATCH!" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ NOT FOUND IN DATABASE!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "AMP file not found in $XmlPath" -ForegroundColor Red
}

# Ingredient Validation
Write-Host "`n=== INGREDIENT ===" -ForegroundColor Yellow
if ($ingFile -and (Test-Path $ingFile)) {
    [xml]$ingXml = Get-Content $ingFile
    $allIngs = @($ingXml.SelectNodes("//ING"))
    $ingSamples = $allIngs | Get-Random -Count $SamplesPerTable

    foreach ($ing in $ingSamples) {
        $isid = $ing.ISID
        $xmlNm = $ing.NM
        $xmlInvalid = if ($ing.INVALID) { $ing.INVALID } else { "NULL" }
        
        if (-not $isid) { continue }  # Skip if empty
        
        Write-Host "`nXML:  ISID=$isid | NM=$xmlNm | INVALID=$xmlInvalid" -ForegroundColor Gray
        
        $dbResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -TrustServerCertificate -Query "SELECT isid, nm, invalid FROM ingredient WHERE isid = CAST($isid AS BIGINT)"
        
        if ($dbResult) {
            $dbInvalid = if ($dbResult.invalid) { $dbResult.invalid } else { "NULL" }
            Write-Host "DB:   ISID=$($dbResult.isid) | NM=$($dbResult.nm) | INVALID=$dbInvalid" -ForegroundColor Gray
            
            if ($xmlNm -eq $dbResult.nm) {
                Write-Host "✓ MATCH" -ForegroundColor Green
            } else {
                Write-Host "✗ MISMATCH!" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ NOT FOUND IN DATABASE!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Ingredient file not found in $XmlPath" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VALIDATION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
