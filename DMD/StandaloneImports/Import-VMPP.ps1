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
    if ($type -eq "decimal" -or $type -eq "numeric") {
        return $value
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
    param(
        [string]$TableName,
        [string]$KeyColumn
    )
    
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

# ===== VMPP Import =====
Write-Host "`n===== VMPP (Virtual Medicinal Product Packs) Import =====" -ForegroundColor Cyan

$VmppFiles = Get-ChildItem -Path $XmlPath -Filter "f_vmpp2_*.xml" -Recurse -ErrorAction SilentlyContinue
if ($VmppFiles.Count -eq 0) {
    Write-Error "VMPP file not found in $XmlPath"
    exit 1
}

$VmppFile = $VmppFiles[0].FullName
Write-Host "Found VMPP file: $VmppFile" -ForegroundColor Green

Write-Host "Loading VMPP XML..."
[xml]$vmppXml = Get-Content $VmppFile

Write-Host "Checking for existing VMPP records..."
$existingVmpp = Get-ExistingKeys -TableName "vmpp" -KeyColumn "vppid"
Write-Host "  Found $($existingVmpp.Count) existing VMPP records"

Write-Host "Processing VMPP records..."
$vmppValues = @()
$duplicatesSkipped = 0

foreach ($vmpp in $vmppXml.VIRTUAL_MED_PRODUCT_PACK.VMPPS.VMPP) {
    $vppid = [string]$vmpp.VPPID
    
    if ($existingVmpp.ContainsKey($vppid)) {
        $duplicatesSkipped++
        continue
    }
    
    $invalid = if ($vmpp.INVALID) { '1' } else { '0' }
    $nm = [string]$vmpp.NM
    $vpid = [string]$vmpp.VPID
    $qtyval = Escape-SqlValue $vmpp.QTYVAL -type "decimal"
    $qty_uomcd = Escape-SqlValue $vmpp.QTY_UOMCD
    $combpackcd = Escape-SqlValue $vmpp.COMBPACKCD
    
    $vmppValues += "($(Escape-SqlValue $vppid),$invalid,$(Escape-SqlValue $nm),$(Escape-SqlValue $vpid),$qtyval,$qty_uomcd,$combpackcd)"
}

Write-Host "  Processed $($vmppValues.Count) unique VMPP records"
if ($duplicatesSkipped -gt 0) {
    Write-Host "  Skipped $duplicatesSkipped duplicate VMPP records"
}

if ($vmppValues.Count -gt 0) {
    $columns = "(vppid,invalid,nm,vpid,qtyval,qty_uomcd,combpackcd)"
    Invoke-BatchedInsert -TableName "vmpp" -Columns $columns -Values $vmppValues -BatchSize $BatchSize
    Write-Host "`nVMPP import complete!" -ForegroundColor Green
    
    $finalCount = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT COUNT(*) as cnt FROM vmpp" -QueryTimeout 30
    Write-Host "Total VMPP records in database: $($finalCount.cnt)" -ForegroundColor Green
} else {
    Write-Warning "No new VMPP records to import."
}
