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

function Ensure-VmpIngredientSchema {
    $columns = @("strnt_nmrtr_val", "strnt_dnmtr_val")
    $metadataQuery = @"
SELECT
    c.name,
    TYPE_NAME(c.user_type_id) AS type_name,
    c.precision,
    c.scale
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dbo.vmp_ingredient')
  AND c.name IN ('strnt_nmrtr_val', 'strnt_dnmtr_val');
"@

    $metadata = @(Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName `
        -TrustServerCertificate -Query $metadataQuery -QueryTimeout 30 -ConnectionTimeout 30 -ErrorAction Stop)

    foreach ($column in $columns) {
        $columnMetadata = $metadata | Where-Object { $_.name -eq $column } | Select-Object -First 1
        if (-not $columnMetadata) {
            throw "Required column dbo.vmp_ingredient.$column was not found."
        }

        $hasRequiredPrecision = $columnMetadata.type_name -in @("decimal", "numeric") -and
            [int]$columnMetadata.scale -ge 5 -and
            ([int]$columnMetadata.precision - [int]$columnMetadata.scale) -ge 13

        if (-not $hasRequiredPrecision) {
            Write-Host "  Updating dbo.vmp_ingredient.$column to DECIMAL(18,5)..."
            $alterSql = "ALTER TABLE dbo.vmp_ingredient ALTER COLUMN $column DECIMAL(18,5) NULL;"
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName `
                -TrustServerCertificate -Query $alterSql -QueryTimeout 120 -ConnectionTimeout 30 -ErrorAction Stop
        }
    }
}

function Invoke-BatchedUpsert {
    param([string]$TableName, [string]$Columns, [string[]]$Values, [int]$BatchSize = 500)

    $totalBatches = [Math]::Ceiling($Values.Count / $BatchSize)
    $totalRecords = $Values.Count
    $inserted = 0
    $updated = 0
    Write-Host "Upserting $totalRecords records into $TableName in $totalBatches batches..."

    for ($i = 0; $i -lt $Values.Count; $i += $BatchSize) {
        $batchNumber = [Math]::Floor($i / $BatchSize) + 1
        $end = [Math]::Min($i + $BatchSize, $Values.Count)
        $batchValues = $Values[$i..($end-1)] -join ','
        $upsertSql = @"
;MERGE INTO $TableName WITH (HOLDLOCK) AS target
USING (
    SELECT
        CONVERT(VARCHAR(18), raw.vpid) AS vpid,
        CONVERT(VARCHAR(18), raw.isid) AS isid,
        CONVERT(VARCHAR(10), raw.basis_strntcd) AS basis_strntcd,
        CONVERT(VARCHAR(18), raw.bs_subid) AS bs_subid,
        CONVERT(DECIMAL(18,5), raw.strnt_nmrtr_val) AS strnt_nmrtr_val,
        CONVERT(VARCHAR(18), raw.strnt_nmrtr_uomcd) AS strnt_nmrtr_uomcd,
        CONVERT(DECIMAL(18,5), raw.strnt_dnmtr_val) AS strnt_dnmtr_val,
        CONVERT(VARCHAR(18), raw.strnt_dnmtr_uomcd) AS strnt_dnmtr_uomcd
    FROM (VALUES $batchValues) AS raw
        (vpid, isid, basis_strntcd, bs_subid, strnt_nmrtr_val, strnt_nmrtr_uomcd, strnt_dnmtr_val, strnt_dnmtr_uomcd)
) AS source
ON target.vpid = source.vpid
AND target.isid = source.isid
WHEN MATCHED AND (
       ISNULL(target.basis_strntcd, '') <> ISNULL(source.basis_strntcd, '')
    OR ISNULL(target.bs_subid, '') <> ISNULL(source.bs_subid, '')
    OR target.strnt_nmrtr_val <> source.strnt_nmrtr_val
    OR (target.strnt_nmrtr_val IS NULL AND source.strnt_nmrtr_val IS NOT NULL)
    OR (target.strnt_nmrtr_val IS NOT NULL AND source.strnt_nmrtr_val IS NULL)
    OR ISNULL(target.strnt_nmrtr_uomcd, '') <> ISNULL(source.strnt_nmrtr_uomcd, '')
    OR target.strnt_dnmtr_val <> source.strnt_dnmtr_val
    OR (target.strnt_dnmtr_val IS NULL AND source.strnt_dnmtr_val IS NOT NULL)
    OR (target.strnt_dnmtr_val IS NOT NULL AND source.strnt_dnmtr_val IS NULL)
    OR ISNULL(target.strnt_dnmtr_uomcd, '') <> ISNULL(source.strnt_dnmtr_uomcd, '')
) THEN
    UPDATE SET
        basis_strntcd = source.basis_strntcd,
        bs_subid = source.bs_subid,
        strnt_nmrtr_val = source.strnt_nmrtr_val,
        strnt_nmrtr_uomcd = source.strnt_nmrtr_uomcd,
        strnt_dnmtr_val = source.strnt_dnmtr_val,
        strnt_dnmtr_uomcd = source.strnt_dnmtr_uomcd
WHEN NOT MATCHED BY TARGET THEN
    INSERT $Columns
    VALUES (source.vpid, source.isid, source.basis_strntcd, source.bs_subid, source.strnt_nmrtr_val,
        source.strnt_nmrtr_uomcd, source.strnt_dnmtr_val, source.strnt_dnmtr_uomcd)
OUTPUT `$action AS MergeAction;
"@

        try {
            $actions = @(Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName `
                -TrustServerCertificate -Query $upsertSql -QueryTimeout 120 -ConnectionTimeout 30 -ErrorAction Stop)
            $batchInserted = @($actions | Where-Object { $_.MergeAction -eq "INSERT" }).Count
            $batchUpdated = @($actions | Where-Object { $_.MergeAction -eq "UPDATE" }).Count
            $inserted += $batchInserted
            $updated += $batchUpdated
            Write-Host "  Batch $batchNumber/$totalBatches complete ($end/$totalRecords records; inserted=$batchInserted, updated=$batchUpdated)"
        }
        catch { Write-Error "Failed to upsert batch $batchNumber`: $_"; throw }
    }

    return [PSCustomObject]@{
        Inserted = $inserted
        Updated  = $updated
    }
}

