# Shared source parsing and SQL staging for the importer and exact validator.
# Dot-source this file; it does not open connections or change the database.

function Get-DmdPackPriceSource {
    param([Parameter(Mandatory = $true)][string]$XmlPath)

    $definitions = @(
        @{
            Table = 'ampp_price'; Pattern = 'f_ampp2_*.xml'
            Section = '/ACTUAL_MEDICINAL_PROD_PACKS/MEDICINAL_PRODUCT_PRICE'; Row = 'PRICE_INFO'
            Key = 'appid'; Parent = 'ampp'; Code = 'price_basiscd'; Lookup = 'PRICE_BASIS'
            Columns = @('appid', 'price', 'pricedt', 'price_prev', 'price_basiscd')
            Types = @([string], [long], [datetime], [long], [string])
        },
        @{
            Table = 'vmpp_drugtariffinfo'; Pattern = 'f_vmpp2_*.xml'
            Section = '/VIRTUAL_MED_PRODUCT_PACK/DRUG_TARIFF_INFO'; Row = 'DTINFO'
            Key = 'vppid'; Parent = 'vmpp'; Code = 'pay_catcd'; Lookup = 'DT_PAYMENT_CATEGORY'
            Columns = @('vppid', 'pay_catcd', 'price', 'dt', 'prevprice')
            Types = @([string], [string], [long], [datetime], [long])
        }
    )

    foreach ($definition in $definitions) {
        $files = @(Get-ChildItem -LiteralPath $XmlPath -Filter $definition.Pattern -File -Recurse -ErrorAction Stop)
        if ($files.Count -ne 1) {
            throw "Expected exactly one $($definition.Pattern) in $XmlPath; found $($files.Count). Supply one full release folder."
        }
        $document = New-Object System.Xml.XmlDocument
        $document.XmlResolver = $null
        $document.Load($files[0].FullName)
        $section = $document.SelectSingleNode($definition.Section)
        if ($null -eq $section) { throw "Missing $($definition.Section) in $($files[0].Name)." }
        $nodes = $section.SelectNodes($definition.Row)
        # An empty full-release price feed is unexpected; never erase prices for it.
        if ($nodes.Count -eq 0) { throw "Empty $($definition.Table) source in $($files[0].Name)." }

        $data = New-Object System.Data.DataTable $definition.Table
        for ($i = 0; $i -lt $definition.Columns.Count; $i++) {
            $column = $data.Columns.Add($definition.Columns[$i], $definition.Types[$i])
            if ($definition.Types[$i] -eq [string]) {
                $column.MaxLength = if ($column.ColumnName -eq $definition.Key) { 18 } else { 10 }
                $column.AllowDBNull = $false
            }
        }
        $data.PrimaryKey = @($data.Columns[$definition.Key])
        foreach ($node in $nodes) {
            $row = $data.NewRow()
            for ($i = 0; $i -lt $definition.Columns.Count; $i++) {
                $columnName = $definition.Columns[$i]
                $element = $node.SelectSingleNode($columnName.ToUpperInvariant())
                if ($null -eq $element) { continue }
                $value = $element.InnerText
                if ([string]::IsNullOrWhiteSpace($value)) { throw "Empty $columnName in $($definition.Table)." }
                if ($definition.Types[$i] -eq [datetime]) {
                    $row[$columnName] = [datetime]::ParseExact($value, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
                } elseif ($definition.Types[$i] -eq [long]) {
                    $row[$columnName] = [long]::Parse($value, [cultureinfo]::InvariantCulture)
                } else {
                    if ($value -notmatch '^\d+$') { throw "Invalid $columnName in $($definition.Table): $value" }
                    $row[$columnName] = $value
                }
            }
            # DataTable enforces required codes/keys, length limits and unique keys.
            $data.Rows.Add($row)
        }
        $definition.Data = $data
        $definition.SourceFile = $files[0].FullName
        [pscustomobject]$definition
    }
}

function New-DmdPriceConnection {
    param([string]$ServerInstance, [string]$Database)
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $ServerInstance
    $builder['Initial Catalog'] = $Database
    $builder['Integrated Security'] = $true
    $builder['Encrypt'] = $true
    $builder['TrustServerCertificate'] = $true
    $builder['Connect Timeout'] = 30
    $connection = New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
    $connection.Open()
    return $connection
}

function Invoke-DmdPriceSql {
    param($Connection, [string]$Sql, $Transaction = $null, [switch]$Scalar,
        [string]$Operation = 'SQL statement')
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $Sql
        $command.CommandTimeout = 180
        $command.Transaction = $Transaction
        if ($Scalar) { return $command.ExecuteScalar() }
        [void]$command.ExecuteNonQuery()
    } catch {
        throw "dm+d $Operation failed: $($_.Exception.Message)"
    } finally { $command.Dispose() }
}

