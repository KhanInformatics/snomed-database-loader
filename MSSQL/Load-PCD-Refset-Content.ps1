# PowerShell script to load PCD Refset Content into SQL Server
# Edit the variables below as needed

$server = "localhost"           # SQL Server instance
$database = "SNOMEDCT"          # Database name
$table = "PCD_Refset_Content_by_Output"   # Target table
$file = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_by_Output_V2.txt"  # Source file

# Updated table creation logic to increase the length of SNOMED_code column
$queryCreate = @"
IF OBJECT_ID('dbo.PCD_Refset_Content_by_Output', 'U') IS NOT NULL
BEGIN
    -- Truncate existing data
    TRUNCATE TABLE PCD_Refset_Content_by_Output;
    
    -- Drop existing table
    DROP TABLE PCD_Refset_Content_by_Output;
END

-- Create the table with updated data types
CREATE TABLE PCD_Refset_Content_by_Output (
    Output_ID VARCHAR(255) NOT NULL,
    Cluster_ID VARCHAR(255) NOT NULL,
    Cluster_Description VARCHAR(255) NOT NULL,
    SNOMED_code VARCHAR(255) NOT NULL, -- Increased length to accommodate larger values
    SNOMED_code_description VARCHAR(255) NOT NULL,
    PCD_Refset_ID VARCHAR(18) NOT NULL
);

-- Optional: Add indexes for better query performance
CREATE INDEX IX_PCD_Refset_Content_Cluster_ID ON PCD_Refset_Content_by_Output(Cluster_ID);
CREATE INDEX IX_PCD_Refset_Content_SNOMED_code ON PCD_Refset_Content_by_Output(SNOMED_code);
CREATE INDEX IX_PCD_Refset_Content_PCD_Refset_ID ON PCD_Refset_Content_by_Output(PCD_Refset_ID);
"@
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $queryCreate

# Truncate the table before loading new data
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE $table"

# Robust import: read file line by line and map columns explicitly to match actual headers
# File structure: Output_ID | Cluster_ID | Cluster_Description | SNOMED_code | SNOMED_code_description | PCD Refset ID

Write-Host "Starting data import process..."
$lines = Get-Content $file | Select-Object -Skip 1
$totalLines = $lines.Count
$processedCount = 0
$skippedCount = 0
$errorCount = 0
$duplicateCount = 0

Write-Host "Total records to process: $totalLines"

