# Script to fix duplicate records in PCD tables
# This script truncates the three affected tables and re-imports them with the fixed logic

param(
    [string]$server = "LOCALHOST\SNOMEDCT",
    [string]$database = "SNOMEDCT"
)

Write-Host "=== Fixing Duplicate Records in PCD Tables ==="
Write-Host "Server: $server"
Write-Host "Database: $database"
Write-Host ""

# Define the three affected tables and their source files
$tables = @(
    @{
        table = "PCD_Ruleset_Full_Name_Mappings_V2"
        file = "C:\SNOMEDCT\Downloads\20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt"
    },
    @{
        table = "PCD_Service_Full_Name_Mappings_V2"
        file = "C:\SNOMEDCT\Downloads\20250521_PCD_Service_Full_Name_Mappings_V2.txt"
    },
    @{
        table = "PCD_Output_Descriptions_V2"
        file = "C:\SNOMEDCT\Downloads\20250521_PCD_Output_Descriptions_V2.txt"
    }
)

# Truncate the affected tables
Write-Host "Step 1: Truncating affected tables to remove duplicates..."
foreach ($tableInfo in $tables) {
    $tableName = $tableInfo.table
    Write-Host "  Truncating $tableName..."
    try {
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE $tableName"
        Write-Host "    ✓ $tableName truncated successfully"
    }
    catch {
        Write-Host "    ✗ Error truncating $tableName" $_.Exception.Message
    }
}

Write-Host ""
Write-Host "Step 2: Re-importing data for affected tables..."

# Re-import PCD_Ruleset_Full_Name_Mappings_V2
$table1 = $tables[0]
Write-Host "Importing $($table1.table)..."
if (Test-Path $table1.file) {
    $lines = Get-Content $table1.file | Select-Object -Skip 1
    $totalLines = $lines.Count
    $processedCount = 0
    $errorCount = 0

    Write-Host "  Processing $totalLines lines from $($table1.file)..."

    foreach ($line in $lines) {
        $processedCount++

        try {
            # Parse fields with multiple delimiter support
            $fields = @()
            if ($line -match "`t") {
                $fields = $line -split "`t"
            } elseif ($line -match ",") {
                $fields = $line -split ","
            } else {
                $fields = @($line)
            }

            # Extract field values with proper bounds checking
            $Ruleset_ID = if ($fields.Count -gt 0) { $fields[0].Trim() } else { "" }
            $Ruleset_Short_Name = if ($fields.Count -gt 1) { $fields[1].Trim() } else { $Ruleset_ID }
            $Ruleset_Full_Name = if ($fields.Count -gt 2) { $fields[2].Trim() } else { $Ruleset_Short_Name }

            # Skip rows with empty required fields
            if ([string]::IsNullOrWhiteSpace($Ruleset_ID)) {
                continue
            }            # Insert record
            $query = @"
            INSERT INTO $($table1.table) (Ruleset_ID, Ruleset_Short_Name, Ruleset_Full_Name)
            VALUES (
                '$(($Ruleset_ID) -replace '''', '''''')',
                '$(($Ruleset_Short_Name) -replace '''', '''''')',
                '$(($Ruleset_Full_Name) -replace '''', '''''')'
            )
"@
            Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query

            if ($processedCount % 10 -eq 0) {
                Write-Host "    Processed $processedCount / $totalLines records..."
            }
        }
        catch {
            Write-Host "    Error inserting record $processedCount" $_.Exception.Message
            $errorCount++
        }
    }

    Write-Host "  ✓ $($table1.table) import completed: $processedCount processed, $errorCount errors"
} else {
    Write-Host "  ✗ File not found: $($table1.file)"
}

# Re-import PCD_Service_Full_Name_Mappings_V2
$table2 = $tables[1]
Write-Host "Importing $($table2.table)..."
if (Test-Path $table2.file) {
    $lines = Get-Content $table2.file | Select-Object -Skip 1
    $totalLines = $lines.Count
    $processedCount = 0
    $errorCount = 0

    Write-Host "  Processing $totalLines lines from $($table2.file)..."

    foreach ($line in $lines) {
        $processedCount++

        try {
            # Parse fields with multiple delimiter support
            $fields = @()
            if ($line -match "`t") {
                $fields = $line -split "`t"
            } elseif ($line -match ",") {
                $fields = $line -split ","
            } else {
                $fields = @($line)
            }

            # Extract field values with proper bounds checking
            $Service_ID = if ($fields.Count -gt 0) { $fields[0].Trim() } else { "" }
            $Service_Short_Name = if ($fields.Count -gt 1) { $fields[1].Trim() } else { $Service_ID }
            $Service_Full_Name = if ($fields.Count -gt 2) { $fields[2].Trim() } else { $Service_Short_Name }

            # Skip rows with empty required fields
            if ([string]::IsNullOrWhiteSpace($Service_ID)) {
                continue
            }            # Insert record
            $query = @"
            INSERT INTO $($table2.table) (Service_ID, Service_Short_Name, Service_Full_Name)
            VALUES (
                '$(($Service_ID) -replace '''', '''''')',
                '$(($Service_Short_Name) -replace '''', '''''')',
                '$(($Service_Full_Name) -replace '''', '''''')'
            )
"@
            Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
        }
        catch {
            Write-Host "    Error inserting record $processedCount" $_.Exception.Message
            $errorCount++
        }
    }

    Write-Host "  ✓ $($table2.table) import completed: $processedCount processed, $errorCount errors"
} else {
    Write-Host "  ✗ File not found: $($table2.file)"
}

# Re-import PCD_Output_Descriptions_V2
$table3 = $tables[2]
Write-Host "Importing $($table3.table)..."
if (Test-Path $table3.file) {
    $lines = Get-Content $table3.file | Select-Object -Skip 1
    $totalLines = $lines.Count
    $processedCount = 0
    $errorCount = 0

    Write-Host "  Processing $totalLines lines from $($table3.file)..."

    foreach ($line in $lines) {
        $processedCount++

        try {
            $fields = $line -split "`t", 3
            $Output_ID = $fields[0]
            $Output_Description = $fields[1]
            $Output_Type = $fields[2]

            # Skip rows with empty required fields
            if ([string]::IsNullOrWhiteSpace($Output_ID) -or 
                [string]::IsNullOrWhiteSpace($Output_Description) -or 
                [string]::IsNullOrWhiteSpace($Output_Type)) {
                continue
            }

            # Insert record
            $query = @"
            INSERT INTO $($table3.table) (Output_ID, Output_Description, Output_Type)
            VALUES (
                '$(($Output_ID) -replace '''', '''''')',
                '$(($Output_Description) -replace '''', '''''')',
                '$(($Output_Type) -replace '''', '''''')'
            )
"@
            Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query

            if ($processedCount % 50 -eq 0) {
                Write-Host "    Processed $processedCount / $totalLines records..."
            }        }
        catch {
            Write-Host "    Error inserting record $processedCount" $_.Exception.Message
            $errorCount++
        }
    }

    Write-Host "  ✓ $($table3.table) import completed: $processedCount processed, $errorCount errors"
} else {
    Write-Host "  ✗ File not found: $($table3.file)"
}

Write-Host ""
Write-Host "Step 3: Verification - Checking record counts..."
foreach ($tableInfo in $tables) {
    $tableName = $tableInfo.table
    try {        $result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "SELECT COUNT(*) as RecordCount FROM $tableName"
        Write-Host "  $tableName" $result.RecordCount "records"
    }    catch {
        Write-Host "  Error checking $tableName" $_.Exception.Message
    }
}

Write-Host ""
Write-Host "=== Duplicate Records Fix Completed ==="
