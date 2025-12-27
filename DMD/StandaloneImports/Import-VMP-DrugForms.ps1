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

# ===== VMP Drug Forms Import =====
Write-Host "`n===== VMP Drug Forms Import =====" -ForegroundColor Cyan

$VmpFiles = Get-ChildItem -Path $XmlPath -Filter "f_vmp2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($VmpFiles.Count -eq 0) {
    Write-Error "VMP file not found in $XmlPath"
    exit 1
}

$VmpFile = $VmpFiles[0].FullName
Write-Host "Found VMP file: $VmpFile" -ForegroundColor Green

Write-Host "Loading VMP XML..."
[xml]$vmpXml = Get-Content $VmpFile

Write-Host "Checking for existing VMP Drug Form records..."
$existingKeys = Get-ExistingKeys -TableName "vmp_drugform" -KeyColumns @("vpid", "formcd")
Write-Host "  Found $($existingKeys.Count) existing VMP Drug Form records"

Write-Host "Processing VMP Drug Form records..."
$values = @()
$duplicatesSkipped = 0

foreach ($form in $vmpXml.VIRTUAL_MED_PRODUCTS.DRUG_FORM.DFORM) {
    $vpid = [string]$form.VPID
    $formcd = [string]$form.FORMCD
    
    if ([string]::IsNullOrWhiteSpace($vpid) -or [string]::IsNullOrWhiteSpace($formcd)) { continue }
    
    $key = "$vpid|$formcd"
    if ($existingKeys.ContainsKey($key)) {
        $duplicatesSkipped++
        continue
    }
    
    $values += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $formcd))"
}

Write-Host "  Processed $($values.Count) unique VMP Drug Form records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate VMP Drug Form records"
}

if ($values.Count -gt 0) {
    $columns = "(vpid,formcd)"
    Invoke-BatchedInsert -TableName "vmp_drugform" -Columns $columns -Values $values -BatchSize $BatchSize
    Write-Host "`nVMP Drug Form import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM vmp_drugform" -QueryTimeout 30
    Write-Host "Total VMP Drug Form records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new VMP Drug Form records to import."
}
