param(
    [string]$XmlPath = "C:\DMD\CurrentReleases\nhsbsa_dmd_11.1.0_20251110000001",
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "dmd",
    [int]$BatchSize = 500
)

# Helper functions
function Escape-SqlValue {
    param([string]$value, [string]$type)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return "NULL"
    }
    if ($type -eq "date") {
        return "'" + $value.Replace("'", "''") + "'"
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
    param([string]$TableName, [string]$KeyColumn)
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
        catch {
            Write-Error "Failed to insert batch $batchNumber`: $_"
            throw
        }
    }
}

# ===== Ingredient Import =====
Write-Host "`n===== Ingredient Import =====" -ForegroundColor Cyan

$IngFiles = Get-ChildItem -Path $XmlPath -Filter "f_ingredient2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($IngFiles.Count -eq 0) {
    Write-Error "Ingredient file not found in $XmlPath"
    exit 1
}

$IngFile = $IngFiles[0].FullName
Write-Host "Found Ingredient file: $IngFile" -ForegroundColor Green

Write-Host "Loading Ingredient XML..."
[xml]$ingXml = Get-Content $IngFile

Write-Host "Checking for existing Ingredient records..."
$existingIng = Get-ExistingKeys -TableName "ingredient" -KeyColumn "isid"
Write-Host "  Found $($existingIng.Count) existing Ingredient records"

Write-Host "Processing Ingredient records..."
$ingValues = @()
$duplicatesSkipped = 0

foreach ($ing in $ingXml.INGREDIENT_SUBSTANCES.ING) {
    $isid = [string]$ing.ISID
    
    if ([string]::IsNullOrWhiteSpace($isid)) {
        continue
    }
    
    if ($existingIng.ContainsKey($isid)) {
        $duplicatesSkipped++
        continue
    }
    
    $isiddt = Escape-SqlValue $ing.ISIDDT -type "date"
    $isidprev = Escape-SqlValue $ing.ISIDPREV
    $nm = Escape-SqlValue $ing.NM
    $invalid = if ($ing.INVALID) { '1' } else { '0' }
    
    $ingValues += "($(Escape-SqlValue $isid),$isiddt,$isidprev,$nm,$invalid)"
}

Write-Host "  Processed $($ingValues.Count) unique Ingredient records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate Ingredient records"
}

if ($ingValues.Count -gt 0) {
    $columns = "(isid,isiddt,isidprev,nm,invalid)"
    Invoke-BatchedInsert -TableName "ingredient" -Columns $columns -Values $ingValues -BatchSize $BatchSize
    Write-Host "`nIngredient import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM ingredient" -QueryTimeout 30
    Write-Host "Total Ingredient records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new Ingredient records to import."
}
