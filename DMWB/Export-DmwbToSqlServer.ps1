<#
.SYNOPSIS
    Exports all DMWB Access databases (.mdb) to SQL Server.

.DESCRIPTION
    This script reads all Microsoft Access .mdb files from the DMWB folder,
    extracts all tables, and creates corresponding tables in SQL Server with the data.

.PARAMETER ServerInstance
    SQL Server instance name (default: localhost\SQLEXPRESS)

.PARAMETER DatabaseName
    Target database name to create/use (default: DMWB_Export)

.PARAMETER SourcePath
    Path to DMWB folder containing .mdb files

.EXAMPLE
    .\Export-DmwbToSqlServer.ps1 -DatabaseName "DMWB_Export"
#>

[CmdletBinding()]
param(
    [string]$ServerInstance = "localhost\SQLEXPRESS",
    [string]$DatabaseName = "DMWB_Export",
    [string]$SourcePath = "C:\DMWB\CurrentReleases",
    [string]$SqlUser = "sa",
    [string]$SqlPassword = "redfive5",
    [switch]$DropExisting
)

$ErrorActionPreference = "Stop"

# SQL Server connection string
$masterConnectionString = "Server=$ServerInstance;Database=master;User Id=$SqlUser;Password=$SqlPassword;TrustServerCertificate=True;"
$targetConnectionString = "Server=$ServerInstance;Database=$DatabaseName;User Id=$SqlUser;Password=$SqlPassword;TrustServerCertificate=True;"

# Ensure logs directory exists
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Log file
$logFile = Join-Path $logsDir "Export-DmwbToSqlServer_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $(switch($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } "PROGRESS" { "Cyan" } default { "White" } })
    Add-Content -Path $logFile -Value $logMessage
}

function Write-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity,
        [string]$Status
    )
    $percent = [math]::Round(($Current / $Total) * 100, 0)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $percent
}

function Execute-SqlNonQuery {
    param(
        [string]$ConnectionString,
        [string]$Query
    )
    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 300
        $result = $command.ExecuteNonQuery()
        return $result
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }
}

function Execute-SqlScalar {
    param(
        [string]$ConnectionString,
        [string]$Query
    )
    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 300
        return $command.ExecuteScalar()
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }
}

function Get-SqlDataTypeFromAccess {
    param([int]$AccessType, [int]$Size = 0)
    
    # Map Access/ADODB data types to SQL Server types
    # Note: Binary types are converted to NVARCHAR to avoid conversion issues
    switch ($AccessType) {
        2   { return "SMALLINT" }                    # adSmallInt
        3   { return "INT" }                         # adInteger
        4   { return "REAL" }                        # adSingle
        5   { return "FLOAT" }                       # adDouble
        6   { return "MONEY" }                       # adCurrency
        7   { return "DATETIME" }                    # adDate
        11  { return "BIT" }                         # adBoolean
        17  { return "TINYINT" }                     # adUnsignedTinyInt
        20  { return "BIGINT" }                      # adBigInt
        72  { return "UNIQUEIDENTIFIER" }            # adGUID
        128 { return "NVARCHAR(MAX)" }               # adBinary - converted to string
        129 { return "VARCHAR($Size)" }              # adChar
        130 { return "NVARCHAR($(if($Size -gt 0 -and $Size -le 4000){$Size}else{'MAX'}))" }  # adWChar
        131 { return "DECIMAL(18,4)" }               # adNumeric
        132 { return "VARCHAR(MAX)" }                # adUserDefined
        133 { return "DATE" }                        # adDBDate
        134 { return "TIME" }                        # adDBTime
        135 { return "DATETIME" }                    # adDBTimeStamp
        200 { return "VARCHAR($(if($Size -gt 0 -and $Size -le 8000){$Size}else{'MAX'}))" }   # adVarChar
        201 { return "VARCHAR(MAX)" }                # adLongVarChar (Memo)
        202 { return "NVARCHAR($(if($Size -gt 0 -and $Size -le 4000){$Size}else{'MAX'}))" }  # adVarWChar
        203 { return "NVARCHAR(MAX)" }               # adLongVarWChar (Memo Unicode)
        204 { return "NVARCHAR(MAX)" }               # adVarBinary - converted to string
        205 { return "NVARCHAR(MAX)" }               # adLongVarBinary (OLE Object) - converted to string
        default { return "NVARCHAR(MAX)" }           # Default fallback
    }
}

