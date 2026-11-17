# PowerShell script to load PCD Refset Content into SQL Server
# v61+ format: reads from GPData_Cluster_Refset CSV in the SupportingProducts folder.
# The old 20260424_PCD_*.txt files no longer exist; the equivalent data is now
# shipped as GPData_Cluster_Refset_<moduleId>_<date>.csv inside the release ZIP.
#
# Only active rows (Active_in_Refset=1 AND Active_Code_Status=1) are imported.
# Bulk-copy is used for speed (127 k rows instead of row-by-row Invoke-Sqlcmd).

$server         = "SILENTPRIORY\SQLEXPRESS"
$database       = "SNOMEDCT"
$releaseRoot    = "C:\SNOMEDCT\CurrentReleases\uk_sct2pc_61.0.0_20260424000000Z"
$innerFolder    = "SnomedCT_UKPrimaryCareRF2_PRODUCTION_20260424T000000Z"
$supportingDir  = Join-Path $releaseRoot "$innerFolder\SupportingProducts"

# Locate the GPData CSV (name contains the release date and module ID)
$csvFile = Get-ChildItem $supportingDir -Filter "GPData_Cluster_Refset_*.csv" |
           Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName

if (-not $csvFile) {
    Write-Error "Could not find GPData_Cluster_Refset_*.csv in $supportingDir"
    exit 1
}
Write-Host "Source CSV : $csvFile"

# ── Helper: Invoke-Sqlcmd wrapper (always trust cert) ───────────────────────
function Invoke-Sql([string]$query, [int]$timeout = 120) {
    Invoke-Sqlcmd -ServerInstance $server -Database $database `
                  -TrustServerCertificate -Query $query `
                  -QueryTimeout $timeout -ErrorAction Stop
}

# ── Helper: SqlBulkCopy – much faster than row-by-row Invoke-Sqlcmd ─────────
function Invoke-BulkCopy([string]$tableName, [System.Data.DataTable]$dt) {
    $connStr = "Server=$server;Database=$database;Integrated Security=True;TrustServerCertificate=True"
    $conn    = New-Object System.Data.SqlClient.SqlConnection($connStr)
    $conn.Open()
    try {
        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
        $bulk.DestinationTableName = "dbo.$tableName"
        $bulk.BulkCopyTimeout      = 600
        $bulk.WriteToServer($dt)
        Write-Host "  Bulk-copied $($dt.Rows.Count) rows → [$tableName]"
    } finally {
        $conn.Close()
    }
}

# ── Load and filter CSV ──────────────────────────────────────────────────────
Write-Host "Reading CSV..."
$allRows = Import-Csv $csvFile
Write-Host "  Total rows : $($allRows.Count)"

$active = $allRows | Where-Object { $_.Active_in_Refset -eq '1' -and $_.Active_Code_Status -eq '1' }
Write-Host "  Active rows: $($active.Count)  (Active_in_Refset=1 AND Active_Code_Status=1)"

# Column mapping (old name → new CSV column):
#   Cluster_ID          ← Cluster_ID
#   Cluster_Description ← Cluster_Desc
#   SNOMED_code         ← ConceptId
#   SNOMED_code_desc    ← ConceptId_Description
#   PCD_Refset_ID       ← RefsetId
#   Service_and_Ruleset ← Type_of_Inclusion  (closest equivalent; was Output/Ruleset label)

# ════════════════════════════════════════════════════════════════════════════
# TABLE 1 : PCD_Refset_Content_V2
# ════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "── PCD_Refset_Content_V2 ────────────────────────────────────────"

Invoke-Sql @"
IF OBJECT_ID('dbo.PCD_Refset_Content_V2','U') IS NOT NULL
BEGIN TRUNCATE TABLE PCD_Refset_Content_V2; DROP TABLE PCD_Refset_Content_V2; END

