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

function Get-ExistingKeys {
    param(
        [string]$TableName,
        [string]$KeyColumn
    )
    $keys = @{}
    $keyColumns = $KeyColumn.Split(',')
    $query = "SELECT $KeyColumn FROM $TableName"
    $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $query
    
    foreach ($row in $result) {
        if ($keyColumns.Count -eq 1) {
            $key = [string]$row[0]
        } else {
            $key = ($keyColumns | ForEach-Object { [string]$row.$_ }) -join '|'
        }
        $keys[$key] = $true
    }
    
    return $keys
}

function Invoke-BatchedInsert {
    param(
        [string]$TableName,
        [string]$Columns,
        [string[]]$Values,
        [int]$BatchSize = 500
    )
    
    $totalBatches = [Math]::Ceiling($Values.Count / $BatchSize)
    Write-Host "Importing $($Values.Count) records into $TableName in $totalBatches batches..."
    
    for ($i = 0; $i -lt $Values.Count; $i += $BatchSize) {
        $batchNumber = [Math]::Floor($i / $BatchSize) + 1
        $end = [Math]::Min($i + $BatchSize, $Values.Count)
        $batchValues = $Values[$i..($end-1)] -join ','
        
        $insertSql = "INSERT INTO $TableName $Columns VALUES $batchValues"
        
        try {
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query $insertSql
            Write-Host "  Batch $batchNumber of $totalBatches complete"
        }
        catch {
            Write-Error "Failed to insert batch $batchNumber`: $_"
            throw
        }
    }
}

# ===== GTIN Import =====
Write-Host "`n===== GTIN Import =====" -ForegroundColor Cyan

# Auto-detect GTIN file
$GtinFiles = Get-ChildItem -Path $XmlPath -Filter "f_gtin2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($GtinFiles.Count -eq 0) {
    Write-Warning "GTIN file not found - skipping GTIN import."
    exit 1
}

$GtinFile = $GtinFiles[0].FullName
Write-Host "Found GTIN file: $GtinFile" -ForegroundColor Green

Write-Host "Loading GTIN XML..."
[xml]$gtinXml = Get-Content $GtinFile

# Get existing GTINs to avoid duplicates
Write-Host "Checking for existing GTINs..."
$existingGtin = Get-ExistingKeys -TableName "gtin" -KeyColumn "appid,gtin"
Write-Host "  Found $($existingGtin.Count) existing GTIN records"

Write-Host "Processing GTIN records..."
$gtinValues = @()
$seenGtin = @{}
$duplicatesSkipped = 0

foreach ($ampp in $gtinXml.GTIN_DETAILS.AMPPS.AMPP) {
    $appid = [string]$ampp.AMPPID
    
    # Handle both single GTINDATA and array of GTINDATA
    $gtinDataArray = @($ampp.GTINDATA)
    
    foreach ($gtinData in $gtinDataArray) {
        $gtin = [string]$gtinData.GTIN
        $startdt = [string]$gtinData.STARTDT
        $enddt = [string]$gtinData.ENDDT
        
        if (-not [string]::IsNullOrWhiteSpace($appid) -and -not [string]::IsNullOrWhiteSpace($gtin)) {
            $key = "$appid|$gtin"
            
            # Skip if already exists
            if ($existingGtin.ContainsKey($key) -or $seenGtin.ContainsKey($key)) {
                $duplicatesSkipped++
                continue
            }
            
            $seenGtin[$key] = $true
            
            # Build value string
            $startdtValue = if ([string]::IsNullOrWhiteSpace($startdt)) { "NULL" } else { Escape-SqlValue $startdt }
            $enddtValue = if ([string]::IsNullOrWhiteSpace($enddt)) { "NULL" } else { Escape-SqlValue $enddt }
            
            $gtinValues += "($(Escape-SqlValue $appid),$(Escape-SqlValue $gtin),$startdtValue,$enddtValue)"
        }
    }
}

Write-Host "  Processed $($gtinValues.Count) unique GTIN records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate GTIN records"
}

if ($gtinValues.Count -gt 0) {
    Invoke-BatchedInsert -TableName "gtin" -Columns "(appid,gtin,startdt,enddt)" -Values $gtinValues -BatchSize $BatchSize
    Write-Host "`nGTIN import complete!" -ForegroundColor Green
} else {
    Write-Warning "No new GTIN records to import."
}
