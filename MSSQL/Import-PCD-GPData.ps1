<#
.SYNOPSIS
    Loads a current Primary Care Domain cluster/refset supporting product losslessly.

.DESCRIPTION
    Discovers the latest timestamped uk_sct2pc release, validates the complete
    14-column GPData or GDPPR CSV, bulk-loads a uniquely named staging table,
    verifies the staged rows value-for-value, and atomically replaces the
    product-specific canonical table.

    The legacy PCD_* projection tables are deliberately not modified. Their
    Output_ID and service/ruleset semantics are not equivalent to the current
    GPData Cluster_Category and Type_of_Inclusion fields.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$DatabaseName = "PCD",
    [string]$ReleasesPath = "C:\SNOMEDCT\CurrentReleases",
    [string]$CsvPath,
    [ValidateSet("GPData", "GDPPR")]
    [string]$ProductCode = "GPData",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$targetTableName = "PCD_${ProductCode}_Cluster_Refset"

$sourceColumns = @(
    "Cluster_Category",
    "Cluster_ID",
    "Cluster_Desc",
    "Active_in_Refset",
    "Refset_Status_Date",
    "RefsetId",
    "Refset_Description",
    "ConceptId",
    "ConceptId_Description",
    "Active_Code_Status",
    "Code_Status_Date",
    "Type_of_Inclusion",
    "Sensitive_Status",
    "Sensitive_Status_Date"
)

$textLimits = @{
    Cluster_Category      = 128
    Cluster_ID            = 64
    Cluster_Desc          = 1000
    Refset_Status_Date    = 8
    RefsetId              = 18
    Refset_Description    = 1000
    ConceptId             = 18
    ConceptId_Description = 1000
    Code_Status_Date      = 8
    Type_of_Inclusion     = 64
    Sensitive_Status_Date = 8
}

function ConvertTo-SqlText {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return "" }
    return ([string]$Value).Replace("'", "''")
}

function ConvertTo-FlagText {
    param([AllowNull()][object]$Value)

    if ($Value -is [bool]) {
        return $(if ($Value) { "1" } else { "0" })
    }

    $text = [string]$Value
    if ($text -eq "1" -or $text -eq "True") { return "1" }
    if ($text -eq "0" -or $text -eq "False") { return "0" }
    throw "Invalid Boolean flag value '$text'"
}

function Get-PcdCsvEncoding {
    param([Parameter(Mandatory = $true)][string]$Path)

    # Releases have historically used Windows-1252 without a BOM. Prefer
    # strict UTF-8 when it is genuinely valid, then fall back explicitly to
    # Windows-1252 so accented clinical terms are never replaced with U+FFFD.
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.StreamReader]::new($stream, $strictUtf8, $true, 65536, $true)
        try {
            $buffer = [char[]]::new(65536)
            while ($reader.Read($buffer, 0, $buffer.Length) -gt 0) { }
            return $strictUtf8
        } finally {
            $reader.Dispose()
        }
    } catch [System.Text.DecoderFallbackException] {
        return [System.Text.Encoding]::GetEncoding(1252)
    } finally {
        $stream.Dispose()
    }
}

function Get-CanonicalRow {
    param(
        [Parameter(Mandatory = $true)][object]$Row,
        [Parameter(Mandatory = $true)][char]$Separator
    )

    return @(
        [string]$Row.Cluster_Category,
        [string]$Row.Cluster_ID,
        [string]$Row.Cluster_Desc,
        (ConvertTo-FlagText $Row.Active_in_Refset),
        [string]$Row.Refset_Status_Date,
        [string]$Row.RefsetId,
        [string]$Row.Refset_Description,
        [string]$Row.ConceptId,
        [string]$Row.ConceptId_Description,
        (ConvertTo-FlagText $Row.Active_Code_Status),
        [string]$Row.Code_Status_Date,
        [string]$Row.Type_of_Inclusion,
        (ConvertTo-FlagText $Row.Sensitive_Status),
        [string]$Row.Sensitive_Status_Date
    ) -join $Separator
}

