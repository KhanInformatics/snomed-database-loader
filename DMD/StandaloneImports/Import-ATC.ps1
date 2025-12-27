param(
    [string]$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_11.1.0_20251110000001",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "dmd",
    [int]$BatchSize = 500
)

# Helper functions
function Escape-SqlValue {
    param([string]$value)
    if ([string]::IsNullOrWhiteSpace($value)) { return "NULL" }
    "'" + $value.Replace("'", "''") + "'"
}

function Should-SkipDuplicateCheck {
    param([string]$TableName)
    try {
        $countQuery = "SELECT COUNT(*) as cnt FROM $TableName WITH (NOLOCK)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $countQuery -QueryTimeout 10 -ConnectionTimeout 10
        return ($result.cnt -eq 0)
    }
    catch { Write-Warning "Could not check if $TableName is empty: $_"; return $false }
}

function Get-ExistingKeys {
    param([string]$TableName, [string[]]$KeyColumns)
    if (Should-SkipDuplicateCheck -TableName $TableName) {
        Write-Host "  Table is empty - skipping duplicate check"
        return @{}
    }
    Write-Host "  Loading existing keys..."
    $keys = @{}
    try {
        $colList = $KeyColumns -join ','
        $query = "SELECT $colList FROM $TableName WITH (NOLOCK)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $query -QueryTimeout 120 -ConnectionTimeout 30
        foreach ($row in $result) {
            $keyParts = $KeyColumns | ForEach-Object { [string]$row.$_ }
            $key = $keyParts -join '|'
            $keys[$key] = $true
        }
        Write-Host "  Loaded $($keys.Count) existing keys"
        return $keys
    }
    catch { Write-Error "Failed to load existing keys from $TableName`: $_"; throw }
}

function Invoke-BatchedInsert {
    param([string]$TableName, [string]$Columns, [string[]]$Values, [int]$BatchSize = 500)
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
        catch { Write-Error "Failed to insert batch $batchNumber`: $_"; throw }
    }
}

# ===== ATC Import =====
Write-Host "`n===== ATC Code Import =====" -ForegroundColor Cyan

# ATC codes are in the BNF bonus file (NOT in VMP file!)
$BonusPath = "C:\DMD\CurrentReleases\nhsbsa_dmdbonus_11.1.0_20251110000001"
$BnfFiles = Get-ChildItem -Path $BonusPath -Filter "f_bnf1_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($BnfFiles.Count -eq 0) {
    Write-Error "BNF file not found in $BonusPath"
    exit 1
}

$BnfFile = $BnfFiles[0].FullName
Write-Host "Found BNF file: $BnfFile" -ForegroundColor Green

Write-Host "Loading BNF XML..."
[xml]$bnfXml = Get-Content $BnfFile

Write-Host "Checking for existing ATC records..."
$existingKeys = Get-ExistingKeys -TableName "dmd_atc" -KeyColumns @("vpid", "atc_code")
Write-Host "  Found $($existingKeys.Count) existing ATC records"

Write-Host "Processing ATC records..."
$values = @()
$duplicatesSkipped = 0

# ATC codes are found in the BNF file under BNF_DETAILS.VMPS.VMP
if ($bnfXml.BNF_DETAILS.VMPS) {
    foreach ($vmp in $bnfXml.BNF_DETAILS.VMPS.VMP) {
        $vpid = [string]$vmp.VPID
        $atc_code = [string]$vmp.ATC
        
        if ([string]::IsNullOrWhiteSpace($vpid) -or [string]::IsNullOrWhiteSpace($atc_code)) { continue }
        
        $key = "$vpid|$atc_code"
        if ($existingKeys.ContainsKey($key)) {
            $duplicatesSkipped++
            continue
        }
        
        $values += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $atc_code))"
    }
}

Write-Host "  Processed $($values.Count) unique ATC records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate ATC records"
}

if ($values.Count -gt 0) {
    $columns = "(vpid,atc_code)"
    Invoke-BatchedInsert -TableName "dmd_atc" -Columns $columns -Values $values -BatchSize $BatchSize
    Write-Host "`nATC import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM dmd_atc" -QueryTimeout 30
    Write-Host "Total ATC records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new ATC records to import."
}