function Get-AccessTables {
    param([string]$MdbPath)
    
    $tables = @()
    $connection = New-Object -ComObject ADODB.Connection
    
    try {
        $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$MdbPath;Persist Security Info=False;"
        $connection.Open($connectionString)
        
        # Get user tables (type = "TABLE")
        $catalog = $connection.OpenSchema(20) # adSchemaTables
        
        while (-not $catalog.EOF) {
            $tableType = $catalog.Fields.Item("TABLE_TYPE").Value
            $tableName = $catalog.Fields.Item("TABLE_NAME").Value
            
            # Skip system tables (start with MSys or USys)
            if ($tableType -eq "TABLE" -and $tableName -notmatch "^(MSys|USys)") {
                $tables += $tableName
            }
            $catalog.MoveNext()
        }
        $catalog.Close()
    }
    catch {
        Write-Log "Error getting tables from $MdbPath : $_" -Level "ERROR"
    }
    finally {
        if ($connection.State -eq 1) { $connection.Close() }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($connection) | Out-Null
    }
    
    return $tables
}

function Get-TableSchema {
    param(
        [string]$MdbPath,
        [string]$TableName
    )
    
    $columns = @()
    $connection = New-Object -ComObject ADODB.Connection
    $recordset = New-Object -ComObject ADODB.Recordset
    
    try {
        $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$MdbPath;Persist Security Info=False;"
        $connection.Open($connectionString)
        
        # Open recordset to get schema
        $recordset.Open("SELECT TOP 1 * FROM [$TableName]", $connection, 0, 1)
        
        for ($i = 0; $i -lt $recordset.Fields.Count; $i++) {
            $field = $recordset.Fields.Item($i)
            $columns += [PSCustomObject]@{
                Name = $field.Name
                Type = $field.Type
                Size = $field.DefinedSize
                SqlType = Get-SqlDataTypeFromAccess -AccessType $field.Type -Size $field.DefinedSize
            }
        }
        $recordset.Close()
    }
    catch {
        Write-Log "Error getting schema for $TableName : $_" -Level "WARN"
    }
    finally {
        if ($recordset.State -eq 1) { $recordset.Close() }
        if ($connection.State -eq 1) { $connection.Close() }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($recordset) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($connection) | Out-Null
    }
    
    return $columns
}