function Invoke-PcdSql {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [int]$QueryTimeout = 180
    )

    return Invoke-Sqlcmd -ServerInstance $ServerInstance `
        -Database $DatabaseName `
        -TrustServerCertificate `
        -Query $Query `
        -QueryTimeout $QueryTimeout `
        -ErrorAction Stop
}

function Test-PcdTableMatchesSource {
    param(
        [Parameter(Mandatory = $true)][string]$TableName,
        [Parameter(Mandatory = $true)][System.Collections.Generic.HashSet[string]]$SourceRows,
        [Parameter(Mandatory = $true)][int]$ExpectedCount,
        [Parameter(Mandatory = $true)][char]$Separator
    )

    if ($TableName -notmatch '^PCD_(GPData|GDPPR)_[A-Za-z0-9_]+$') {
        throw "Unsafe GPData table name: $TableName"
    }

    $exists = Invoke-PcdSql -Query "SELECT CASE WHEN OBJECT_ID('dbo.$TableName','U') IS NULL THEN 0 ELSE 1 END AS present;"
    if (-not $exists -or [int]$exists.present -ne 1) {
        return [pscustomobject]@{ Matches = $false; RowCount = 0; Missing = $ExpectedCount; Stale = 0; DuplicateRows = 0; LoadIds = @() }
    }

    $dbRows = @(Invoke-PcdSql -Query @"
SELECT Cluster_Category, Cluster_ID, Cluster_Desc, Active_in_Refset,
       Refset_Status_Date, RefsetId, Refset_Description, ConceptId,
       ConceptId_Description, Active_Code_Status, Code_Status_Date,
       Type_of_Inclusion, Sensitive_Status, Sensitive_Status_Date, Load_Id
FROM dbo.[$TableName];
"@ -QueryTimeout 300)

    $dbCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $loadIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $dbRows) {
        [void]$dbCanonical.Add((Get-CanonicalRow -Row $row -Separator $Separator))
        if ($row.Load_Id) { [void]$loadIds.Add([string]$row.Load_Id) }
    }

    $missing = [System.Collections.Generic.HashSet[string]]::new($SourceRows, [System.StringComparer]::Ordinal)
    $missing.ExceptWith($dbCanonical)
    $stale = [System.Collections.Generic.HashSet[string]]::new($dbCanonical, [System.StringComparer]::Ordinal)
    $stale.ExceptWith($SourceRows)
    $duplicates = $dbRows.Count - $dbCanonical.Count

    return [pscustomobject]@{
        Matches       = $dbRows.Count -eq $ExpectedCount -and $duplicates -eq 0 -and $missing.Count -eq 0 -and $stale.Count -eq 0
        RowCount      = $dbRows.Count
        Missing       = $missing.Count
        Stale         = $stale.Count
        DuplicateRows = $duplicates
        LoadIds       = @($loadIds)
    }
}

function New-GPDataDataTable {
    param(
        [Parameter(Mandatory = $true)][array]$Rows,
        [Parameter(Mandatory = $true)][guid]$LoadId
    )

    $table = [System.Data.DataTable]::new()
    foreach ($name in $sourceColumns) {
        $type = if ($name -in @("Active_in_Refset", "Active_Code_Status", "Sensitive_Status")) { [bool] } else { [string] }
        [void]$table.Columns.Add($name, $type)
    }
    [void]$table.Columns.Add("Load_Id", [guid])

    foreach ($row in $Rows) {
        [void]$table.Rows.Add(@(
            [string]$row.Cluster_Category,
            [string]$row.Cluster_ID,
            [string]$row.Cluster_Desc,
            ($row.Active_in_Refset -eq "1"),
            [string]$row.Refset_Status_Date,
            [string]$row.RefsetId,
            [string]$row.Refset_Description,
            [string]$row.ConceptId,
            [string]$row.ConceptId_Description,
            ($row.Active_Code_Status -eq "1"),
            [string]$row.Code_Status_Date,
            [string]$row.Type_of_Inclusion,
            ($row.Sensitive_Status -eq "1"),
            [string]$row.Sensitive_Status_Date,
            $LoadId
        ))
    }

    # DataTable is IEnumerable; suppress pipeline enumeration into DataRow objects.
    return ,$table
}

function Invoke-PcdBulkCopy {
    param(
        [Parameter(Mandatory = $true)][string]$TableName,
        [Parameter(Mandatory = $true)][System.Data.DataTable]$Data
    )

    if ($TableName -notmatch '^PCD_(GPData|GDPPR)_[A-Za-z0-9_]+$') {
        throw "Unsafe GPData staging table name: $TableName"
    }

    $connectionString = "Server=$ServerInstance;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True"
    $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
    try {
        $connection.Open()
        $bulk = [System.Data.SqlClient.SqlBulkCopy]::new($connection)
        try {
            $bulk.DestinationTableName = "dbo.[$TableName]"
            $bulk.BatchSize = 10000
            $bulk.BulkCopyTimeout = 600
            foreach ($column in $Data.Columns) {
                [void]$bulk.ColumnMappings.Add($column.ColumnName, $column.ColumnName)
            }
            $bulk.WriteToServer($Data)
        } finally {
            $bulk.Dispose()
        }
    } finally {
        $connection.Dispose()
    }
}

# Discover the authoritative source file.
if ($CsvPath) {
    $resolvedCsv = (Resolve-Path -LiteralPath $CsvPath).Path
    $resolvedFileName = Split-Path $resolvedCsv -Leaf
    if ($resolvedFileName -notmatch "^$([regex]::Escape($ProductCode))_Cluster_Refset_.+\.csv$") {
        throw "Explicit CSV '$resolvedFileName' does not match ProductCode '$ProductCode'"
    }
    $releaseMatch = [regex]::Match($resolvedCsv, '(?i)[\\/](uk_sct2pc_[^\\/]+)')
    $sourceRelease = if ($releaseMatch.Success) { $releaseMatch.Groups[1].Value } else { "manual" }
} else {
    if (-not (Test-Path -LiteralPath $ReleasesPath -PathType Container)) {
        throw "PCD releases folder not found: $ReleasesPath"
    }
    $release = Get-ChildItem -LiteralPath $ReleasesPath -Directory -Filter "uk_sct2pc_*" |
        ForEach-Object {
            if ($_.Name -match '_(?<stamp>\d{14})Z$') {
                [pscustomobject]@{ Path = $_.FullName; Name = $_.Name; Stamp = $Matches.stamp }
            }
        } |
        Sort-Object Stamp -Descending |
        Select-Object -First 1
    if (-not $release) {
        throw "No timestamped uk_sct2pc release folder found in $ReleasesPath"
    }
    $resolvedCsv = (Get-ChildItem -LiteralPath $release.Path -Recurse -File -Filter "${ProductCode}_Cluster_Refset_*.csv" |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName)
    if (-not $resolvedCsv) {
        throw "No ${ProductCode}_Cluster_Refset CSV found below $($release.Path)"
    }
    $sourceRelease = $release.Name
}

Write-Host "PCD release : $sourceRelease" -ForegroundColor Cyan
Write-Host "$ProductCode file : $resolvedCsv" -ForegroundColor Gray

$sourceEncoding = Get-PcdCsvEncoding -Path $resolvedCsv
$allRows = @(Import-Csv -LiteralPath $resolvedCsv -Encoding $sourceEncoding)
if ($allRows.Count -eq 0) {
    throw "$ProductCode source is empty: $resolvedCsv"
}

$actualColumns = @($allRows[0].PSObject.Properties.Name)
$missingColumns = @($sourceColumns | Where-Object { $_ -notin $actualColumns })
$unexpectedColumns = @($actualColumns | Where-Object { $_ -notin $sourceColumns })
if ($missingColumns.Count -gt 0 -or $unexpectedColumns.Count -gt 0 -or
    ($actualColumns -join [char]31) -cne ($sourceColumns -join [char]31)) {
    throw "$ProductCode schema mismatch. Missing=[$($missingColumns -join ', ')]; unexpected=[$($unexpectedColumns -join ', ')]"
}

$separator = [char]31
$sourceCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$membershipKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$activeCount = 0
$rowNumber = 1
foreach ($row in $allRows) {
    $rowNumber++
    foreach ($column in $sourceColumns) {
        if ([string]::IsNullOrWhiteSpace([string]$row.$column)) {
            throw "$ProductCode row $rowNumber has an empty required value in $column"
        }
        if (([string]$row.$column).Contains([char]0xFFFD)) {
            throw "$ProductCode row $rowNumber contains a Unicode replacement character in $column; source decoding is not lossless"
        }
        if (([string]$row.$column).Contains($separator)) {
            throw "$ProductCode row $rowNumber contains the reserved validation separator in $column"
        }
    }
    foreach ($flag in @("Active_in_Refset", "Active_Code_Status", "Sensitive_Status")) {
        if ([string]$row.$flag -notin @("0", "1")) {
            throw "$ProductCode row $rowNumber has invalid $flag value '$($row.$flag)'"
        }
    }
    foreach ($dateColumn in @("Refset_Status_Date", "Code_Status_Date", "Sensitive_Status_Date")) {
        if ([string]$row.$dateColumn -notmatch '^\d{8}$') {
            throw "$ProductCode row $rowNumber has invalid $dateColumn value '$($row.$dateColumn)'"
        }
        $parsedDate = [datetime]::MinValue
        if (-not [datetime]::TryParseExact(
                [string]$row.$dateColumn,
                "yyyyMMdd",
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None,
                [ref]$parsedDate)) {
            throw "$ProductCode row $rowNumber has a non-calendar $dateColumn value '$($row.$dateColumn)'"
        }
    }
    foreach ($idColumn in @("RefsetId", "ConceptId")) {
        if ([string]$row.$idColumn -notmatch '^\d{6,18}$') {
            throw "$ProductCode row $rowNumber has invalid $idColumn value '$($row.$idColumn)'"
        }
    }
    if ([string]$row.Cluster_ID -notmatch '^[A-Z0-9_]+$') {
        throw "$ProductCode row $rowNumber has invalid Cluster_ID '$($row.Cluster_ID)'"
    }
    if ([string]$row.Type_of_Inclusion -notin @("Refset", "PC refset")) {
        throw "$ProductCode row $rowNumber has unsupported Type_of_Inclusion '$($row.Type_of_Inclusion)'"
    }
    foreach ($entry in $textLimits.GetEnumerator()) {
        if (([string]$row.($entry.Key)).Length -gt [int]$entry.Value) {
            throw "$ProductCode row $rowNumber exceeds the $($entry.Value)-character limit for $($entry.Key)"
        }
    }

    $membershipKey = "$($row.Cluster_ID)$separator$($row.ConceptId)$separator$($row.RefsetId)"
    if (-not $membershipKeys.Add($membershipKey)) {
        throw "$ProductCode source contains duplicate membership key at row ${rowNumber}: Cluster_ID=$($row.Cluster_ID), ConceptId=$($row.ConceptId), RefsetId=$($row.RefsetId)"
    }
    if (-not $sourceCanonical.Add((Get-CanonicalRow -Row $row -Separator $separator))) {
        throw "$ProductCode source contains an exact duplicate row at row $rowNumber"
    }
    if ($row.Active_in_Refset -eq "1" -and $row.Active_Code_Status -eq "1") {
        $activeCount++
    }
}

$sourceHash = (Get-FileHash -LiteralPath $resolvedCsv -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceFile = Split-Path $resolvedCsv -Leaf
$loadId = [guid]::NewGuid()
$targetDescription = "$ServerInstance/$DatabaseName/dbo.$targetTableName"

if (-not $PSCmdlet.ShouldProcess($targetDescription, "Atomically load $($allRows.Count) $ProductCode rows from $sourceFile")) {
    return [pscustomobject]@{
        Success = $true; Planned = $true; Skipped = $true; LoadId = $null
        ProductCode = $ProductCode; SourceEncoding = $sourceEncoding.WebName
        SourceRelease = $sourceRelease; SourceFile = $sourceFile
        SourceRows = $allRows.Count; ActiveRows = $activeCount; SourceHash = $sourceHash
    }
}

$historySchemaSql = @"
IF OBJECT_ID('dbo.PCD_GPData_Load_History','U') IS NULL
BEGIN
    CREATE TABLE dbo.PCD_GPData_Load_History (
        Load_Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_PCD_GPData_Load_History PRIMARY KEY,
        Product_Code NVARCHAR(16) NOT NULL,
        Source_Release NVARCHAR(200) NOT NULL,
        Source_File NVARCHAR(512) NOT NULL,
        Source_SHA256 CHAR(64) NOT NULL,
        Source_Encoding NVARCHAR(32) NOT NULL,
        Source_Row_Count BIGINT NOT NULL,
        Active_Row_Count BIGINT NOT NULL,
        Started_At DATETIME2(0) NOT NULL CONSTRAINT DF_PCD_GPData_Load_Started DEFAULT SYSUTCDATETIME(),
        Completed_At DATETIME2(0) NULL,
        Success BIT NOT NULL,
        Details NVARCHAR(2000) NULL
    );
    CREATE INDEX IX_PCD_GPData_Load_Source ON dbo.PCD_GPData_Load_History(Source_Release, Completed_At DESC);
END;
"@
Invoke-PcdSql -Query $historySchemaSql | Out-Null

$productColumnSql = @"
IF COL_LENGTH('dbo.PCD_GPData_Load_History','Product_Code') IS NULL
    ALTER TABLE dbo.PCD_GPData_Load_History ADD Product_Code NVARCHAR(16) NULL;
"@
Invoke-PcdSql -Query $productColumnSql | Out-Null
Invoke-PcdSql -Query @"
IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id=OBJECT_ID('dbo.PCD_GPData_Load_History')
      AND name='Product_Code'
      AND is_nullable=1
)
BEGIN
    UPDATE dbo.PCD_GPData_Load_History SET Product_Code=N'GPData' WHERE Product_Code IS NULL;
    ALTER TABLE dbo.PCD_GPData_Load_History ALTER COLUMN Product_Code NVARCHAR(16) NOT NULL;
END;
"@ | Out-Null

$encodingColumnSql = @"
IF COL_LENGTH('dbo.PCD_GPData_Load_History','Source_Encoding') IS NULL
    ALTER TABLE dbo.PCD_GPData_Load_History ADD Source_Encoding NVARCHAR(32) NULL;
"@
Invoke-PcdSql -Query $encodingColumnSql | Out-Null
Invoke-PcdSql -Query @"
IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id=OBJECT_ID('dbo.PCD_GPData_Load_History')
      AND name='Source_Encoding'
      AND is_nullable=1
)
BEGIN
    UPDATE dbo.PCD_GPData_Load_History SET Source_Encoding=N'unknown' WHERE Source_Encoding IS NULL;
    ALTER TABLE dbo.PCD_GPData_Load_History ALTER COLUMN Source_Encoding NVARCHAR(32) NOT NULL;
END;
"@ | Out-Null

$targetSchemaSql = @"
IF OBJECT_ID('dbo.$targetTableName','U') IS NULL
BEGIN
    CREATE TABLE dbo.[$targetTableName] (
        Cluster_Category NVARCHAR(128) NOT NULL,
        Cluster_ID NVARCHAR(64) NOT NULL,
        Cluster_Desc NVARCHAR(1000) NOT NULL,
        Active_in_Refset BIT NOT NULL,
        Refset_Status_Date CHAR(8) NOT NULL,
        RefsetId VARCHAR(18) NOT NULL,
        Refset_Description NVARCHAR(1000) NOT NULL,
        ConceptId VARCHAR(18) NOT NULL,
        ConceptId_Description NVARCHAR(1000) NOT NULL,
        Active_Code_Status BIT NOT NULL,
        Code_Status_Date CHAR(8) NOT NULL,
        Type_of_Inclusion NVARCHAR(64) NOT NULL,
        Sensitive_Status BIT NOT NULL,
        Sensitive_Status_Date CHAR(8) NOT NULL,
        Load_Id UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_PCD_${ProductCode}_Cluster_Refset PRIMARY KEY CLUSTERED (Cluster_ID, ConceptId, RefsetId),
        CONSTRAINT FK_PCD_${ProductCode}_Cluster_Load FOREIGN KEY (Load_Id) REFERENCES dbo.PCD_GPData_Load_History(Load_Id),
        CONSTRAINT CK_PCD_${ProductCode}_ActiveRefset CHECK (Active_in_Refset IN (0,1)),
        CONSTRAINT CK_PCD_${ProductCode}_ActiveCode CHECK (Active_Code_Status IN (0,1)),
        CONSTRAINT CK_PCD_${ProductCode}_Sensitive CHECK (Sensitive_Status IN (0,1)),
        CONSTRAINT CK_PCD_${ProductCode}_Inclusion CHECK (Type_of_Inclusion IN (N'Refset', N'PC refset'))
    );
    CREATE INDEX IX_PCD_${ProductCode}_Refset ON dbo.[$targetTableName](RefsetId, Cluster_ID) INCLUDE (ConceptId, ConceptId_Description);
    CREATE INDEX IX_PCD_${ProductCode}_Concept ON dbo.[$targetTableName](ConceptId) INCLUDE (Cluster_ID, RefsetId);
    CREATE INDEX IX_PCD_${ProductCode}_ActiveCluster ON dbo.[$targetTableName](Cluster_ID, RefsetId, ConceptId)
        INCLUDE (Cluster_Desc, ConceptId_Description, Cluster_Category, Type_of_Inclusion)
        WHERE Active_in_Refset = 1 AND Active_Code_Status = 1;
END;
"@
Invoke-PcdSql -Query $targetSchemaSql | Out-Null

if (-not $Force) {
    $currentState = Test-PcdTableMatchesSource -TableName $targetTableName `
        -SourceRows $sourceCanonical -ExpectedCount $allRows.Count -Separator $separator
    if ($currentState.Matches -and $currentState.LoadIds.Count -eq 1) {
        $currentLoadId = ConvertTo-SqlText $currentState.LoadIds[0]
        $history = Invoke-PcdSql -Query "SELECT Product_Code, Source_Release, Source_File, Source_SHA256, Source_Encoding, Source_Row_Count, Active_Row_Count, Success FROM dbo.PCD_GPData_Load_History WHERE Load_Id='$currentLoadId';"
        if ($history -and [bool]$history.Success -and
            [string]$history.Product_Code -eq $ProductCode -and
            [string]$history.Source_Release -eq $sourceRelease -and
            [string]$history.Source_File -eq $sourceFile -and
            [string]$history.Source_SHA256 -eq $sourceHash -and
            [string]$history.Source_Encoding -eq $sourceEncoding.WebName -and
            [int64]$history.Source_Row_Count -eq $allRows.Count -and
            [int64]$history.Active_Row_Count -eq $activeCount) {
            Write-Host "Canonical $ProductCode table already exactly matches $sourceFile; no reload required." -ForegroundColor Green
            return [pscustomobject]@{
                Success = $true; Planned = $false; Skipped = $true; LoadId = $currentState.LoadIds[0]
                ProductCode = $ProductCode; SourceEncoding = $sourceEncoding.WebName
                SourceRelease = $sourceRelease; SourceFile = $sourceFile
                SourceRows = $allRows.Count; ActiveRows = $activeCount; SourceHash = $sourceHash
            }
        }
    }
}

