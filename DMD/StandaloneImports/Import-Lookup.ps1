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

function Get-ExistingLookupKeys {
    param([string]$TableName)
    if (Should-SkipDuplicateCheck -TableName $TableName) {
        Write-Host "  Table is empty - skipping duplicate check"
        return @{}
    }
    Write-Host "  Loading existing lookup keys..."
    $keys = @{}
    try {
        $query = "SELECT type, cd FROM $TableName WITH (NOLOCK)"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $query -QueryTimeout 120 -ConnectionTimeout 30
        foreach ($row in $result) {
            $key = "$($row.type)|$($row.cd)"
            $keys[$key] = $true
        }
        Write-Host "  Loaded $($keys.Count) existing lookup keys"
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

# ===== Lookup Import =====
Write-Host "`n===== Lookup Import =====" -ForegroundColor Cyan

$LookupFiles = Get-ChildItem -Path $XmlPath -Filter "f_lookup2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($LookupFiles.Count -eq 0) {
    Write-Error "Lookup file not found in $XmlPath"
    exit 1
}

$LookupFile = $LookupFiles[0].FullName
Write-Host "Found Lookup file: $LookupFile" -ForegroundColor Green

Write-Host "Loading Lookup XML..."
[xml]$lookupXml = Get-Content $LookupFile

Write-Host "Checking for existing Lookup records..."
$existingLookup = Get-ExistingLookupKeys -TableName "lookup"
Write-Host "  Found $($existingLookup.Count) existing Lookup records"

Write-Host "Processing Lookup records..."
$lookupValues = @()
$duplicatesSkipped = 0

# Iterate over each child section of LOOKUP (e.g., FORM, ROUTE, SUPPLIER, etc.)
foreach ($section in $lookupXml.LOOKUP.ChildNodes) {
    if ($null -eq $section -or $section.NodeType -ne [System.Xml.XmlNodeType]::Element) {
        continue
    }
    
    $typeName = $section.Name
    $infos = @($section.INFO)
    
    foreach ($info in $infos) {
        if ($null -eq $info) { continue }
        
        $cd = [string]$info.CD
        $desc = [string]$info.DESC
        
        if ([string]::IsNullOrWhiteSpace($cd) -or [string]::IsNullOrWhiteSpace($desc)) {
            continue
        }
        
        $key = "$typeName|$cd"
        if ($existingLookup.ContainsKey($key)) {
            $duplicatesSkipped++
            continue
        }
        
        $lookupValues += "($(Escape-SqlValue $typeName),$(Escape-SqlValue $cd),$(Escape-SqlValue $desc))"
    }
}

Write-Host "  Processed $($lookupValues.Count) unique Lookup records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate Lookup records"
}

if ($lookupValues.Count -gt 0) {
    $columns = "(type,cd,descr)"
    Invoke-BatchedInsert -TableName "lookup" -Columns $columns -Values $lookupValues -BatchSize $BatchSize
    Write-Host "`nLookup import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM lookup" -QueryTimeout 30
    Write-Host "Total Lookup records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new Lookup records to import."
}
