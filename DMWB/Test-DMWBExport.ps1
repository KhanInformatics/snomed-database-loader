<#
.SYNOPSIS
    Validates DMWB data integrity between Access databases and SQL Server export.

.DESCRIPTION
    Compares row counts, field values, and specific mappings between the original 
    DMWB Access databases and the exported SQL Server database to verify data integrity.

.PARAMETER ServerInstance
    SQL Server instance (default: localhost\SQLEXPRESS)

.PARAMETER DatabaseName
    SQL Server database name (default: DMWB_Export)

.PARAMETER SourcePath
    Path to DMWB folder with .mdb files (default: C:\DMWB\CurrentReleases)

.PARAMETER SqlUser
    SQL Server username (default: sa)

.PARAMETER SqlPassword
    SQL Server password (default: redfive5)

.EXAMPLE
    .\Test-DMWBExport.ps1

.EXAMPLE
    .\Test-DMWBExport.ps1 -SourcePath "C:\DMWB\CurrentReleases\nhs_dmwb_41.2.0_20251119000001"
#>

[CmdletBinding()]
param(
    [string]$ServerInstance = "localhost\SQLEXPRESS",
    [string]$DatabaseName = "DMWB_Export",
    [string]$SourcePath = "C:\DMWB\CurrentReleases",
    [string]$SqlUser = "sa",
    [string]$SqlPassword = "redfive5"
)

$ErrorActionPreference = "Continue"

# Test results
$testResults = @()
$passCount = 0
$failCount = 0
$warnCount = 0

# Ensure logs directory exists
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Output files
$reportFile = Join-Path $logsDir "Test-DMWBExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$logFile = Join-Path $logsDir "Test-DMWBExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $color = switch($Level) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $logFile -Value $logMessage
}

function Add-TestResult {
    param(
        [string]$Category,
        [string]$TestName,
        [string]$Status,
        [string]$Expected,
        [string]$Actual,
        [string]$Details = ""
    )
    
    $script:testResults += [PSCustomObject]@{
        Category = $Category
        Test = $TestName
        Status = $Status
        Expected = $Expected
        Actual = $Actual
        Details = $Details
    }
    
    switch($Status) {
        "PASS" { $script:passCount++ }
        "FAIL" { $script:failCount++ }
        "WARN" { $script:warnCount++ }
    }
}

function Get-AccessRowCount {
    param([string]$MdbPath, [string]$TableName)
    
    $connection = New-Object -ComObject ADODB.Connection
    $recordset = New-Object -ComObject ADODB.Recordset
    
    try {
        $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$MdbPath;"
        $connection.Open($connectionString)
        $recordset.Open("SELECT COUNT(*) FROM [$TableName]", $connection, 3, 1)
        $count = $recordset.Fields.Item(0).Value
        $recordset.Close()
        return $count
    }
    catch {
        Write-Log "Error reading $TableName from $MdbPath : $_" -Level "ERROR"
        return -1
    }
    finally {
        if ($recordset.State -eq 1) { $recordset.Close() }
        if ($connection.State -eq 1) { $connection.Close() }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($recordset) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($connection) | Out-Null
    }
}

function Get-SqlRowCount {
    param([string]$ConnectionString, [string]$TableName)
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT COUNT(*) FROM [$TableName]"
        return $command.ExecuteScalar()
    }
    catch {
        Write-Log "Error reading $TableName from SQL: $_" -Level "ERROR"
        return -1
    }
    finally {
        if ($connection.State -eq 'Open') { $connection.Close() }
        $connection.Dispose()
    }
}

