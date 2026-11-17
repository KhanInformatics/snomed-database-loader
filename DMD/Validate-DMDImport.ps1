# Validate DM+D Data Import
# Save this as Validate-DMDImport.ps1

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [string]$XmlPath
)

Write-Host "=== DM+D Import Validation ===" -ForegroundColor Cyan
Write-Host "Server: $ServerInstance"
Write-Host "Database: $Database"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Function to execute SQL and return results
function Invoke-SqlQuery {
    param(
        [string]$Query,
        [string]$Server = $ServerInstance,
        [string]$DB = $Database
    )
    
    try {
        $result = Invoke-Sqlcmd -ServerInstance $Server -Database $DB -Query $Query -TrustServerCertificate -ErrorAction Stop
        return $result
    } catch {
        throw "SQL validation query failed: $($_.Exception.Message)"
    }
}

# Test database connection
Write-Host "`n🔍 Testing database connection..." -ForegroundColor Yellow
$connectionTest = Invoke-SqlQuery "SELECT COUNT(*) as test FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'vtm'"

if ($null -eq $connectionTest) {
    Write-Error "❌ Cannot connect to database $Database on $ServerInstance"
    exit 1
} 

if ($connectionTest.test -eq 0) {
    Write-Error "❌ DM+D tables not found. Please run create-database-dmd.sql first."
    exit 1
}

Write-Host "✅ Database connection successful" -ForegroundColor Green

# Pricing is required. Report zero and missing amounts separately.
$priceCounts = Invoke-SqlQuery @"
SELECT 'ampp_price' AS Entity, COUNT(*) AS Total_Records,
    COUNT(price) AS With_Price, COUNT(CASE WHEN price > 0 THEN 1 END) AS Positive_Price,
    COUNT(CASE WHEN price = 0 THEN 1 END) AS Zero_Price,
    COUNT(CASE WHEN price IS NULL THEN 1 END) AS Missing_Price FROM dbo.ampp_price
UNION ALL
SELECT 'vmpp_drugtariffinfo', COUNT(*), COUNT(price),
    COUNT(CASE WHEN price > 0 THEN 1 END), COUNT(CASE WHEN price = 0 THEN 1 END),
    COUNT(CASE WHEN price IS NULL THEN 1 END) FROM dbo.vmpp_drugtariffinfo;
"@
$priceCounts | Format-Table -AutoSize
if (@($priceCounts | Where-Object { $_.Total_Records -eq 0 }).Count -gt 0) {
    throw 'Pricing tables are empty. Run StandaloneImports/Import-PackPrices.ps1 with the full release folder.'
}
if ($XmlPath) {
    & (Join-Path $PSScriptRoot 'Validate-PackPrices.ps1') -XmlPath $XmlPath -ServerInstance $ServerInstance -Database $Database | Format-Table -AutoSize
}

# Check record counts in core tables
Write-Host "`n📊 Checking record counts..." -ForegroundColor Yellow
$recordCounts = @"
SELECT 
    'VTM (Virtual Therapeutic Moiety)' as Entity,
    COUNT(*) as Total_Records,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Records,
    COUNT(CASE WHEN invalid = 1 THEN 1 END) as Invalid_Records
FROM vtm
UNION ALL
SELECT 
    'VMP (Virtual Medical Product)' as Entity,
    COUNT(*) as Total_Records,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Records,
    COUNT(CASE WHEN invalid = 1 THEN 1 END) as Invalid_Records
FROM vmp
UNION ALL
SELECT 
    'AMP (Actual Medical Product)' as Entity,
    COUNT(*) as Total_Records,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Records,
    COUNT(CASE WHEN invalid = 1 THEN 1 END) as Invalid_Records
FROM amp
UNION ALL
SELECT 
    'VMPP (Virtual Medical Product Pack)' as Entity,
    COUNT(*) as Total_Records,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Records,
    COUNT(CASE WHEN invalid = 1 THEN 1 END) as Invalid_Records
FROM vmpp
UNION ALL
SELECT 
    'AMPP (Actual Medical Product Pack)' as Entity,
    COUNT(*) as Total_Records,
    COUNT(CASE WHEN invalid = 0 THEN 1 END) as Active_Records,
    COUNT(CASE WHEN invalid = 1 THEN 1 END) as Invalid_Records
FROM ampp
UNION ALL
SELECT 
    'Lookup Values' as Entity,
    COUNT(*) as Total_Records,
    COUNT(DISTINCT type) as Active_Records,
    0 as Invalid_Records
FROM lookup;
"@

