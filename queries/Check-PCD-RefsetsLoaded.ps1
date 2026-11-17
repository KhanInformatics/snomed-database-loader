<#
Checks which PCD refset IDs from the QOF cluster CSV files exist in the
SNOMEDCT database (either in PCD_Refset_Content_V2 or curr_simplerefset_f).

Outputs a CSV summary to the current folder: Check-PCD-RefsetsLoaded-YYYYMMDD.csv
#>
[CmdletBinding()]
param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database       = "SNOMEDCT",
    [string]$SourceDir      = "O:\GitHub\ConsultationTemplates\QOF\QOF 2026_27_CodeClusters",
    [string]$OutFileDir     = "."
)

Import-Module SqlServer -ErrorAction Stop

$files = Get-ChildItem -LiteralPath $SourceDir -Filter '*.clusters.csv' -File
if ($files.Count -eq 0) { Write-Error "No cluster CSVs found in $SourceDir"; exit 1 }

$refsetIds = @()
foreach ($f in $files) {
    $rows = Import-Csv -LiteralPath $f.FullName -ErrorAction Stop
    foreach ($r in $rows) {
        if ($r.PCD_Refset_ID -and $r.PCD_Refset_ID.Trim() -ne '') {
            $refsetIds += $r.PCD_Refset_ID.Trim()
        }
    }
}
$refsetIds = $refsetIds | Select-Object -Unique | Sort-Object

Write-Host "Found $($refsetIds.Count) unique PCD_Refset_IDs from source CSVs" -ForegroundColor Cyan

$results = @()
foreach ($rid in $refsetIds) {
    $escaped = $rid.Replace("'","''")
    $query = @"
SET NOCOUNT ON;
SELECT
    (CASE WHEN EXISTS(SELECT 1 FROM PCD_Refset_Content_V2 WHERE PCD_Refset_ID = '$escaped') THEN 1 ELSE 0 END) AS In_PCD,
    (CASE WHEN EXISTS(SELECT 1 FROM curr_simplerefset_f WHERE refsetid = '$escaped') THEN 1 ELSE 0 END) AS In_Simple
"@
    try {
        $r = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query -TrustServerCertificate -ErrorAction Stop
    }
    catch {
        Write-Error ("SQL query failed for {0}: {1}" -f $rid, $_.Exception.Message)
        $results += [pscustomobject]@{ PCD_Refset_ID=$rid; In_PCD='ERROR'; In_Simple='ERROR' }
        continue
    }
    $results += [pscustomobject]@{ PCD_Refset_ID=$rid; In_PCD = $r.In_PCD; In_Simple = $r.In_Simple }
}

$outName = "Check-PCD-RefsetsLoaded-$(Get-Date -Format yyyyMMdd).csv"
$outPath = Join-Path $OutFileDir $outName
$results | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host "Wrote summary to: $outPath" -ForegroundColor Green

# Also print concise summary of missing IDs
$missing = $results | Where-Object { $_.In_PCD -eq 0 -and $_.In_Simple -eq 0 }
if ($missing.Count -eq 0) {
    Write-Host "All refset IDs are present in at least one table." -ForegroundColor Green
} else {
    Write-Warning "The following refset IDs are missing from both PCD_Refset_Content_V2 and curr_simplerefset_f:"
    $missing | ForEach-Object { Write-Host "  $_.PCD_Refset_ID" }
}

# Exit with non-zero if any missing
if ($missing.Count -gt 0) { exit 2 } else { exit 0 }