function Test-TableRowCounts {
    param([string]$MdbPath, [string]$MdbFileName, [string]$SqlConnectionString)
    
    Write-Log "Testing: $MdbFileName"
    
    # Get Access tables
    $connection = New-Object -ComObject ADODB.Connection
    try {
        $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$MdbPath;"
        $connection.Open($connectionString)
        
        $catalog = $connection.OpenSchema(20)
        $tables = @()
        
        while (-not $catalog.EOF) {
            $tableType = $catalog.Fields.Item("TABLE_TYPE").Value
            $tableName = $catalog.Fields.Item("TABLE_NAME").Value
            
            if ($tableType -eq "TABLE" -and $tableName -notmatch "^(MSys|USys)") {
                $tables += $tableName
            }
            $catalog.MoveNext()
        }
        $catalog.Close()
    }
    finally {
        if ($connection.State -eq 1) { $connection.Close() }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($connection) | Out-Null
    }
    
    # Compare each table
    foreach ($table in $tables) {
        $dbPrefix = ($MdbFileName -replace '\.mdb$', '' -replace '\s+', '_' -replace '[^\w]', '')
        $sqlTableName = "${dbPrefix}_${table}" -replace '[^\w]', '_'
        
        $accessCount = Get-AccessRowCount -MdbPath $MdbPath -TableName $table
        $sqlCount = Get-SqlRowCount -ConnectionString $SqlConnectionString -TableName $sqlTableName
        
        if ($accessCount -eq -1 -or $sqlCount -eq -1) {
            Add-TestResult -Category "Row Counts" -TestName "$MdbFileName :: $table" `
                -Status "FAIL" -Expected "Valid counts" -Actual "Error"
            Write-Log "  ❌ $table - Error reading counts" -Level "FAIL"
        }
        elseif ($accessCount -eq $sqlCount) {
            Add-TestResult -Category "Row Counts" -TestName "$MdbFileName :: $table" `
                -Status "PASS" -Expected "$accessCount rows" -Actual "$sqlCount rows"
            Write-Log "  ✓ $table - $accessCount rows" -Level "PASS"
        }
        else {
            Add-TestResult -Category "Row Counts" -TestName "$MdbFileName :: $table" `
                -Status "FAIL" -Expected "$accessCount rows" -Actual "$sqlCount rows" `
                -Details "Mismatch"
            Write-Log "  ❌ $table - Access: $accessCount, SQL: $sqlCount" -Level "FAIL"
        }
    }
}

function Test-SpecificMappings {
    param([string]$SqlConnectionString)
    
    Write-Log "`nTesting specific known mappings..."
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($SqlConnectionString)
    
    $testCases = @(
        @{ ReadCode = 'G58..'; ExpectedConcept = '84114007'; Description = 'Heart failure' }
        @{ ReadCode = 'C10..'; ExpectedConcept = '73211009'; Description = 'Diabetes mellitus' }
        @{ ReadCode = 'G30..'; ExpectedConcept = '57054005'; Description = 'Acute myocardial infarction' }
        @{ ReadCode = 'G802.'; ExpectedConcept = '266267005'; Description = 'Deep vein phlebitis of leg' }
    )
    
    try {
        $connection.Open()
        
        foreach ($test in $testCases) {
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT TCUI FROM DMWB_NHS_Data_Migration_Maps_RCTSCTMAP WHERE SCUI = @code"
            $command.Parameters.AddWithValue("@code", $test.ReadCode) | Out-Null
            
            $result = $command.ExecuteScalar()
            
            if ($null -eq $result) {
                Add-TestResult -Category "Known Mappings" -TestName "Read Code $($test.ReadCode)" `
                    -Status "WARN" -Expected $test.ExpectedConcept -Actual "Not found" `
                    -Details $test.Description
                Write-Log "  ⚠️  $($test.ReadCode) not found" -Level "WARN"
            }
            elseif ($result -eq $test.ExpectedConcept) {
                Add-TestResult -Category "Known Mappings" -TestName "Read Code $($test.ReadCode)" `
                    -Status "PASS" -Expected $test.ExpectedConcept -Actual $result `
                    -Details $test.Description
                Write-Log "  ✓ $($test.ReadCode) → $result" -Level "PASS"
            }
            else {
                Add-TestResult -Category "Known Mappings" -TestName "Read Code $($test.ReadCode)" `
                    -Status "FAIL" -Expected $test.ExpectedConcept -Actual $result `
                    -Details $test.Description
                Write-Log "  ❌ $($test.ReadCode) mismatch: expected $($test.ExpectedConcept), got $result" -Level "FAIL"
            }
        }
    }
    finally {
        if ($connection.State -eq 'Open') { $connection.Close() }
        $connection.Dispose()
    }
}