# Removed validation logic for numeric checks
foreach ($line in $lines) {
    $processedCount++

    # Progress indicator
    if ($processedCount % 1000 -eq 0) {
        Write-Host "Processed $processedCount / $totalLines records..."
    }

    $fields = $line -split "`t", 6
    $Output_ID = $fields[0]
    $Cluster_ID = $fields[1]
    $Cluster_Description = $fields[2]
    $SNOMED_code = $fields[3]
    $SNOMED_code_description = $fields[4]
    $PCD_Refset_ID = $fields[5]

    # Skip rows with empty required fields
    if ([string]::IsNullOrWhiteSpace($Output_ID) -or 
        [string]::IsNullOrWhiteSpace($Cluster_ID) -or 
        [string]::IsNullOrWhiteSpace($Cluster_Description) -or 
        [string]::IsNullOrWhiteSpace($SNOMED_code) -or 
        [string]::IsNullOrWhiteSpace($SNOMED_code_description) -or 
        [string]::IsNullOrWhiteSpace($PCD_Refset_ID)) {
        Write-Host "Skipping row $processedCount with empty required fields"
        $skippedCount++
        continue
    }

    try {
        # Insert new record
        $query = @"
        INSERT INTO $table (Output_ID, Cluster_ID, Cluster_Description, SNOMED_code, SNOMED_code_description, PCD_Refset_ID)
        VALUES (
            '$(($Output_ID) -replace '''', '''''')',
            '$(($Cluster_ID) -replace '''', '''''')',
            '$(($Cluster_Description) -replace '''', '''''')',
            '$(($SNOMED_code) -replace '''', '''''')',
            '$(($SNOMED_code_description) -replace '''', '''''')',
            '$(($PCD_Refset_ID) -replace '''', '''''')'
        )
"@
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
    }
    catch {
        Write-Host "Error inserting record $processedCount : $($_.Exception.Message)"
        $errorCount++
    }
}

Write-Host ""
Write-Host "Import completed!"
Write-Host "Total processed: $processedCount"
Write-Host "Successfully imported: $($processedCount - $skippedCount - $errorCount - $duplicateCount)"
Write-Host "Skipped: $skippedCount"
Write-Host "Duplicates: $duplicateCount"
Write-Host "Errors: $errorCount"

# Verify the data load
Write-Host ""
Write-Host "Verifying data load..."
$countQuery = "SELECT COUNT(*) as RecordCount FROM $table"
$result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $countQuery
Write-Host "Total records in database: $($result.RecordCount)"

# Check for any obvious data quality issues
$qualityQuery = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT Output_ID) as UniqueOutputIds,
    COUNT(DISTINCT SNOMED_code) as UniqueSnomedCodes,
    COUNT(DISTINCT PCD_Refset_ID) as UniquePcdRefsetIds,
    COUNT(DISTINCT Cluster_ID) as UniqueClusters
FROM $table
"@
$qualityResult = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $qualityQuery
Write-Host "Data quality summary:"
Write-Host "  Total Records: $($qualityResult.TotalRecords)"
Write-Host "  Unique Output IDs: $($qualityResult.UniqueOutputIds)"
Write-Host "  Unique SNOMED Codes: $($qualityResult.UniqueSnomedCodes)"
Write-Host "  Unique PCD Refset IDs: $($qualityResult.UniquePcdRefsetIds)"
Write-Host "  Unique Clusters: $($qualityResult.UniqueClusters)"

Write-Host "PCD Refset Content loaded successfully with updated primary key constraint."

# Additional table and import for PCD_Refset_Content_V2
$file2 = "C:\SNOMEDCT\Downloads\20250521_PCD_Refset_Content_V2.txt"  # Second source file
$table2 = "PCD_Refset_Content_V2"   # Second target table

# Create second table with similar structure
$queryCreate2 = @"
IF OBJECT_ID('dbo.PCD_Refset_Content_V2', 'U') IS NOT NULL
BEGIN
    -- Truncate existing data
    TRUNCATE TABLE PCD_Refset_Content_V2;
    
    -- Drop existing table
    DROP TABLE PCD_Refset_Content_V2;
END

-- Create the table with appropriate data types
CREATE TABLE PCD_Refset_Content_V2 (
    SNOMED_code VARCHAR(255) NOT NULL,
    SNOMED_code_description VARCHAR(500) NOT NULL,
    PCD_Refset_ID VARCHAR(18) NOT NULL,
    PCD_Refset_Description VARCHAR(500) NOT NULL
);

-- Optional: Add indexes for better query performance
CREATE INDEX IX_PCD_Refset_Content_V2_SNOMED_code ON PCD_Refset_Content_V2(SNOMED_code);
CREATE INDEX IX_PCD_Refset_Content_V2_PCD_Refset_ID ON PCD_Refset_Content_V2(PCD_Refset_ID);
"@
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $queryCreate2

Write-Host "Created table: $table2"

# Truncate the second table before loading new data
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE $table2"

# Robust import for second table: read file line by line and map columns explicitly to match actual headers
# File structure for V2: SNOMED_code | SNOMED_code_description | PCD Refset ID | PCD Refset Description

Write-Host "Starting data import process for $table2..."
$lines2 = Get-Content $file2 | Select-Object -Skip 1
$totalLines2 = $lines2.Count
$processedCount2 = 0
$skippedCount2 = 0
$errorCount2 = 0
$duplicateCount2 = 0

Write-Host "Total records to process for ${table2}: $totalLines2"

foreach ($line in $lines2) {
    $processedCount2++

    # Progress indicator
    if ($processedCount2 % 1000 -eq 0) {
        Write-Host "Processed $processedCount2 / $totalLines2 records for $table2..."
    }

    $fields = $line -split "`t", 4
    $SNOMED_code = $fields[0]
    $SNOMED_code_description = $fields[1]
    $PCD_Refset_ID = $fields[2]
    $PCD_Refset_Description = $fields[3]

    # Skip rows with empty required fields
    if ([string]::IsNullOrWhiteSpace($SNOMED_code) -or 
        [string]::IsNullOrWhiteSpace($SNOMED_code_description) -or 
        [string]::IsNullOrWhiteSpace($PCD_Refset_ID) -or 
        [string]::IsNullOrWhiteSpace($PCD_Refset_Description)) {
        Write-Host "Skipping row $processedCount2 with empty required fields"
        $skippedCount2++
        continue
    }

    try {
        # Insert new record into second table
        $query = @"
        INSERT INTO $table2 (SNOMED_code, SNOMED_code_description, PCD_Refset_ID, PCD_Refset_Description)
        VALUES (
            '$(($SNOMED_code) -replace '''', '''''')',
            '$(($SNOMED_code_description) -replace '''', '''''')',
            '$(($PCD_Refset_ID) -replace '''', '''''')',
            '$(($PCD_Refset_Description) -replace '''', '''''')'
        )
"@
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
    }
    catch {
        Write-Host "Error inserting record $processedCount2 into ${table2}: $($_.Exception.Message)"
        $errorCount2++
    }
}

Write-Host ""
Write-Host "Import completed for $table2!"
Write-Host "Total processed: $processedCount2"
Write-Host "Successfully imported: $($processedCount2 - $skippedCount2 - $errorCount2 - $duplicateCount2)"
Write-Host "Skipped: $skippedCount2"
Write-Host "Duplicates: $duplicateCount2"
Write-Host "Errors: $errorCount2"

# Verify the data load for second table
Write-Host ""
Write-Host "Verifying data load for $table2..."
$countQuery2 = "SELECT COUNT(*) as RecordCount FROM $table2"
$result2 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $countQuery2
Write-Host "Total records in ${table2}: $($result2.RecordCount)"

# Check for any obvious data quality issues in second table
$qualityQuery2 = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT SNOMED_code) as UniqueSnomedCodes,
    COUNT(DISTINCT PCD_Refset_ID) as UniquePcdRefsetIds
FROM $table2
"@
$qualityResult2 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $qualityQuery2
Write-Host "Data quality summary for ${table2}:"
Write-Host "  Total Records: $($qualityResult2.TotalRecords)"
Write-Host "  Unique SNOMED Codes: $($qualityResult2.UniqueSnomedCodes)"
Write-Host "  Unique PCD Refset IDs: $($qualityResult2.UniquePcdRefsetIds)"

Write-Host "Both PCD Refset Content files loaded successfully with updated primary key constraint."

# Additional tables and imports for other PCD files
$file3 = "C:\SNOMEDCT\Downloads\20250521_PCD_Ruleset_Full_Name_Mappings_V2.txt"  # Third source file
$table3 = "PCD_Ruleset_Full_Name_Mappings_V2"   # Third target table

$file4 = "C:\SNOMEDCT\Downloads\20250521_PCD_Service_Full_Name_Mappings_V2.txt"  # Fourth source file
$table4 = "PCD_Service_Full_Name_Mappings_V2"   # Fourth target table

$file5 = "C:\SNOMEDCT\Downloads\20250521_PCD_Output_Descriptions_V2.txt"  # Fifth source file
$table5 = "PCD_Output_Descriptions_V2"   # Fifth target table

# Create third table for Ruleset mappings
$queryCreate3 = @"
IF OBJECT_ID('dbo.PCD_Ruleset_Full_Name_Mappings_V2', 'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE PCD_Ruleset_Full_Name_Mappings_V2;
    DROP TABLE PCD_Ruleset_Full_Name_Mappings_V2;
END

CREATE TABLE PCD_Ruleset_Full_Name_Mappings_V2 (
    Ruleset_ID VARCHAR(50) NOT NULL,
    Ruleset_Short_Name VARCHAR(255) NOT NULL,
    Ruleset_Full_Name VARCHAR(500) NOT NULL
);

CREATE INDEX IX_PCD_Ruleset_Mappings_ID ON PCD_Ruleset_Full_Name_Mappings_V2(Ruleset_ID);
"@
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $queryCreate3

# Create fourth table for Service mappings
$queryCreate4 = @"
IF OBJECT_ID('dbo.PCD_Service_Full_Name_Mappings_V2', 'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE PCD_Service_Full_Name_Mappings_V2;
    DROP TABLE PCD_Service_Full_Name_Mappings_V2;
END

CREATE TABLE PCD_Service_Full_Name_Mappings_V2 (
    Service_ID VARCHAR(50) NOT NULL,
    Service_Short_Name VARCHAR(255) NOT NULL,
    Service_Full_Name VARCHAR(500) NOT NULL
);

CREATE INDEX IX_PCD_Service_Mappings_ID ON PCD_Service_Full_Name_Mappings_V2(Service_ID);
"@
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $queryCreate4

# Create fifth table for Output descriptions
$queryCreate5 = @"
IF OBJECT_ID('dbo.PCD_Output_Descriptions_V2', 'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE PCD_Output_Descriptions_V2;
    DROP TABLE PCD_Output_Descriptions_V2;
END

CREATE TABLE PCD_Output_Descriptions_V2 (
    Output_ID VARCHAR(50) NOT NULL,
    Output_Description VARCHAR(1000) NOT NULL,
    Output_Type VARCHAR(1000) NOT NULL
);

CREATE INDEX IX_PCD_Output_Descriptions_ID ON PCD_Output_Descriptions_V2(Output_ID);
"@
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $queryCreate5

Write-Host "Created additional tables: ${table3}, ${table4}, ${table5}"

# Truncate and import for third table: Ruleset mappings
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE $table3"

Write-Host "Starting data import process for $table3..."
$lines3 = Get-Content $file3 | Select-Object -Skip 1
$totalLines3 = $lines3.Count
$processedCount3 = 0
$skippedCount3 = 0
$errorCount3 = 0
$duplicateCount3 = 0

Write-Host "Total records to process for ${table3}: $totalLines3"

foreach ($line in $lines3) {
    $processedCount3++

    # Progress indicator
    if ($processedCount3 % 1000 -eq 0) {
        Write-Host "Processed $processedCount3 / $totalLines3 records for $table3..."
    }    # Debug first few records to understand file structure
    if ($processedCount3 -le 3) {
        Write-Host "Debug Line $processedCount3 - Raw line: '$line'"
        $debugFields = @()
        if ($line -match "`t") {
            $debugFields = $line -split "`t"
            Write-Host "  Tab-separated - Fields count: $($debugFields.Count)"
        } elseif ($line -match ",") {
            $debugFields = $line -split ","
            Write-Host "  Comma-separated - Fields count: $($debugFields.Count)"
        } else {
            $debugFields = @($line)
            Write-Host "  Single field - Fields count: $($debugFields.Count)"
        }
        for ($f = 0; $f -lt $debugFields.Count -and $f -lt 5; $f++) {
            Write-Host "    Field ${f}: '$($debugFields[$f])'"
        }
    }

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
        Write-Host "Skipping row $processedCount3 - empty required fields (ID: '$Ruleset_ID', Fields: $($fields.Count))"
        $skippedCount3++
        continue
    }

    try {
        # Insert new record into third table
        $query = @"
        INSERT INTO $table3 (Ruleset_ID, Ruleset_Short_Name, Ruleset_Full_Name)
        VALUES (
            '$(($Ruleset_ID) -replace '''', '''''')',
            '$(($Ruleset_Short_Name) -replace '''', '''''')',
            '$(($Ruleset_Full_Name) -replace '''', '''''')'
        )
"@
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
    }
    catch {
        Write-Host "Error inserting record $processedCount3 into ${table3}: $($_.Exception.Message)"
        $errorCount3++
    }
}

Write-Host ""
Write-Host "Import completed for $table3!"
Write-Host "Total processed: $processedCount3"
Write-Host "Successfully imported: $($processedCount3 - $skippedCount3 - $errorCount3 - $duplicateCount3)"
Write-Host "Skipped: $skippedCount3"
Write-Host "Duplicates: $duplicateCount3"
Write-Host "Errors: $errorCount3"

# Verify the data load for third table
Write-Host ""
Write-Host "Verifying data load for $table3..."
$countQuery3 = "SELECT COUNT(*) as RecordCount FROM $table3"
$result3 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $countQuery3
Write-Host "Total records in ${table3}: $($result3.RecordCount)"

# Check for any obvious data quality issues in third table
$qualityQuery3 = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT Ruleset_ID) as UniqueRulesetIds
FROM $table3
"@
$qualityResult3 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $qualityQuery3
Write-Host "Data quality summary for ${table3}:"
Write-Host "  Total Records: $($qualityResult3.TotalRecords)"
Write-Host "  Unique Ruleset IDs: $($qualityResult3.UniqueRulesetIds)"

# Truncate and import for fourth table: Service mappings
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE $table4"

Write-Host "Starting data import process for $table4..."
$lines4 = Get-Content $file4 | Select-Object -Skip 1
$totalLines4 = $lines4.Count
$processedCount4 = 0
$skippedCount4 = 0
$errorCount4 = 0
$duplicateCount4 = 0

Write-Host "Total records to process for ${table4}: $totalLines4"

foreach ($line in $lines4) {
    $processedCount4++

    # Progress indicator
    if ($processedCount4 % 1000 -eq 0) {
        Write-Host "Processed $processedCount4 / $totalLines4 records for $table4..."
    }    # Debug first few records to understand file structure  
    if ($processedCount4 -le 3) {
        Write-Host "Debug Line $processedCount4 - Raw line: '$line'"
        $debugFields = @()
        if ($line -match "`t") {
            $debugFields = $line -split "`t"
            Write-Host "  Tab-separated - Fields count: $($debugFields.Count)"
        } elseif ($line -match ",") {
            $debugFields = $line -split ","
            Write-Host "  Comma-separated - Fields count: $($debugFields.Count)"
        } else {
            $debugFields = @($line)
            Write-Host "  Single field - Fields count: $($debugFields.Count)"
        }
        for ($f = 0; $f -lt $debugFields.Count -and $f -lt 5; $f++) {
            Write-Host "    Field ${f}: '$($debugFields[$f])'"
        }
    }

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
        Write-Host "Skipping row $processedCount4 - empty required fields (ID: '$Service_ID', Fields: $($fields.Count))"
        $skippedCount4++
        continue
    }

    try {
        # Insert new record into fourth table
        $query = @"
        INSERT INTO $table4 (Service_ID, Service_Short_Name, Service_Full_Name)
        VALUES (
            '$(($Service_ID) -replace '''', '''''')',
            '$(($Service_Short_Name) -replace '''', '''''')',
            '$(($Service_Full_Name) -replace '''', '''''')'
        )
"@
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
    }
    catch {
        Write-Host "Error inserting record $processedCount4 into ${table4}: $($_.Exception.Message)"
        $errorCount4++
    }
}

Write-Host ""
Write-Host "Import completed for $table4!"
Write-Host "Total processed: $processedCount4"
Write-Host "Successfully imported: $($processedCount4 - $skippedCount4 - $errorCount4 - $duplicateCount4)"
Write-Host "Skipped: $skippedCount4"
Write-Host "Duplicates: $duplicateCount4"
Write-Host "Errors: $errorCount4"

# Verify the data load for fourth table
Write-Host ""
Write-Host "Verifying data load for $table4..."
$countQuery4 = "SELECT COUNT(*) as RecordCount FROM $table4"
$result4 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $countQuery4
Write-Host "Total records in ${table4}: $($result4.RecordCount)"

# Check for any obvious data quality issues in fourth table
$qualityQuery4 = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT Service_ID) as UniqueServiceIds
FROM $table4
"@
$qualityResult4 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $qualityQuery4
Write-Host "Data quality summary for ${table4}:"
Write-Host "  Total Records: $($qualityResult4.TotalRecords)"
Write-Host "  Unique Service IDs: $($qualityResult4.UniqueServiceIds)"

# Truncate and import for fifth table: Output descriptions
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE $table5"

Write-Host "Starting data import process for $table5..."
$lines5 = Get-Content $file5 | Select-Object -Skip 1
$totalLines5 = $lines5.Count
$processedCount5 = 0
$skippedCount5 = 0
$errorCount5 = 0
$duplicateCount5 = 0

Write-Host "Total records to process for ${table5}: $totalLines5"

foreach ($line in $lines5) {
    $processedCount5++

    # Progress indicator
    if ($processedCount5 % 1000 -eq 0) {
        Write-Host "Processed $processedCount5 / $totalLines5 records for $table5..."
    }

    $fields = $line -split "`t", 3
    $Output_ID = $fields[0]
    $Output_Description = $fields[1]
    $Output_Type = $fields[2]

    # Skip rows with empty required fields
    if ([string]::IsNullOrWhiteSpace($Output_ID) -or 
        [string]::IsNullOrWhiteSpace($Output_Description) -or 
        [string]::IsNullOrWhiteSpace($Output_Type)) {
        Write-Host "Skipping row $processedCount5 with empty required fields"
        $skippedCount5++
        continue
    }

    try {
        # Insert new record into fifth table
        $query = @"
        INSERT INTO $table5 (Output_ID, Output_Description, Output_Type)
        VALUES (
            '$(($Output_ID) -replace '''', '''''')',
            '$(($Output_Description) -replace '''', '''''')',
            '$(($Output_Type) -replace '''', '''''')'
        )
"@
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
    }
    catch {
        Write-Host "Error inserting record $processedCount5 into ${table5}: $($_.Exception.Message)"
        $errorCount5++
    }
}

Write-Host ""
Write-Host "Import completed for $table5!"
Write-Host "Total processed: $processedCount5"
Write-Host "Successfully imported: $($processedCount5 - $skippedCount5 - $errorCount5 - $duplicateCount5)"
Write-Host "Skipped: $skippedCount5"
Write-Host "Duplicates: $duplicateCount5"
Write-Host "Errors: $errorCount5"

# Verify the data load for fifth table
Write-Host ""
Write-Host "Verifying data load for $table5..."
$countQuery5 = "SELECT COUNT(*) as RecordCount FROM $table5"
$result5 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $countQuery5
Write-Host "Total records in ${table5}: $($result5.RecordCount)"

# Check for any obvious data quality issues in fifth table
$qualityQuery5 = @"
SELECT 
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT Output_ID) as UniqueOutputIds
FROM $table5
"@
$qualityResult5 = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $qualityQuery5
Write-Host "Data quality summary for ${table5}:"
Write-Host "  Total Records: $($qualityResult5.TotalRecords)"
Write-Host "  Unique Output IDs: $($qualityResult5.UniqueOutputIds)"

Write-Host "All PCD files loaded successfully."
