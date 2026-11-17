param(
    [Parameter(Mandatory = $true)][string]$XmlPath,
    [string]$ServerInstance = 'SILENTPRIORY\SQLEXPRESS',
    [string]$DatabaseName = 'dmd'
)

$ErrorActionPreference = 'Stop'
$dmdDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $dmdDir 'PackPriceSupport.ps1')

# Read and validate both sources before opening a transaction or changing tables.
$sources = @(Get-DmdPackPriceSource -XmlPath $XmlPath)
$connection = New-DmdPriceConnection $ServerInstance $DatabaseName
$transaction = $null
try {
    $transaction = $connection.BeginTransaction([System.Data.IsolationLevel]::Serializable)
    $schema = [System.IO.File]::ReadAllText((Join-Path $dmdDir 'Ensure-PackPriceSchema.sql'))
    Invoke-DmdPriceSql $connection $schema $transaction
    foreach ($source in $sources) { Add-DmdPriceStage $connection $source $transaction }
    foreach ($source in $sources) {
        $table = $source.Table
        $key = $source.Key
        $columns = $source.Columns -join ', '
        $assignments = ($source.Columns | Where-Object { $_ -ne $key } | ForEach-Object { "t.$_ = s.$_" }) -join ', '
        $selected = ($source.Columns | ForEach-Object { "s.$_" }) -join ', '
        # Full release snapshot: refresh existing prices, add new ones and remove
        # withdrawn pricing records. Parent product/pack tables are not changed.
        Invoke-DmdPriceSql $connection @"
UPDATE t SET $assignments FROM dbo.$table t JOIN #$table s ON s.$key = t.$key;
INSERT INTO dbo.$table ($columns)
SELECT $selected FROM #$table s WHERE NOT EXISTS (SELECT 1 FROM dbo.$table t WHERE t.$key = s.$key);
DELETE t FROM dbo.$table t WHERE NOT EXISTS (SELECT 1 FROM #$table s WHERE s.$key = t.$key);
"@ $transaction
        Assert-DmdPriceMatch $connection $source $transaction
    }
    $transaction.Commit()
    $transaction = $null
    foreach ($source in $sources) {
        Write-Host "$($source.Table): $($source.Data.Rows.Count) rows imported and all fields verified against XML." -ForegroundColor Green
    }
} catch {
    if ($null -ne $transaction) { $transaction.Rollback() }
    throw
} finally {
    $connection.Dispose()
    foreach ($source in $sources) { $source.Data.Dispose() }
}
