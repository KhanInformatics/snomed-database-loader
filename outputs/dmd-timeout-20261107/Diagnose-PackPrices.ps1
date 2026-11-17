$ErrorActionPreference = 'Stop'
$repo = 'O:\GitHub\snomed-database-loader'
. (Join-Path $repo 'DMD\PackPriceSupport.ps1')
function Invoke-DmdPriceSql {
    param($Connection, [string]$Sql, $Transaction = $null, [switch]$Scalar,
        [string]$Operation = 'SQL statement')
    $command = $Connection.CreateCommand()
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $phase = $Operation
    Write-Host "Starting SQL: $phase"
    try {
        $command.CommandText = $Sql
        $command.CommandTimeout = 30
        $command.Transaction = $Transaction
        if ($Scalar) { return $command.ExecuteScalar() }
        [void]$command.ExecuteNonQuery()
    } catch {
        $Sql | Set-Content (Join-Path $PSScriptRoot 'failed-query.sql')
        throw
    } finally {
        Write-Host "$phase completed/stopped after $([math]::Round($timer.Elapsed.TotalSeconds, 2)) seconds"
        $command.Dispose()
    }
}
$timer = [Diagnostics.Stopwatch]::StartNew()
Write-Host 'Parsing downloaded 2 November release'
$sources = @(Get-DmdPackPriceSource -XmlPath 'C:\DMD\CurrentReleases\nhsbsa_dmd_11.0.0_20261102000001')
Write-Host "Parsed in $([math]::Round($timer.Elapsed.TotalSeconds, 2)) seconds"
$connection = New-DmdPriceConnection 'SILENTPRIORY\SQLEXPRESS' 'dmd'
try {
    foreach ($source in $sources) {
        Write-Host "$($source.Table): $($source.Data.Rows.Count) XML records"
        Add-DmdPriceStage $connection $source
        Assert-DmdPriceMatch $connection $source
    }
} finally {
    $connection.Dispose()
    foreach ($source in $sources) { $source.Data.Dispose() }
}
