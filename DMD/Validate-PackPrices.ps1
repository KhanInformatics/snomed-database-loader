param(
    [Parameter(Mandatory = $true)][string]$XmlPath,
    [string]$ServerInstance = 'SILENTPRIORY\SQLEXPRESS',
    [string]$Database = 'dmd'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PackPriceSupport.ps1')
$sources = @(Get-DmdPackPriceSource -XmlPath $XmlPath)
$connection = New-DmdPriceConnection $ServerInstance $Database
try {
    foreach ($source in $sources) {
        # Only session-local temporary tables are written by validation.
        Add-DmdPriceStage $connection $source
        Assert-DmdPriceMatch $connection $source
        [pscustomobject]@{
            Table = $source.Table
            Rows = $source.Data.Rows.Count
            Status = 'PASSED'
            SourceFile = $source.SourceFile
        }
    }
} finally {
    $connection.Dispose()
    foreach ($source in $sources) { $source.Data.Dispose() }
}