CREATE TABLE PCD_Refset_Content_V2 (
    Cluster_ID               VARCHAR(50)  NOT NULL,
    Cluster_Description      VARCHAR(500) NOT NULL,
    SNOMED_code              VARCHAR(255) NOT NULL,
    SNOMED_code_description  VARCHAR(500) NOT NULL,
    PCD_Refset_ID            VARCHAR(18)  NOT NULL,
    Service_and_Ruleset      VARCHAR(500) NOT NULL
);
CREATE INDEX IX_PCD_V2_Cluster      ON PCD_Refset_Content_V2(Cluster_ID);
CREATE INDEX IX_PCD_V2_SNOMED       ON PCD_Refset_Content_V2(SNOMED_code);
CREATE INDEX IX_PCD_V2_RefsetID     ON PCD_Refset_Content_V2(PCD_Refset_ID);
"@

$dtV2 = New-Object System.Data.DataTable
foreach ($col in @('Cluster_ID','Cluster_Description','SNOMED_code','SNOMED_code_description','PCD_Refset_ID','Service_and_Ruleset')) {
    $dtV2.Columns.Add($col) | Out-Null
}
foreach ($row in $active) {
    $dtV2.Rows.Add(
        $row.Cluster_ID,
        $row.Cluster_Desc,
        $row.ConceptId,
        $row.ConceptId_Description,
        $row.RefsetId,
        $row.Type_of_Inclusion
    ) | Out-Null
}
Invoke-BulkCopy "PCD_Refset_Content_V2" $dtV2

# Spot-check
$r = Invoke-Sql "SELECT COUNT(*) AS N, COUNT(DISTINCT PCD_Refset_ID) AS Refsets, COUNT(DISTINCT Cluster_ID) AS Clusters FROM PCD_Refset_Content_V2"
Write-Host "  Rows=$($r.N)  Refsets=$($r.Refsets)  Clusters=$($r.Clusters)"

# ════════════════════════════════════════════════════════════════════════════
# TABLE 2 : PCD_Refset_Content_by_Output
# The new CSV has no Output_ID column; Cluster_Category is used as the
# nearest equivalent (it groups clusters into extract categories).
# ════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "── PCD_Refset_Content_by_Output ─────────────────────────────────"

Invoke-Sql @"
IF OBJECT_ID('dbo.PCD_Refset_Content_by_Output','U') IS NOT NULL
BEGIN TRUNCATE TABLE PCD_Refset_Content_by_Output; DROP TABLE PCD_Refset_Content_by_Output; END

CREATE TABLE PCD_Refset_Content_by_Output (
    Output_ID                VARCHAR(255) NOT NULL,
    Cluster_ID               VARCHAR(255) NOT NULL,
    Cluster_Description      VARCHAR(255) NOT NULL,
    SNOMED_code              VARCHAR(255) NOT NULL,
    SNOMED_code_description  VARCHAR(255) NOT NULL,
    PCD_Refset_ID            VARCHAR(18)  NOT NULL
);
CREATE INDEX IX_PCD_Out_Cluster  ON PCD_Refset_Content_by_Output(Cluster_ID);
CREATE INDEX IX_PCD_Out_SNOMED   ON PCD_Refset_Content_by_Output(SNOMED_code);
CREATE INDEX IX_PCD_Out_RefsetID ON PCD_Refset_Content_by_Output(PCD_Refset_ID);
"@

$dtOut = New-Object System.Data.DataTable
foreach ($col in @('Output_ID','Cluster_ID','Cluster_Description','SNOMED_code','SNOMED_code_description','PCD_Refset_ID')) {
    $dtOut.Columns.Add($col) | Out-Null
}
foreach ($row in $active) {
    $dtOut.Rows.Add(
        $row.Cluster_Category,
        $row.Cluster_ID,
        $row.Cluster_Desc,
        $row.ConceptId,
        $row.ConceptId_Description,
        $row.RefsetId
    ) | Out-Null
}
Invoke-BulkCopy "PCD_Refset_Content_by_Output" $dtOut

