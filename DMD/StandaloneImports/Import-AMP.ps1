param(
    [string]$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_11.1.0_20251110000001",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "dmd",
    [int]$BatchSize = 500
)

# Helper functions
function Escape-SqlValue {
    param([string]$value)
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
    
    # Check if table is empty first
    if (Should-SkipDuplicateCheck -TableName $TableName) {
        Write-Host "  Table is empty - skipping duplicate check"
        return @{}
    }
    
    Write-Host "  Loading existing keys for duplicate checking..."
    $keys = @{}
    $keyColumns = $KeyColumn.Split(',')
    
    try {
        $query = "SELECT $KeyColumn FROM $TableName WITH (NOLOCK)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $query -QueryTimeout 120 -ConnectionTimeout 30
        
        foreach ($row in $result) {
            if ($keyColumns.Count -eq 1) {
                $key = [string]$row[0]
            } else {
                $key = ($keyColumns | ForEach-Object { [string]$row.$_ }) -join '|'
            }
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
        $recordsInBatch = $end - $i
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

# ===== AMP Import =====
Write-Host "`n===== AMP (Actual Medicinal Products) Import =====" -ForegroundColor Cyan

# Auto-detect AMP file
$AmpFiles = Get-ChildItem -Path $XmlPath -Filter "f_amp2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($AmpFiles.Count -eq 0) {
    Write-Error "AMP file not found in $XmlPath"
    exit 1
}

$AmpFile = $AmpFiles[0].FullName
Write-Host "Found AMP file: $AmpFile" -ForegroundColor Green

Write-Host "Loading AMP XML..."
[xml]$ampXml = Get-Content $AmpFile

# Get existing AMPs to avoid duplicates
Write-Host "Checking for existing AMP records..."
$existingAmp = Get-ExistingKeys -TableName "amp" -KeyColumn "apid"
Write-Host "  Found $($existingAmp.Count) existing AMP records"

Write-Host "Processing AMP records..."
$ampValues = @()
$duplicatesSkipped = 0

foreach ($amp in $ampXml.ACTUAL_MEDICINAL_PRODUCTS.AMPS.AMP) {
    $apid = [string]$amp.APID
    
    # Skip if already exists
    if ($existingAmp.ContainsKey($apid)) {
        $duplicatesSkipped++
        continue
    }
    
    # Extract fields
    $vpid = [string]$amp.VPID
    $nm = [string]$amp.NM
    $desc = [string]$amp.DESC
    $suppcd = [string]$amp.SUPPCD
    $lic_authcd = [string]$amp.LIC_AUTHCD
    $avail_restrictcd = [string]$amp.AVAIL_RESTRICTCD
    
    # Build value string with proper NULL handling
    $vpidValue = if ([string]::IsNullOrWhiteSpace($vpid)) { "NULL" } else { Escape-SqlValue $vpid }
    $nmValue = Escape-SqlValue $nm
    $descValue = if ([string]::IsNullOrWhiteSpace($desc)) { "NULL" } else { Escape-SqlValue $desc }
    $suppcdValue = if ([string]::IsNullOrWhiteSpace($suppcd)) { "NULL" } else { Escape-SqlValue $suppcd }
    $lic_authcdValue = if ([string]::IsNullOrWhiteSpace($lic_authcd)) { "NULL" } else { Escape-SqlValue $lic_authcd }
    $avail_restrictcdValue = if ([string]::IsNullOrWhiteSpace($avail_restrictcd)) { "NULL" } else { Escape-SqlValue $avail_restrictcd }
    
    # AMP has many optional fields - setting defaults for fields not in basic XML structure
    # Based on table structure: apid, invalid, vpid, nm, abbrevnm, desc_f, nmdt, nm_prev, suppcd, 
    # lic_authcd, lic_auth_prevcd, lic_authchangecd, lic_authchangedt, combprodcd, flavourcd, 
    # ema_f, parallel_import_f, avail_restrictcd
    
    $ampValues += "($(Escape-SqlValue $apid),0,$vpidValue,$nmValue,NULL,0,NULL,NULL,$suppcdValue,$lic_authcdValue,NULL,NULL,NULL,NULL,NULL,0,0,$avail_restrictcdValue)"
}

Write-Host "  Processed $($ampValues.Count) unique AMP records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate AMP records"
}

if ($ampValues.Count -gt 0) {
    $columns = "(apid,invalid,vpid,nm,abbrevnm,desc_f,nmdt,nm_prev,suppcd,lic_authcd,lic_auth_prevcd,lic_authchangecd,lic_authchangedt,combprodcd,flavourcd,ema_f,parallel_import_f,avail_restrictcd)"
    Invoke-BatchedInsert -TableName "amp" -Columns $columns -Values $ampValues -BatchSize $BatchSize
    Write-Host "`nAMP import complete!" -ForegroundColor Green
    
    # Verify count
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM amp" -QueryTimeout 30
    Write-Host "Total AMP records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new AMP records to import."
}