$stageName = "PCD_${ProductCode}_Stage_$($loadId.ToString('N'))"
$historyInserted = $false
try {
    $safeRelease = ConvertTo-SqlText $sourceRelease
    $safeFile = ConvertTo-SqlText $sourceFile
    Invoke-PcdSql -Query @"
INSERT INTO dbo.PCD_GPData_Load_History
    (Load_Id, Product_Code, Source_Release, Source_File, Source_SHA256, Source_Encoding, Source_Row_Count, Active_Row_Count, Success, Details)
VALUES
    ('$loadId', N'$ProductCode', N'$safeRelease', N'$safeFile', '$sourceHash', N'$($sourceEncoding.WebName)', $($allRows.Count), $activeCount, 0, N'Loading');
"@ | Out-Null
    $historyInserted = $true

    Invoke-PcdSql -Query @"
CREATE TABLE dbo.[$stageName] (
    Cluster_Category NVARCHAR(128) NOT NULL,
    Cluster_ID NVARCHAR(64) NOT NULL,
    Cluster_Desc NVARCHAR(1000) NOT NULL,
    Active_in_Refset BIT NOT NULL,
    Refset_Status_Date CHAR(8) NOT NULL,
    RefsetId VARCHAR(18) NOT NULL,
    Refset_Description NVARCHAR(1000) NOT NULL,
    ConceptId VARCHAR(18) NOT NULL,
    ConceptId_Description NVARCHAR(1000) NOT NULL,
    Active_Code_Status BIT NOT NULL,
    Code_Status_Date CHAR(8) NOT NULL,
    Type_of_Inclusion NVARCHAR(64) NOT NULL,
    Sensitive_Status BIT NOT NULL,
    Sensitive_Status_Date CHAR(8) NOT NULL,
    Load_Id UNIQUEIDENTIFIER NOT NULL
);
"@ | Out-Null

    $data = New-GPDataDataTable -Rows $allRows -LoadId $loadId
    try {
        Invoke-PcdBulkCopy -TableName $stageName -Data $data
    } finally {
        $data.Dispose()
    }

    $stageState = Test-PcdTableMatchesSource -TableName $stageName `
        -SourceRows $sourceCanonical -ExpectedCount $allRows.Count -Separator $separator
    if (-not $stageState.Matches -or $stageState.LoadIds.Count -ne 1 -or [string]$stageState.LoadIds[0] -ne [string]$loadId) {
        throw "Staging verification failed: rows=$($stageState.RowCount), missing=$($stageState.Missing), stale=$($stageState.Stale), duplicates=$($stageState.DuplicateRows), loadIds=$($stageState.LoadIds.Count)"
    }

    $postStageHash = (Get-FileHash -LiteralPath $resolvedCsv -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($postStageHash -cne $sourceHash) {
        throw "$ProductCode source file changed while it was being loaded: $resolvedCsv"
    }

    Invoke-PcdSql -Query @"
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.[$targetTableName];
    INSERT INTO dbo.[$targetTableName] WITH (TABLOCK)
        (Cluster_Category, Cluster_ID, Cluster_Desc, Active_in_Refset,
         Refset_Status_Date, RefsetId, Refset_Description, ConceptId,
         ConceptId_Description, Active_Code_Status, Code_Status_Date,
         Type_of_Inclusion, Sensitive_Status, Sensitive_Status_Date, Load_Id)
    SELECT Cluster_Category, Cluster_ID, Cluster_Desc, Active_in_Refset,
           Refset_Status_Date, RefsetId, Refset_Description, ConceptId,
           ConceptId_Description, Active_Code_Status, Code_Status_Date,
           Type_of_Inclusion, Sensitive_Status, Sensitive_Status_Date, Load_Id
    FROM dbo.[$stageName];

    IF @@ROWCOUNT <> $($allRows.Count)
        THROW 51000, 'Canonical $ProductCode row count did not match the staged source.', 1;

    UPDATE dbo.PCD_GPData_Load_History
    SET Success = 1,
        Completed_At = SYSUTCDATETIME(),
        Details = N'Atomic load completed and verified'
    WHERE Load_Id = '$loadId';

    DROP TABLE dbo.[$stageName];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@ -QueryTimeout 600 | Out-Null

    Write-Host "Loaded and verified $($allRows.Count) canonical $ProductCode rows ($activeCount active)." -ForegroundColor Green
    return [pscustomobject]@{
        Success = $true; Planned = $false; Skipped = $false; LoadId = [string]$loadId
        ProductCode = $ProductCode; SourceEncoding = $sourceEncoding.WebName
        SourceRelease = $sourceRelease; SourceFile = $sourceFile
        SourceRows = $allRows.Count; ActiveRows = $activeCount; SourceHash = $sourceHash
    }
} catch {
    $loadError = $_
    $safeError = ConvertTo-SqlText ($loadError.Exception.Message.Substring(0, [Math]::Min(1900, $loadError.Exception.Message.Length)))
    try {
        Invoke-PcdSql -Query "IF OBJECT_ID('dbo.$stageName','U') IS NOT NULL DROP TABLE dbo.[$stageName];" | Out-Null
    } catch {
        Write-Warning "Could not remove failed $ProductCode staging table $stageName"
    }
    if ($historyInserted) {
        try {
            Invoke-PcdSql -Query "UPDATE dbo.PCD_GPData_Load_History SET Success=0, Completed_At=SYSUTCDATETIME(), Details=N'$safeError' WHERE Load_Id='$loadId';" | Out-Null
        } catch {
            Write-Warning "Could not record failed $ProductCode load metadata"
        }
    }
    throw $loadError
}