$r2 = Invoke-Sql "SELECT COUNT(*) AS N FROM PCD_Refset_Content_by_Output"
Write-Host "  Rows=$($r2.N)"

# ════════════════════════════════════════════════════════════════════════════
# TABLES 3-5 : Ruleset / Service / Output-Description mappings
# These were separate NHSBSA flat files that are no longer distributed in
# the RF2 release ZIP.  The tables are recreated empty so existing queries
# do not break.  Reload from a separate NHSBSA download if available.
# ════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "── PCD_Ruleset_Full_Name_Mappings_V2 (empty – no v61 source) ────"

Invoke-Sql @"
IF OBJECT_ID('dbo.PCD_Ruleset_Full_Name_Mappings_V2','U') IS NOT NULL
BEGIN TRUNCATE TABLE PCD_Ruleset_Full_Name_Mappings_V2; DROP TABLE PCD_Ruleset_Full_Name_Mappings_V2; END
CREATE TABLE PCD_Ruleset_Full_Name_Mappings_V2 (
    Ruleset_ID         VARCHAR(50)  NOT NULL,
    Ruleset_Short_Name VARCHAR(255) NOT NULL,
    Ruleset_Full_Name  VARCHAR(500) NOT NULL
);
CREATE INDEX IX_PCD_Ruleset_ID ON PCD_Ruleset_Full_Name_Mappings_V2(Ruleset_ID);
"@
Write-Host "  Table recreated (0 rows – no equivalent file in v61 ZIP)"

Write-Host ""
Write-Host "── PCD_Service_Full_Name_Mappings_V2 (empty – no v61 source) ────"

Invoke-Sql @"
IF OBJECT_ID('dbo.PCD_Service_Full_Name_Mappings_V2','U') IS NOT NULL
BEGIN TRUNCATE TABLE PCD_Service_Full_Name_Mappings_V2; DROP TABLE PCD_Service_Full_Name_Mappings_V2; END
CREATE TABLE PCD_Service_Full_Name_Mappings_V2 (
    Service_ID         VARCHAR(50)  NOT NULL,
    Service_Short_Name VARCHAR(255) NOT NULL,
    Service_Full_Name  VARCHAR(500) NOT NULL
);
CREATE INDEX IX_PCD_Service_ID ON PCD_Service_Full_Name_Mappings_V2(Service_ID);
"@
Write-Host "  Table recreated (0 rows – no equivalent file in v61 ZIP)"

Write-Host ""
Write-Host "── PCD_Output_Descriptions_V2 (empty – no v61 source) ──────────"

Invoke-Sql @"
IF OBJECT_ID('dbo.PCD_Output_Descriptions_V2','U') IS NOT NULL
BEGIN TRUNCATE TABLE PCD_Output_Descriptions_V2; DROP TABLE PCD_Output_Descriptions_V2; END
CREATE TABLE PCD_Output_Descriptions_V2 (
    Service_ID         VARCHAR(50)   NOT NULL,
    Ruleset_ID         VARCHAR(255)  NOT NULL,
    Output_ID          VARCHAR(50)   NOT NULL,
    Output_Description VARCHAR(2000) NOT NULL,
    Output_Type        VARCHAR(10)   NOT NULL
);
CREATE INDEX IX_PCD_OutDesc_Service ON PCD_Output_Descriptions_V2(Service_ID);
CREATE INDEX IX_PCD_OutDesc_Ruleset ON PCD_Output_Descriptions_V2(Ruleset_ID);
CREATE INDEX IX_PCD_OutDesc_Output  ON PCD_Output_Descriptions_V2(Output_ID);
"@
Write-Host "  Table recreated (0 rows – no equivalent file in v61 ZIP)"

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════"
Write-Host "All PCD tables loaded successfully from v61 release."
Write-Host "════════════════════════════════════════════════════════════"