function Export-AccessTableToSql {
    param(
        [string]$MdbPath,
        [string]$TableName,
        [string]$SqlTableName,
        [string]$ConnectionString,
        [int]$BatchSize = 1000,
        [int]$TimeoutSeconds = 3600  # 1 hour default timeout
    )
    
    $accessConnection = New-Object -ComObject ADODB.Connection
    $recordset = New-Object -ComObject ADODB.Recordset
    $sqlConnection = $null
    $rowCount = 0
    $startTime = Get-Date
    
    try {
        # Open Access connection
        $accessConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$MdbPath;Persist Security Info=False;"
        $accessConnection.Open($accessConnectionString)
        
        # Get schema first
        $columns = Get-TableSchema -MdbPath $MdbPath -TableName $TableName
        
        if ($columns.Count -eq 0) {
            Write-Log "  ⚠️  No columns found for table $TableName" -Level "WARN"
            return 0
        }
        
        # Create SQL table
        $columnDefs = ($columns | ForEach-Object { 
            $colName = $_.Name -replace '[^\w]', '_'
            "[$colName] $($_.SqlType) NULL" 
        }) -join ", "
        
        $createTableSql = "IF OBJECT_ID('[$SqlTableName]', 'U') IS NOT NULL DROP TABLE [$SqlTableName]; CREATE TABLE [$SqlTableName] ($columnDefs);"
        Execute-SqlNonQuery -ConnectionString $ConnectionString -Query $createTableSql | Out-Null
        
        # Open recordset
        $recordset.CursorLocation = 3  # adUseClient
        $recordset.Open("SELECT * FROM [$TableName]", $accessConnection, 3, 1)  # adOpenStatic, adLockReadOnly
        
        # Get total row count
        $totalRows = $recordset.RecordCount
        
        if ($recordset.EOF -and $recordset.BOF) {
            Write-Host " [EMPTY]" -ForegroundColor Yellow
            Write-Log "  ⚠️  Table $TableName is empty" -Level "WARN"
            return 0
        }
        
        # Adjust timeout based on table size (2 hours for tables > 10M rows)
        if ($totalRows -gt 10000000) {
            $TimeoutSeconds = 7200  # 2 hours
            Write-Host " [LARGE TABLE: $totalRows rows, timeout: 2hrs] " -NoNewline -ForegroundColor Yellow
        }
        elseif ($totalRows -gt 1000000) {
            $TimeoutSeconds = 3600  # 1 hour
            Write-Host " [LARGE TABLE: $totalRows rows, timeout: 1hr] " -NoNewline -ForegroundColor Yellow
        }
        
        Write-Host " [0/$totalRows rows] " -NoNewline
        
        # Bulk insert using SqlBulkCopy
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $sqlConnection.Open()
        
        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($sqlConnection)
        $bulkCopy.DestinationTableName = "[$SqlTableName]"
        $bulkCopy.BatchSize = $BatchSize
        $bulkCopy.BulkCopyTimeout = $TimeoutSeconds
        
        # Create DataTable
        $dataTable = New-Object System.Data.DataTable
        foreach ($col in $columns) {
            $colName = $col.Name -replace '[^\w]', '_'
            $dtColumn = New-Object System.Data.DataColumn($colName)
            $dtColumn.AllowDBNull = $true
            $dataTable.Columns.Add($dtColumn) | Out-Null
        }
        
        # Map columns
        foreach ($col in $columns) {
            $colName = $col.Name -replace '[^\w]', '_'
            $bulkCopy.ColumnMappings.Add($colName, $colName) | Out-Null
        }
        
        # Read data with timeout checking
        $batchCount = 0
        $lastProgressUpdate = Get-Date
        $lastTimeoutCheck = Get-Date
        
        while (-not $recordset.EOF) {
            # Check for timeout every 10 seconds
            $now = Get-Date
            if (($now - $lastTimeoutCheck).TotalSeconds -ge 10) {
                $elapsed = $now - $startTime
                if ($elapsed.TotalSeconds -gt $TimeoutSeconds) {
                    throw "Export timeout exceeded ($TimeoutSeconds seconds / $([math]::Round($TimeoutSeconds/60,1)) minutes) at row $rowCount of $totalRows"
                }
                $lastTimeoutCheck = $now
            }
            
            $row = $dataTable.NewRow()
            for ($i = 0; $i -lt $columns.Count; $i++) {
                $value = $recordset.Fields.Item($i).Value
                $colName = $columns[$i].Name -replace '[^\w]', '_'
                $colType = $columns[$i].Type
                
                if ($null -eq $value -or [System.DBNull]::Value.Equals($value)) {
                    $row[$colName] = [System.DBNull]::Value
                }
                elseif ($colType -in @(202, 203, 204)) {
                    # Unicode text types - convert byte arrays to Unicode strings
                    if ($value -is [byte[]]) {
                        $row[$colName] = [System.Text.Encoding]::Unicode.GetString($value)
                    }
                    else {
                        $row[$colName] = $value.ToString()
                    }
                }
                elseif ($colType -in @(128, 205)) {
                    # Binary types - convert to Base64 string
                    if ($value -is [byte[]]) {
                        $row[$colName] = [System.Convert]::ToBase64String($value)
                    }
                    else {
                        $row[$colName] = $value.ToString()
                    }
                }
                else {
                    $row[$colName] = $value
                }
            }
            $dataTable.Rows.Add($row)
            $rowCount++
            $batchCount++
            
            # Write in batches
            if ($batchCount -ge $BatchSize) {
                $bulkCopy.WriteToServer($dataTable)
                $dataTable.Clear()
                $batchCount = 0
                
                # Update progress every second
                $now = Get-Date
                if (($now - $lastProgressUpdate).TotalSeconds -ge 1) {
                    Write-Host "`r  ✓ Exporting: $table -> $sqlTableName [$rowCount/$totalRows rows] " -NoNewline
                    $lastProgressUpdate = $now
                }
            }
            
            $recordset.MoveNext()
        }
        
        # Write remaining rows
        if ($dataTable.Rows.Count -gt 0) {
            $bulkCopy.WriteToServer($dataTable)
        }
        
        $recordset.Close()
        
        # Final progress update
        $duration = (Get-Date) - $startTime
        Write-Host "`r  ✓ Exported: $table -> $sqlTableName [$rowCount rows in $([math]::Round($duration.TotalSeconds,1))s]" -NoNewline
    }
    catch {
        Write-Log "  ❌ Error exporting table $TableName : $_" -Level "ERROR"
        throw
    }
    finally {
        if ($recordset.State -eq 1) { $recordset.Close() }
        if ($accessConnection.State -eq 1) { $accessConnection.Close() }
        if ($sqlConnection -and $sqlConnection.State -eq 'Open') { $sqlConnection.Close() }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($recordset) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($accessConnection) | Out-Null
    }
    
    return $rowCount
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Write-Log "========================================================"
Write-Log "DMWB Access to SQL Server Export Tool"
Write-Log "========================================================"
Write-Log "Server: $ServerInstance"
Write-Log "Database: $DatabaseName"
Write-Log "Source: $SourcePath"
Write-Log ""

# Step 1: Test SQL Server connection
Write-Log "Testing SQL Server connection..."
try {
    $version = Execute-SqlScalar -ConnectionString $masterConnectionString -Query "SELECT @@VERSION"
    Write-Log "Connected to: $($version.Substring(0, 60))..." -Level "SUCCESS"
}
catch {
    Write-Log "Failed to connect to SQL Server: $_" -Level "ERROR"
    exit 1
}

# Step 2: Create database if it doesn't exist
Write-Log "Creating database '$DatabaseName'..."
try {
    $dbExists = Execute-SqlScalar -ConnectionString $masterConnectionString -Query "SELECT database_id FROM sys.databases WHERE name = '$DatabaseName'"
    
    if ($dbExists -and $DropExisting) {
        Write-Log "Dropping existing database..." -Level "WARN"
        Execute-SqlNonQuery -ConnectionString $masterConnectionString -Query @"
ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE [$DatabaseName];
"@ | Out-Null
        $dbExists = $null
    }
    
    if (-not $dbExists) {
        Execute-SqlNonQuery -ConnectionString $masterConnectionString -Query "CREATE DATABASE [$DatabaseName]" | Out-Null
        Write-Log "Database '$DatabaseName' created successfully" -Level "SUCCESS"
    }
    else {
        Write-Log "Database '$DatabaseName' already exists - will add/update tables" -Level "WARN"
    }
}
catch {
    Write-Log "Failed to create database: $_" -Level "ERROR"
    exit 1
}

# Step 3: Find all Access databases
$mdbFiles = Get-ChildItem -Path $SourcePath -Filter "*.mdb" -File -Recurse | Where-Object { $_.Name -notmatch "^~" }
Write-Log "Found $($mdbFiles.Count) Access database files"
Write-Log ""

# Step 4: Export each database
$totalTables = 0
$totalRows = 0
$exportSummary = @()
$dbIndex = 0

foreach ($mdbFile in $mdbFiles) {
    $dbIndex++
    
    Write-Host "`n" -NoNewline
    Write-Log "========================================================" -Level "PROGRESS"
    Write-Log "[$dbIndex/$($mdbFiles.Count)] Processing: $($mdbFile.Name)" -Level "PROGRESS"
    Write-Log "========================================================" -Level "PROGRESS"
    
    $dbPrefix = ($mdbFile.BaseName -replace '\s+', '_' -replace '[^\w]', '') 
    $tables = Get-AccessTables -MdbPath $mdbFile.FullName
    
    Write-Log "Found $($tables.Count) tables" -Level "PROGRESS"
    
    $tableIndex = 0
    foreach ($table in $tables) {
        $tableIndex++
        $sqlTableName = "${dbPrefix}_${table}" -replace '[^\w]', '_'
        
        Write-ProgressBar -Current $tableIndex -Total $tables.Count `
            -Activity "Database $dbIndex/$($mdbFiles.Count): $($mdbFile.Name)" `
            -Status "Table $tableIndex/$($tables.Count): $table"
        
        Write-Host "  [$tableIndex/$($tables.Count)] $table -> $sqlTableName" -NoNewline
        
        try {
            $rowCount = Export-AccessTableToSql `
                -MdbPath $mdbFile.FullName `
                -TableName $table `
                -SqlTableName $sqlTableName `
                -ConnectionString $targetConnectionString `
                -BatchSize 1000 `
                -TimeoutSeconds 7200  # 2 hours max timeout
            
            Write-Host ""
            Write-Log "  ✓ Exported $table -> $sqlTableName ($rowCount rows)" -Level "SUCCESS"
            
            $totalTables++
            $totalRows += $rowCount
            
            $exportSummary += [PSCustomObject]@{
                SourceDatabase = $mdbFile.Name
                SourceTable = $table
                SqlTable = $sqlTableName
                RowCount = $rowCount
                Status = "Success"
            }
        }
        catch {
            Write-Host " [FAILED]" -ForegroundColor Red
            Write-Log "  ❌ FAILED: $table - $_" -Level "ERROR"
            
            $exportSummary += [PSCustomObject]@{
                SourceDatabase = $mdbFile.Name
                SourceTable = $table
                SqlTable = $sqlTableName
                RowCount = 0
                Status = "Failed: $_"
            }
        }
    }
    
    Write-Progress -Activity "Database Export" -Completed
}

# Step 5: Summary
Write-Log "========================================================"
Write-Log "EXPORT COMPLETE"
Write-Log "========================================================"
Write-Log "Total Tables: $totalTables"
Write-Log "Total Rows: $totalRows"
Write-Log "Database: $DatabaseName"
Write-Log "Log File: $logFile"
Write-Log ""

# Export summary to CSV
$summaryFile = Join-Path $logsDir "Export-DmwbToSqlServer_Summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$exportSummary | Export-Csv -Path $summaryFile -NoTypeInformation
Write-Log "Summary exported to: $summaryFile"

# Display connection info
Write-Log ""
Write-Log "CONNECTION STRING:"
Write-Log "Server=$ServerInstance;Database=$DatabaseName;User Id=$SqlUser;Password=$SqlPassword;TrustServerCertificate=True;"
Write-Log ""
Write-Log "To query the data, use:"
Write-Log "  SELECT * FROM [TableName]"
Write-Log ""

# Return summary
return $exportSummary