function Test-Relationships {
    param([string]$SqlConnectionString)
    
    Write-Log "`nTesting hierarchical relationships..."
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($SqlConnectionString)
    
    try {
        $connection.Open()
        
        # Test Diabetes Mellitus children count
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT COUNT(*) FROM DMWB_NHS_SNOMED_SCTHIER WHERE PARENT = '73211009'"
        $childCount = $command.ExecuteScalar()
        
        if ($childCount -gt 0) {
            Add-TestResult -Category "Relationships" -TestName "Diabetes Mellitus Children" `
                -Status "PASS" -Expected ">0 children" -Actual "$childCount children"
            Write-Log "  ✓ Diabetes has $childCount children" -Level "PASS"
        }
        else {
            Add-TestResult -Category "Relationships" -TestName "Diabetes Mellitus Children" `
                -Status "FAIL" -Expected ">0 children" -Actual "0 children"
            Write-Log "  ❌ Diabetes has no children" -Level "FAIL"
        }
    }
    finally {
        if ($connection.State -eq 'Open') { $connection.Close() }
        $connection.Dispose()
    }
}

function Test-TableCounts {
    param([string]$SqlConnectionString)
    
    Write-Log "`nTesting overall table counts..."
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($SqlConnectionString)
    
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"
        $tableCount = $command.ExecuteScalar()
        
        $expectedMin = 40  # Should have at least 40 tables
        
        if ($tableCount -ge $expectedMin) {
            Add-TestResult -Category "Database Structure" -TestName "Table Count" `
                -Status "PASS" -Expected ">=$expectedMin tables" -Actual "$tableCount tables"
            Write-Log "  ✓ Database has $tableCount tables" -Level "PASS"
        }
        else {
            Add-TestResult -Category "Database Structure" -TestName "Table Count" `
                -Status "FAIL" -Expected ">=$expectedMin tables" -Actual "$tableCount tables"
            Write-Log "  ❌ Only $tableCount tables found" -Level "FAIL"
        }
    }
    finally {
        if ($connection.State -eq 'Open') { $connection.Close() }
        $connection.Dispose()
    }
}