$counts = Invoke-SqlQuery $recordCounts
if ($counts) {
    $counts | Format-Table -AutoSize
    
    # Check if we have reasonable data
    $vtmCount = ($counts | Where-Object { $_.Entity -like "*VTM*" }).Total_Records
    $vmpCount = ($counts | Where-Object { $_.Entity -like "VMP (*" }).Total_Records
    
    if ($vtmCount -lt 100) {
        Write-Warning "⚠️  Low VTM count ($vtmCount). Expected several thousand VTMs."
    } else {
        Write-Host "✅ VTM count looks reasonable ($vtmCount records)" -ForegroundColor Green
    }
    
    if ($vmpCount -lt 1000) {
        Write-Warning "⚠️  Low VMP count ($vmpCount). Expected tens of thousands of VMPs."
    } else {
        Write-Host "✅ VMP count looks reasonable ($vmpCount records)" -ForegroundColor Green
    }
} else {
    Write-Error "❌ Could not retrieve record counts"
}

# Check referential integrity
Write-Host "`n🔗 Checking referential integrity..." -ForegroundColor Yellow

$integrityChecks = @(
    @{
        Name = "AMPP prices with invalid pack references"
        Query = "SELECT COUNT(*) as count FROM dbo.ampp_price p LEFT JOIN dbo.ampp a ON a.appid = p.appid WHERE a.appid IS NULL"
    },
    @{
        Name = "VMPP tariffs with invalid pack references"
        Query = "SELECT COUNT(*) as count FROM dbo.vmpp_drugtariffinfo p LEFT JOIN dbo.vmpp v ON v.vppid = p.vppid WHERE v.vppid IS NULL"
    },
    @{
        Name = "Unknown AMPP price basis codes"
        Query = "SELECT COUNT(*) as count FROM dbo.ampp_price p WHERE NOT EXISTS (SELECT 1 FROM dbo.lookup l WHERE l.type = 'PRICE_BASIS' AND TRY_CONVERT(BIGINT, l.cd) = TRY_CONVERT(BIGINT, p.price_basiscd))"
    },
    @{
        Name = "Unknown VMPP tariff payment categories"
        Query = "SELECT COUNT(*) as count FROM dbo.vmpp_drugtariffinfo p WHERE NOT EXISTS (SELECT 1 FROM dbo.lookup l WHERE l.type = 'DT_PAYMENT_CATEGORY' AND TRY_CONVERT(BIGINT, l.cd) = TRY_CONVERT(BIGINT, p.pay_catcd))"
    },
    @{
        Name = "VMPs with invalid VTM references"
        Query = "SELECT COUNT(*) as count FROM vmp v LEFT JOIN vtm t ON v.vtmid = t.vtmid WHERE v.vtmid IS NOT NULL AND t.vtmid IS NULL"
    },
    @{
        Name = "AMPs with invalid VMP references"  
        Query = "SELECT COUNT(*) as count FROM amp a LEFT JOIN vmp v ON a.vpid = v.vpid WHERE a.vpid IS NOT NULL AND v.vpid IS NULL"
    },
    @{
        Name = "VMPPs with invalid VMP references"
        Query = "SELECT COUNT(*) as count FROM vmpp p LEFT JOIN vmp v ON p.vpid = v.vpid WHERE p.vpid IS NOT NULL AND v.vpid IS NULL"
    },
    @{
        Name = "AMPPs with invalid VMPP references"
        Query = "SELECT COUNT(*) as count FROM ampp ap LEFT JOIN vmpp vp ON ap.vppid = vp.vppid WHERE ap.vppid IS NOT NULL AND vp.vppid IS NULL"
    },
    @{
        Name = "AMPPs with invalid AMP references"
        Query = "SELECT COUNT(*) as count FROM ampp ap LEFT JOIN amp a ON ap.apid = a.apid WHERE ap.apid IS NOT NULL AND a.apid IS NULL"
    }
)

$integrityIssues = 0
foreach ($check in $integrityChecks) {
    $result = Invoke-SqlQuery $check.Query
    if ($result -and $result.count -gt 0) {
        Write-Warning "⚠️  $($check.Name): $($result.count) issues found"
        $integrityIssues += $result.count
    } else {
        Write-Host "✅ $($check.Name): No issues" -ForegroundColor Green
    }
}

# Check for duplicate records
Write-Host "`n🔍 Checking for duplicate records..." -ForegroundColor Yellow

$duplicateChecks = @(
    @{ Table = "ampp_price"; Key = "appid" },
    @{ Table = "vmpp_drugtariffinfo"; Key = "vppid" },
    @{ Table = "vtm"; Key = "vtmid" },
    @{ Table = "vmp"; Key = "vpid" },
    @{ Table = "amp"; Key = "apid" },
    @{ Table = "vmpp"; Key = "vppid" },
    @{ Table = "ampp"; Key = "appid" }
)

$duplicateIssues = 0
foreach ($check in $duplicateChecks) {
    $duplicateQuery = "SELECT COUNT(*) - COUNT(DISTINCT $($check.Key)) as duplicates FROM $($check.Table)"
    $result = Invoke-SqlQuery $duplicateQuery
    
    if ($result -and $result.duplicates -gt 0) {
        Write-Warning "⚠️  $($check.Table): $($result.duplicates) duplicate records found"
        $duplicateIssues += $result.duplicates
    } else {
        Write-Host "✅ $($check.Table): No duplicates found" -ForegroundColor Green
    }
}

