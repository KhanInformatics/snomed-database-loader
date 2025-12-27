param(
    [string]$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_11.1.0_20251110000001",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "dmd",
    [int]$BatchSize = 500
)

# Helper functions
function Escape-SqlValue {
    param([string]$value)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return "NULL"
    }
    "'" + $value.Replace("'", "''") + "'"
}

function Should-SkipDuplicateCheck {
    param([string]$TableName)
    
    try {
        $countQuery = "SELECT COUNT(*) as cnt FROM $TableName WITH (NOLOCK)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $countQuery -QueryTimeout 10 -ConnectionTimeout 10
        return ($result.cnt -eq 0)
    }
    catch {
        Write-Warning "Could not check if $TableName is empty: $_"
        return $false
    }
}

function Get-ExistingKeys {
    param(
        [string]$TableName,
        [string]$KeyColumn
    )
    
    if (Should-SkipDuplicateCheck -TableName $TableName) {
        Write-Host "  Table is empty - skipping duplicate check"
        return @{}
    }
    
    Write-Host "  Loading existing keys for duplicate checking..."
    $keys = @{}
    
    try {
        $query = "SELECT $KeyColumn FROM $TableName WITH (NOLOCK)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $query -QueryTimeout 120 -ConnectionTimeout 30
        
        foreach ($row in $result) {
            $key = [string]$row[0]
            $keys[$key] = $true
        }
        
        Write-Host "  Loaded $($keys.Count) existing keys"
        return $keys
    }
    catch {
        Write-Error "Failed to load existing keys from $TableName`: $_"
        throw
    }
}

function Invoke-BatchedInsert {
    param(
        [string]$TableName,
        [string]$Columns,
        [string[]]$Values,
        [int]$BatchSize = 500
    )
    
    $totalBatches = [Math]::Ceiling($Values.Count / $BatchSize)
    $totalRecords = $Values.Count
    Write-Host "Importing $totalRecords records into $TableName in $totalBatches batches..."
    
    for ($i = 0; $i -lt $Values.Count; $i += $BatchSize) {
        $batchNumber = [Math]::Floor($i / $BatchSize) + 1
        $end = [Math]::Min($i + $BatchSize, $Values.Count)
        $batchValues = $Values[$i..($end-1)] -join ','
        
        $insertSql = "INSERT INTO $TableName $Columns VALUES $batchValues"
        
        try {
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $insertSql -QueryTimeout 120 -ConnectionTimeout 30
            Write-Host "  Batch $batchNumber/$totalBatches complete ($end/$totalRecords records)"
        }
        catch {
            Write-Error "Failed to insert batch $batchNumber`: $_"
            throw
        }
    }
}

# ===== AMPP Import =====
Write-Host "`n===== AMPP (Actual Medicinal Product Packs) Import =====" -ForegroundColor Cyan

$AmppFiles = Get-ChildItem -Path $XmlPath -Filter "f_ampp2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($AmppFiles.Count -eq 0) {
    Write-Error "AMPP file not found in $XmlPath"
    exit 1
}

$AmppFile = $AmppFiles[0].FullName
Write-Host "Found AMPP file: $AmppFile" -ForegroundColor Green

Write-Host "Loading AMPP XML..."
[xml]$amppXml = Get-Content $AmppFile

Write-Host "Checking for existing AMPP records..."
$existingAmpp = Get-ExistingKeys -TableName "ampp" -KeyColumn "appid"
Write-Host "  Found $($existingAmpp.Count) existing AMPP records"

Write-Host "Processing AMPP records..."
$amppValues = @()
$duplicatesSkipped = 0

foreach ($ampp in $amppXml.ACTUAL_MEDICINAL_PROD_PACKS.AMPPS.AMPP) {
    $appid = [string]$ampp.APPID
    
    if ($existingAmpp.ContainsKey($appid)) {
        $duplicatesSkipped++
        continue
    }
    
    $invalid = if ($ampp.INVALID) { '1' } else { '0' }
    $vppid = [string]$ampp.VPPID
    $apid = [string]$ampp.APID
    $nm = [string]$ampp.NM
    $legal_catcd = Escape-SqlValue $ampp.LEGAL_CATCD
    $subp = Escape-SqlValue $ampp.SUBP
    $disccd = Escape-SqlValue $ampp.DISCCD
    $hosp_f = if ($ampp.HOSP_F) { '1' } else { '0' }
    $broken_bulk_f = if ($ampp.BROKEN_BULK_F) { '1' } else { '0' }
    $nurse_f = if ($ampp.NURSE_F) { '1' } else { '0' }
    $enurse_f = if ($ampp.ENURSE_F) { '1' } else { '0' }
    $dent_f = if ($ampp.DENT_F) { '1' } else { '0' }
    
    $amppValues += "($(Escape-SqlValue $appid),$invalid,$(Escape-SqlValue $vppid),$(Escape-SqlValue $apid),$(Escape-SqlValue $nm),$legal_catcd,$subp,$disccd,$hosp_f,$broken_bulk_f,$nurse_f,$enurse_f,$dent_f)"
}

Write-Host "  Processed $($amppValues.Count) unique AMPP records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate AMPP records"
}

if ($amppValues.Count -gt 0) {
    $columns = "(appid,invalid,vppid,apid,nm,legal_catcd,subp,disccd,hosp_f,broken_bulk_f,nurse_f,enurse_f,dent_f)"
    Invoke-BatchedInsert -TableName "ampp" -Columns $columns -Values $amppValues -BatchSize $BatchSize
    Write-Host "`nAMPP import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM ampp" -QueryTimeout 30
    Write-Host "Total AMPP records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new AMPP records to import."
}
