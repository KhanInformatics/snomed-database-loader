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

function Convert-BoolFlag {
    param([string]$value)
    if ($value -eq '1') { return '1' }
    return '0'
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

# ===== VMP Import =====
Write-Host "`n===== VMP (Virtual Medicinal Product) Import =====" -ForegroundColor Cyan

# Find VMP file
$VmpFiles = Get-ChildItem -Path $XmlPath -Filter "f_vmp2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($VmpFiles.Count -eq 0) {
    Write-Error "VMP file not found in $XmlPath"
    exit 1
}

$VmpFile = $VmpFiles[0].FullName
Write-Host "Found VMP file: $VmpFile" -ForegroundColor Green

Write-Host "Loading VMP XML..."
[xml]$vmpXml = Get-Content $VmpFile

Write-Host "Checking for existing VMP records..."
$existingKeys = Get-ExistingKeys -TableName "vmp" -KeyColumns @("vpid")
Write-Host "  Found $($existingKeys.Count) existing VMP records"

Write-Host "Processing VMP records..."
$values = @()
$duplicatesSkipped = 0

foreach ($vmp in $vmpXml.VIRTUAL_MED_PRODUCTS.VMPS.VMP) {
    $vpid = [string]$vmp.VPID
    $vpiddt = [string]$vmp.VPIDDT
    $vpidprev = [string]$vmp.VPIDPREV
    $vtmid = [string]$vmp.VTMID
    $invalid = if ([string]::IsNullOrWhiteSpace($vmp.INVALID)) { "0" } else { [string]$vmp.INVALID }
    $nm = [string]$vmp.NM
    $abbrevnm = [string]$vmp.ABBREVNM
    $basiscd = [string]$vmp.BASISCD
    $nmdt = [string]$vmp.NMDT
    $nmprev = [string]$vmp.NMPREV
    $basis_prevcd = [string]$vmp.BASIS_PREVCD
    $nmchangecd = [string]$vmp.NMCHANGECD
    $comprodcd = [string]$vmp.COMPRODCD
    $pres_statcd = [string]$vmp.PRES_STATCD
    $sug_f = Convert-BoolFlag $vmp.SUG_F
    $glu_f = Convert-BoolFlag $vmp.GLU_F
    $pres_f = Convert-BoolFlag $vmp.PRES_F
    $cfc_f = Convert-BoolFlag $vmp.CFC_F
    $non_availcd = [string]$vmp.NON_AVAILCD
    $non_availdt = [string]$vmp.NON_AVAILDT
    $df_indcd = [string]$vmp.DF_INDCD
    $udfs = [string]$vmp.UDFS
    $udfs_uomcd = [string]$vmp.UDFS_UOMCD
    $unit_dose_uomcd = [string]$vmp.UNIT_DOSE_UOMCD
    
    if ([string]::IsNullOrWhiteSpace($vpid)) { continue }
    
    $key = $vpid
    if ($existingKeys.ContainsKey($key)) {
        $duplicatesSkipped++
        continue
    }
    
    $values += "($(Escape-SqlValue $vpid),$(Escape-SqlValue $vpiddt),$(Escape-SqlValue $vpidprev),$(Escape-SqlValue $vtmid),$invalid,$(Escape-SqlValue $nm),$(Escape-SqlValue $abbrevnm),$(Escape-SqlValue $basiscd),$(Escape-SqlValue $nmdt),$(Escape-SqlValue $nmprev),$(Escape-SqlValue $basis_prevcd),$(Escape-SqlValue $nmchangecd),$(Escape-SqlValue $comprodcd),$(Escape-SqlValue $pres_statcd),$sug_f,$glu_f,$pres_f,$cfc_f,$(Escape-SqlValue $non_availcd),$(Escape-SqlValue $non_availdt),$(Escape-SqlValue $df_indcd),$(Escape-SqlValue $udfs),$(Escape-SqlValue $udfs_uomcd),$(Escape-SqlValue $unit_dose_uomcd))"
    $existingKeys[$key] = $true
}

Write-Host "  Processed $($values.Count) unique VMP records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate VMP records"
}

if ($values.Count -gt 0) {
    $columns = "(vpid,vpiddt,vpidprev,vtmid,invalid,nm,abbrevnm,basiscd,nmdt,nmprev,basis_prevcd,nmchangecd,comprodcd,pres_statcd,sug_f,glu_f,pres_f,cfc_f,non_availcd,non_availdt,df_indcd,udfs,udfs_uomcd,unit_dose_uomcd)"
    Invoke-BatchedInsert -TableName "vmp" -Columns $columns -Values $values -BatchSize $BatchSize
    Write-Host "`nVMP import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM vmp" -QueryTimeout 30
    Write-Host "Total VMP records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new VMP records to import."
}