# ===== VMP Ingredients Import =====
Write-Host "`n===== VMP Ingredients Import =====" -ForegroundColor Cyan

$VmpFiles = Get-ChildItem -Path $XmlPath -Filter "f_vmp2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($VmpFiles.Count -eq 0) {
    Write-Error "VMP file not found in $XmlPath"
    exit 1
}

$VmpFile = $VmpFiles[0].FullName
Write-Host "Found VMP file: $VmpFile" -ForegroundColor Green

Write-Host "Loading VMP XML..."
[xml]$vmpXml = Get-Content $VmpFile

Write-Host "Checking VMP Ingredient schema..."
Ensure-VmpIngredientSchema

Write-Host "Processing VMP Ingredient records..."
$values = @()
$duplicatesSkipped = 0
$sourceKeys = @{}

foreach ($vpi in $vmpXml.VIRTUAL_MED_PRODUCTS.VIRTUAL_PRODUCT_INGREDIENT.VPI) {
    $vpid = [string]$vpi.VPID
    $isid = [string]$vpi.ISID
    $basis_strntcd = [string]$vpi.BASIS_STRNTCD
    
    if ([string]::IsNullOrWhiteSpace($vpid) -or [string]::IsNullOrWhiteSpace($isid)) { continue }
    
    # The database primary key is (vpid, isid). BASIS_STRNTCD and strength values
    # are mutable attributes and must not be used to decide record identity.
    $key = "$vpid|$isid"
    $fingerprint = @(
        $basis_strntcd,
        [string]$vpi.BS_SUBID,
        [string]$vpi.STRNT_NMRTR_VAL,
        [string]$vpi.STRNT_NMRTR_UOMCD,
        [string]$vpi.STRNT_DNMTR_VAL,
        [string]$vpi.STRNT_DNMTR_UOMCD
    ) -join '|'

    if ($sourceKeys.ContainsKey($key)) {
        if ($sourceKeys[$key] -ne $fingerprint) {
            throw "Conflicting duplicate VMP Ingredient key '$key' found in $VmpFile."
        }
        $duplicatesSkipped++
        continue
    }
    $sourceKeys[$key] = $fingerprint
    
    $bs_subid = Escape-SqlValue $vpi.BS_SUBID
    $strnt_nmrtr_val = Escape-SqlValue $vpi.STRNT_NMRTR_VAL
    $strnt_nmrtr_uomcd = Escape-SqlValue $vpi.STRNT_NMRTR_UOMCD
    $strnt_dnmtr_val = Escape-SqlValue $vpi.STRNT_DNMTR_VAL
    $strnt_dnmtr_uomcd = Escape-SqlValue $vpi.STRNT_DNMTR_UOMCD
    
    $values += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $isid),$(Escape-SqlValue $basis_strntcd),$bs_subid,$strnt_nmrtr_val,$strnt_nmrtr_uomcd,$strnt_dnmtr_val,$strnt_dnmtr_uomcd)"
}

Write-Host "  Processed $($values.Count) unique VMP Ingredient records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped identical duplicate VMP Ingredient records"
}

if ($values.Count -gt 0) {
    $columns = "(vpid,isid,basis_strntcd,bs_subid,strnt_nmrtr_val,strnt_nmrtr_uomcd,strnt_dnmtr_val,strnt_dnmtr_uomcd)"
    $upsertStats = Invoke-BatchedUpsert -TableName "vmp_ingredient" -Columns $columns -Values $values -BatchSize $BatchSize
    $unchanged = $values.Count - $upsertStats.Inserted - $upsertStats.Updated
    Write-Host "  Upsert summary: inserted=$($upsertStats.Inserted), updated=$($upsertStats.Updated), unchanged=$unchanged, duplicate XML rows=$duplicatesSkipped"
    Write-Host "`nVMP Ingredient import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM vmp_ingredient" -QueryTimeout 30
    Write-Host "Total VMP Ingredient records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new VMP Ingredient records to import."
}
