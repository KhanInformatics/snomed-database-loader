param(
    [string]$BonusPath = "C:\DMD\CurrentReleases\nhsbsa_dmdbonus_11.1.0_20251110000001",
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

# ===== BNF Import =====
Write-Host "`n===== BNF Code Import =====" -ForegroundColor Cyan

$BnfFiles = Get-ChildItem -Path $BonusPath -Filter "f_bnf1_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($BnfFiles.Count -eq 0) {
    Write-Error "BNF file not found in $BonusPath"
    exit 1
}

$BnfFile = $BnfFiles[0].FullName
Write-Host "Found BNF file: $BnfFile" -ForegroundColor Green

Write-Host "Loading BNF XML..."
[xml]$bnfXml = Get-Content $BnfFile

Write-Host "Checking for existing BNF records..."
$existingKeys = Get-ExistingKeys -TableName "dmd_bnf" -KeyColumns @("vpid", "bnf_code")
Write-Host "  Found $($existingKeys.Count) existing BNF records"

Write-Host "Processing BNF records..."
$values = @()
$duplicatesSkipped = 0

foreach ($vmp in $bnfXml.BNF_DETAILS.VMPS.VMP) {
    $vpid = [string]$vmp.VPID
    $bnf = [string]$vmp.BNF
    
    if ([string]::IsNullOrWhiteSpace($vpid) -or [string]::IsNullOrWhiteSpace($bnf)) { continue }
    
    $key = "$vpid|$bnf"
    if ($existingKeys.ContainsKey($key)) {
        $duplicatesSkipped++
        continue
    }
    
    $values += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $bnf))"
}

Write-Host "  Processed $($values.Count) unique BNF records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate BNF records"
}

if ($values.Count -gt 0) {
    $columns = "(vpid,bnf_code)"
    Invoke-BatchedInsert -TableName "dmd_bnf" -Columns $columns -Values $values -BatchSize $BatchSize
    Write-Host "`nBNF import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM dmd_bnf" -QueryTimeout 30
    Write-Host "Total BNF records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new BNF records to import."
}