# Check data quality
Write-Host "`n📋 Checking data quality..." -ForegroundColor Yellow

$qualityChecks = @"
-- Names with unusual characters or lengths
SELECT 
    'VTM names' as Check_Type,
    COUNT(CASE WHEN LEN(nm) < 3 THEN 1 END) as Too_Short,
    COUNT(CASE WHEN LEN(nm) > 200 THEN 1 END) as Too_Long,
    COUNT(CASE WHEN nm LIKE '%[0-9][0-9][0-9][0-9][0-9]%' THEN 1 END) as Contains_Long_Numbers
FROM vtm
WHERE invalid = 0

UNION ALL

SELECT 
    'VMP names' as Check_Type,
    COUNT(CASE WHEN LEN(nm) < 3 THEN 1 END) as Too_Short,
    COUNT(CASE WHEN LEN(nm) > 200 THEN 1 END) as Too_Long,
    COUNT(CASE WHEN nm LIKE '%[0-9][0-9][0-9][0-9][0-9]%' THEN 1 END) as Contains_Long_Numbers
FROM vmp
WHERE invalid = 0;
"@

$qualityResults = Invoke-SqlQuery $qualityChecks
if ($qualityResults) {
    Write-Host "Data quality summary:"
    $qualityResults | Format-Table -AutoSize
}

# Check lookup table coverage
Write-Host "`n📚 Checking lookup table coverage..." -ForegroundColor Yellow

$lookupCoverage = @"
SELECT 
    type as Lookup_Type,
    COUNT(*) as Value_Count,
    MIN(cd) as Min_Code,
    MAX(cd) as Max_Code
FROM lookup
GROUP BY type
ORDER BY type;
"@

$lookupResults = Invoke-SqlQuery $lookupCoverage
if ($lookupResults) {
    Write-Host "Lookup table coverage:"
    $lookupResults | Format-Table -AutoSize
}

# Sample data verification
Write-Host "`n🔍 Sample data verification..." -ForegroundColor Yellow

$sampleQuery = @"
-- Show sample of each entity type with names
SELECT * FROM (
    SELECT TOP 3 
        'VTM' as Type,
        CAST(vtmid as VARCHAR(20)) as ID,
        nm as Name
    FROM vtm 
    WHERE invalid = 0 AND nm IS NOT NULL
    ORDER BY nm
) vtm_samples
UNION ALL
SELECT * FROM (
    SELECT TOP 3
        'VMP' as Type, 
        CAST(vpid as VARCHAR(20)) as ID,
        nm as Name
    FROM vmp
    WHERE invalid = 0 AND nm IS NOT NULL  
    ORDER BY nm
) vmp_samples
UNION ALL
SELECT * FROM (
    SELECT TOP 3
        'AMP' as Type,
        CAST(apid as VARCHAR(20)) as ID, 
        nm as Name
    FROM amp
    WHERE invalid = 0 AND nm IS NOT NULL
    ORDER BY nm
) amp_samples;
"@

$sampleResults = Invoke-SqlQuery $sampleQuery
if ($sampleResults) {
    Write-Host "Sample records:"
    $sampleResults | Format-Table -AutoSize
}

# Summary
Write-Host "`n=== VALIDATION SUMMARY ===" -ForegroundColor Cyan

if ($integrityIssues -eq 0 -and $duplicateIssues -eq 0) {
    Write-Host "✅ DM+D import validation PASSED" -ForegroundColor Green
    Write-Host "✅ All referential integrity checks passed" -ForegroundColor Green
    Write-Host "✅ No duplicate records found" -ForegroundColor Green
} else {
    Write-Warning "⚠️  DM+D import validation found $($integrityIssues + $duplicateIssues) issues"
    if ($integrityIssues -gt 0) {
        Write-Warning "⚠️  Referential integrity issues: $integrityIssues"
    }
    if ($duplicateIssues -gt 0) {
        Write-Warning "⚠️  Duplicate record issues: $duplicateIssues"
    }
}

Write-Host "`n📁 Next steps:"
Write-Host "1. Explore data using queries in DMD\Queries folder"
Write-Host "2. Set up regular refresh schedule with Check-NewDMDRelease.ps1"  
Write-Host "3. Consider creating views for common query patterns"

# Generate validation report
$reportFile = "C:\DMD\validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$validationSummary = @"
DM+D Import Validation Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server: $ServerInstance
Database: $Database

Record Counts:
$($counts | Out-String)

Pack Pricing Counts:
$($priceCounts | Out-String)

Issues Found:
- Referential Integrity Issues: $integrityIssues
- Duplicate Records: $duplicateIssues

Status: $(if ($integrityIssues -eq 0 -and $duplicateIssues -eq 0) { "PASSED" } else { "ISSUES FOUND" })
"@

$validationSummary | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "📄 Validation report saved to: $reportFile" -ForegroundColor Cyan
if ($integrityIssues -gt 0 -or $duplicateIssues -gt 0) {
    throw "DM+D validation failed: $integrityIssues integrity issues, $duplicateIssues duplicate records."
}
