<#
.SYNOPSIS
    Export resolved SNOMED codelists for each QOF cluster CSV.

.DESCRIPTION
    For each *.clusters.csv file in -SourceDir, builds an in-memory T-SQL
    DECLARE/INSERT/SELECT (mirroring Queries\GetCodesAllclusters.sql) that
    joins the cluster IDs to PCD_Refset_Content_V2 in the SNOMEDCT database,
    and writes one resolved-codes CSV per source file to -OutputDir.

.EXAMPLE
    .\Export-QOFCodelists.ps1
#>

[CmdletBinding()]
param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database       = "SNOMEDCT",
    [string]$SourceDir      = "O:\GitHub\ConsultationTemplates\QOF\QOF 2026_27_CodeClusters",
    [string]$OutputDir      = "O:\GitHub\ConsultationTemplates\QOF\QOFCodelists 2026_27"
)

$ErrorActionPreference = 'Stop'

Import-Module SqlServer -ErrorAction Stop

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "SourceDir not found: $SourceDir"
}
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

function Escape-SqlString {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace("'", "''")
}

function Build-Query {
    param([object[]]$Rows)

    $valueLines = foreach ($r in $Rows) {
        $cid  = Escape-SqlString $r.Cluster_ID
        $desc = Escape-SqlString $r.Cluster_Description
        $rid  = Escape-SqlString $r.PCD_Refset_ID
        "    ('$cid','$desc','$rid')"
    }
    $valuesBlock = ($valueLines -join ",`r`n")

    # Two-pass lookup:
    #   1. PCD_Refset_Content_V2 (primary care domain clusters)
    #   2. curr_simplerefset_f   (UK Drug Extension / other SNOMED simple refsets)
    #      - only for clusters that returned NO rows from pass 1.
    #      - PCD_Refset_ID matches refsetid in curr_simplerefset_f.
    #      - Description preferred-term sourced from curr_description_f (typeid 900000000000013009).
    @"
SET NOCOUNT ON;

DECLARE @ClusterList TABLE (
    Cluster_ID           NVARCHAR(50),
    Cluster_Description  NVARCHAR(300),
    PCD_Refset_ID        NVARCHAR(50)
);

INSERT INTO @ClusterList (Cluster_ID, Cluster_Description, PCD_Refset_ID)
VALUES
$valuesBlock;

-- Pass 1: PCD refset content
WITH PCDHits AS (
    SELECT
        cl.Cluster_ID,
        cl.Cluster_Description,
        CAST(prc.SNOMED_code AS NVARCHAR(50))             AS SNOMED_code,
        CAST(prc.SNOMED_code_description AS NVARCHAR(500)) AS SNOMED_code_description,
        'PCD_Refset_Content_V2'                            AS Source
    FROM @ClusterList cl
    JOIN PCD_Refset_Content_V2 prc
        ON prc.Cluster_ID = cl.Cluster_ID
),
ClustersWithHits AS (
    SELECT DISTINCT Cluster_ID FROM PCDHits
),
-- Pass 2: SNOMED simple refset fallback (Drug Extension etc.) for clusters missed by pass 1
DrugHits AS (
    SELECT
        cl.Cluster_ID,
        cl.Cluster_Description,
        CAST(s.referencedcomponentid AS NVARCHAR(50)) AS SNOMED_code,
        CAST(pt.term AS NVARCHAR(500))                AS SNOMED_code_description,
        'curr_simplerefset_f'                         AS Source
    FROM @ClusterList cl
    JOIN curr_simplerefset_f s
        ON s.refsetid = cl.PCD_Refset_ID
       AND s.active   = '1'
    LEFT JOIN curr_description_f pt
        ON pt.conceptid = s.referencedcomponentid
       AND pt.typeid    = '900000000000013009'  -- Preferred term
       AND pt.active    = '1'
    WHERE cl.Cluster_ID NOT IN (SELECT Cluster_ID FROM ClustersWithHits)
)
SELECT Cluster_ID, Cluster_Description, SNOMED_code, SNOMED_code_description, Source FROM PCDHits
UNION ALL
SELECT Cluster_ID, Cluster_Description, SNOMED_code, SNOMED_code_description, Source FROM DrugHits
ORDER BY Cluster_ID, SNOMED_code;
"@
}

$files = Get-ChildItem -LiteralPath $SourceDir -Filter '*.clusters.csv' -File |
         Sort-Object Name

Write-Host "Found $($files.Count) cluster CSV file(s) in $SourceDir" -ForegroundColor Cyan
Write-Host "Server : $ServerInstance"
Write-Host "DB     : $Database"
Write-Host "Output : $OutputDir"
Write-Host ""

$summary = @()

foreach ($file in $files) {
    $base = $file.Name -replace '\.clusters\.csv$', ''
    $outPath = Join-Path $OutputDir "$base.codelist.csv"

    Write-Host "[$($file.Name)]" -ForegroundColor Yellow

    $rows = Import-Csv -LiteralPath $file.FullName
    if (-not $rows -or $rows.Count -eq 0) {
        Write-Warning "  Source has no rows; skipping."
        $summary += [pscustomobject]@{ File=$file.Name; Clusters=0; Codes=0; Output='(skipped)' }
        continue
    }

    Write-Host ("  Clusters in source : {0}" -f $rows.Count)

    $query = Build-Query -Rows $rows

    try {
        $results = Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database $Database `
            -Query $query `
            -TrustServerCertificate `
            -QueryTimeout 120 `
            -ErrorAction Stop
    }
    catch {
        Write-Error "  SQL execution failed for $($file.Name): $($_.Exception.Message)"
        $summary += [pscustomobject]@{ File=$file.Name; Clusters=$rows.Count; Codes='ERROR'; Output='(failed)' }
        continue
    }

    $codeCount = if ($null -eq $results) { 0 } elseif ($results -is [array]) { $results.Count } else { 1 }

    if ($codeCount -eq 0) {
        Write-Warning "  Query returned 0 rows."
        # Still write an empty CSV with headers for traceability.
        '"Cluster_ID","Cluster_Description","SNOMED_code","SNOMED_code_description","Source"' |
            Out-File -LiteralPath $outPath -Encoding UTF8
    }
    else {
        $results |
            Select-Object Cluster_ID, Cluster_Description, SNOMED_code, SNOMED_code_description, Source |
            Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8
    }

    Write-Host ("  Codes returned     : {0}" -f $codeCount)
    Write-Host ("  Wrote              : {0}" -f $outPath) -ForegroundColor Green

    # Identify clusters in the source CSV that returned no codes.
    if ($codeCount -gt 0) {
        $returnedIds = $results | Select-Object -ExpandProperty Cluster_ID -Unique
        $missing = $rows | Where-Object { $returnedIds -notcontains $_.Cluster_ID } |
                   Select-Object -ExpandProperty Cluster_ID
        if ($missing) {
            Write-Warning ("  Clusters with no codes: {0}" -f ($missing -join ', '))
        }
    }

    $summary += [pscustomobject]@{
        File     = $file.Name
        Clusters = $rows.Count
        Codes    = $codeCount
        Output   = (Split-Path $outPath -Leaf)
    }
}

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