function Generate-HtmlReport {
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>DMWB Export Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #0078d4; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary-stats { display: flex; justify-content: space-around; margin-top: 15px; }
        .stat { text-align: center; }
        .stat-value { font-size: 36px; font-weight: bold; }
        .stat-label { color: #666; margin-top: 5px; }
        .pass { color: #107c10; }
        .fail { color: #d13438; }
        .warn { color: #ff8c00; }
        table { width: 100%; border-collapse: collapse; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        th { background: #f0f0f0; padding: 12px; text-align: left; font-weight: 600; border-bottom: 2px solid #ddd; }
        td { padding: 10px; border-bottom: 1px solid #eee; }
        tr:hover { background: #f9f9f9; }
        .status-badge { padding: 4px 12px; border-radius: 12px; font-weight: 600; font-size: 11px; }
        .badge-pass { background: #dff6dd; color: #107c10; }
        .badge-fail { background: #fde7e9; color: #d13438; }
        .badge-warn { background: #fff4ce; color: #8a6300; }
        .category-section { background: white; padding: 15px; border-radius: 5px; margin-bottom: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .category-header { font-size: 18px; font-weight: 600; margin-bottom: 10px; color: #333; }
    </style>
</head>
<body>
    <div class="header">
        <h1>DMWB Export Test Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Database: $DatabaseName @ $ServerInstance</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <div class="summary-stats">
            <div class="stat">
                <div class="stat-value pass">$passCount</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat">
                <div class="stat-value fail">$failCount</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat">
                <div class="stat-value warn">$warnCount</div>
                <div class="stat-label">Warnings</div>
            </div>
            <div class="stat">
                <div class="stat-value">$($testResults.Count)</div>
                <div class="stat-label">Total Tests</div>
            </div>
        </div>
    </div>
"@
    
    $categories = $testResults | Group-Object -Property Category
    
    foreach ($category in $categories) {
        $html += @"
    <div class="category-section">
        <div class="category-header">$($category.Name)</div>
        <table>
            <thead>
                <tr>
                    <th>Test</th>
                    <th>Status</th>
                    <th>Expected</th>
                    <th>Actual</th>
                    <th>Details</th>
                </tr>
            </thead>
            <tbody>
"@
        
        foreach ($test in $category.Group) {
            $badgeClass = switch($test.Status) {
                "PASS" { "badge-pass" }
                "FAIL" { "badge-fail" }
                "WARN" { "badge-warn" }
            }
            
            $html += @"
                <tr>
                    <td>$($test.Test)</td>
                    <td><span class="status-badge $badgeClass">$($test.Status)</span></td>
                    <td>$($test.Expected)</td>
                    <td>$($test.Actual)</td>
                    <td>$($test.Details)</td>
                </tr>
"@
        }
        
        $html += @"
            </tbody>
        </table>
    </div>
"@
    }
    
    $html += @"
    <div style="text-align: center; color: #666; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;">
        <p>DMWB Export Validation - $(Get-Date -Format 'yyyy-MM-dd')</p>
        <p>Log: $logFile</p>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $reportFile -Encoding UTF8
}

# ============================================================================
# MAIN
# ============================================================================

Write-Log "========================================================"
Write-Log "DMWB Export Validation Test Suite"
Write-Log "========================================================"
Write-Log "SQL Server: $ServerInstance"
Write-Log "Database: $DatabaseName"
Write-Log "Source: $SourcePath"
Write-Log ""

$sqlConnectionString = "Server=$ServerInstance;Database=$DatabaseName;User Id=$SqlUser;Password=$SqlPassword;TrustServerCertificate=True;"

# Find all .mdb files
$mdbFiles = Get-ChildItem -Path $SourcePath -Filter "*.mdb" -File -Recurse | 
    Where-Object { $_.Name -notmatch "^~" -and $_.Name -notmatch "^(EPR Data|User Data|User Cluster)" }

if ($mdbFiles.Count -eq 0) {
    Write-Log "No .mdb files found in $SourcePath" -Level "ERROR"
    exit 1
}

Write-Log "Found $($mdbFiles.Count) Access database files"
Write-Log ""

# Test 1: Database structure
Test-TableCounts -SqlConnectionString $sqlConnectionString

# Test 2: Row counts for each database
foreach ($mdbFile in $mdbFiles) {
    Test-TableRowCounts -MdbPath $mdbFile.FullName -MdbFileName $mdbFile.Name -SqlConnectionString $sqlConnectionString
}

# Test 3: Specific known mappings
Test-SpecificMappings -SqlConnectionString $sqlConnectionString

# Test 4: Hierarchical relationships
Test-Relationships -SqlConnectionString $sqlConnectionString

# Generate report
Write-Log ""
Write-Log "========================================================"
Write-Log "TEST SUMMARY"
Write-Log "========================================================"
Write-Log "Passed:   $passCount" -Level "PASS"
Write-Log "Failed:   $failCount" -Level $(if($failCount -gt 0){"FAIL"}else{"INFO"})
Write-Log "Warnings: $warnCount" -Level $(if($warnCount -gt 0){"WARN"}else{"INFO"})
Write-Log "Total:    $($testResults.Count)"
Write-Log ""

Generate-HtmlReport

Write-Log "HTML Report: $reportFile"
Write-Log "Log File: $logFile"
Write-Log ""

if ($failCount -eq 0) {
    Write-Log "✓ All tests passed!" -Level "PASS"
    exit 0
}
else {
    Write-Log "❌ $failCount test(s) failed" -Level "FAIL"
    exit 1
}
