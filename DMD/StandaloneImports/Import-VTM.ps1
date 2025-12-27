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

# ===== VTM Import =====
Write-Host "`n===== VTM (Virtual Therapeutic Moiety) Import =====" -ForegroundColor Cyan

# Find VTM file
$VtmFiles = Get-ChildItem -Path $XmlPath -Filter "f_vtm2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($VtmFiles.Count -eq 0) {
    Write-Error "VTM file not found in $XmlPath"
    exit 1
}

$VtmFile = $VtmFiles[0].FullName
Write-Host "Found VTM file: $VtmFile" -ForegroundColor Green

Write-Host "Loading VTM XML..."
[xml]$vtmXml = Get-Content $VtmFile

Write-Host "Checking for existing VTM records..."
$existingKeys = Get-ExistingKeys -TableName "vtm" -KeyColumns @("vtmid")
Write-Host "  Found $($existingKeys.Count) existing VTM records"

Write-Host "Processing VTM records..."
$values = @()
$duplicatesSkipped = 0

foreach ($vtm in $vtmXml.VIRTUAL_THERAPEUTIC_MOIETIES.VTM) {
    $vtmid = [string]$vtm.VTMID
    $invalid = if ([string]::IsNullOrWhiteSpace($vtm.INVALID)) { "0" } else { [string]$vtm.INVALID }
    $nm = [string]$vtm.NM
    $abbrevnm = [string]$vtm.ABBREVNM
    $vtmidprev = [string]$vtm.VTMIDPREV
    $vtmiddt = [string]$vtm.VTMIDDT
    
    if ([string]::IsNullOrWhiteSpace($vtmid)) { continue }
    
    $key = $vtmid
    if ($existingKeys.ContainsKey($key)) {
        $duplicatesSkipped++
        continue
    }
    
    $values += "($(Escape-SqlValue $vtmid),$invalid,$(Escape-SqlValue $nm),$(Escape-SqlValue $abbrevnm),$(Escape-SqlValue $vtmidprev),$(Escape-SqlValue $vtmiddt))"
    $existingKeys[$key] = $true
}

Write-Host "  Processed $($values.Count) unique VTM records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate VTM records"
}

if ($values.Count -gt 0) {
    $columns = "(vtmid,invalid,nm,abbrevnm,vtmidprev,vtmiddt)"
    Invoke-BatchedInsert -TableName "vtm" -Columns $columns -Values $values -BatchSize $BatchSize
    Write-Host "`nVTM import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM vtm" -QueryTimeout 30
    Write-Host "Total VTM records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new VTM records to import."
}