function Add-DmdPriceStage {
    param($Connection, $Source, $Transaction = $null)
    $table = $Source.Table
    $columns = $Source.Columns -join ', '
    $key = $Source.Key
    # Create the ordered key while empty: building/sorting a full-release heap
    # later can itself wait for a large grant on a memory-constrained Express host.
    Invoke-DmdPriceSql $Connection @"
SELECT TOP (0) $columns INTO #$table FROM dbo.$table;
CREATE UNIQUE CLUSTERED INDEX IX_price_stage_key ON #$table ($key);
"@ $Transaction -Operation "$table staging setup"
    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($Connection, [System.Data.SqlClient.SqlBulkCopyOptions]::Default, $Transaction)
    try {
        $bulk.DestinationTableName = "#$table"
        $bulk.BatchSize = 5000
        $bulk.BulkCopyTimeout = 180
        foreach ($column in $Source.Columns) { [void]$bulk.ColumnMappings.Add($column, $column) }
        $bulk.WriteToServer($Source.Data)
    } finally { $bulk.Dispose() }

    $code = $Source.Code
    $parent = $Source.Parent
    $lookup = $Source.Lookup
    # Both pack keys are indexed in the same order. Stream the reference check
    # instead of hashing the entire release and waiting on RESOURCE_SEMAPHORE.
    $missingPacks = Invoke-DmdPriceSql $Connection @"
SELECT COUNT(*) FROM #$table s
LEFT MERGE JOIN dbo.$parent p ON p.$key = s.$key
WHERE p.$key IS NULL
OPTION (MAXDOP 1);
"@ $Transaction -Scalar -Operation "$table pack-reference validation"
    # There are only a handful of lookup codes per type. A loop anti-join keeps
    # the code-normalisation check independent of full-release memory grants.
    $unknownCodes = Invoke-DmdPriceSql $Connection @"
SELECT COUNT(*) FROM #$table s WHERE NOT EXISTS (
        SELECT 1 FROM dbo.lookup l WHERE l.type = '$lookup'
        AND TRY_CONVERT(BIGINT, l.cd) = TRY_CONVERT(BIGINT, s.$code))
OPTION (LOOP JOIN, MAXDOP 1);
"@ $Transaction -Scalar -Operation "$table $lookup validation"
    $issues = $missingPacks + $unknownCodes
    if ($issues -ne 0) { throw "$table source has $issues missing pack references or unknown $lookup codes." }
}

function Assert-DmdPriceMatch {
    param($Connection, $Source, $Transaction = $null)
    $table = $Source.Table
    $key = $Source.Key
    $sourceColumns = ($Source.Columns | ForEach-Object { "s.$_" }) -join ', '
    $targetColumns = ($Source.Columns | ForEach-Object { "t.$_" }) -join ', '
    # Merge the unique ordered keys, then compare one pair of rows at a time.
    # The single-row EXCEPT preserves NULL semantics without sorting/hashing
    # two complete snapshots (which can exhaust the Express query workspace).
    $differences = Invoke-DmdPriceSql $Connection @"
SELECT COUNT(*) FROM #$table s
FULL OUTER MERGE JOIN dbo.$table t ON t.$key = s.$key
WHERE s.$key IS NULL OR t.$key IS NULL
    OR EXISTS (SELECT $sourceColumns EXCEPT SELECT $targetColumns)
OPTION (MAXDOP 1);
"@ $Transaction -Scalar -Operation "$table XML field comparison"
    if ($differences -ne 0) { throw "$table differs from XML ($differences missing, changed or extra rows)." }
}
