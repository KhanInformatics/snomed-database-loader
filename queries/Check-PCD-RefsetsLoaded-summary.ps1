$csvPath = Resolve-Path .\Check-PCD-RefsetsLoaded-$(Get-Date -Format yyyyMMdd).csv
$csv = Import-Csv $csvPath
$total = $csv.Count
$inpcd = ($csv | Where-Object { $_.In_PCD -eq '1' }).Count
$insimple = ($csv | Where-Object { $_.In_Simple -eq '1' }).Count
$both = ($csv | Where-Object { $_.In_PCD -eq '1' -and $_.In_Simple -eq '1' }).Count
$missing = ($csv | Where-Object { $_.In_PCD -eq '0' -and $_.In_Simple -eq '0' }).Count
Write-Host "Total=$total, In_PCD=$inpcd, In_Simple=$insimple, Both=$both, Missing=$missing"
if ($missing -gt 0) {
    Write-Host "Missing IDs:"
    $csv | Where-Object { $_.In_PCD -eq '0' -and $_.In_Simple -eq '0' } | Select-Object -ExpandProperty PCD_Refset_ID | ForEach-Object { Write-Host "  $_" }
}
