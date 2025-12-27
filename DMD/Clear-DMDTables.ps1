# Clear all DM+D tables
# This script truncates all tables in the correct order to respect foreign key constraints

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd"
)

Write-Host "=== Clearing all DM+D Tables ===" -ForegroundColor Red
Write-Host "Server: $ServerInstance" -ForegroundColor Yellow
Write-Host "Database: $Database" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "This will delete ALL data from the DM+D database. Type 'YES' to confirm"
if ($confirmation -ne 'YES') {
    Write-Host "Operation cancelled." -ForegroundColor Green
    exit
}

Write-Host "`nClearing tables..." -ForegroundColor Cyan

# Order matters - child tables first, then parent tables
$tables = @(
    "gtin",
    "dmd_bnf",
    "dmd_atc",
    "dmd_snomed",
    "vmp_ingredient",
    "vmp_drugroute",
    "vmp_drugform",
    "vmp_ontdrugform",
    "vmp_controlinfo",
    "dt_payment_category",
    "ampp_drugtariffinfo",
    "ampp",
    "vmpp",
    "amp",
    "vmp",
    "vtm",
    "ingredient",
    "lookup"
)

# Disable foreign key constraints first
Write-Host "  Disabling foreign key constraints... " -NoNewline
try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database `
        -Query "EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'" -TrustServerCertificate -ErrorAction Stop
    Write-Host "✓" -ForegroundColor Green
} catch {
    Write-Host "✗ ($($_.Exception.Message))" -ForegroundColor Red
}

$cleared = 0
$errors = 0

foreach ($table in $tables) {
    Write-Host "  Clearing $table... " -NoNewline
    try {
        # Check if table exists first
        $exists = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database `
            -Query "IF OBJECT_ID('$table', 'U') IS NOT NULL SELECT 1 ELSE SELECT 0" -TrustServerCertificate
        
        if ($exists.Column1 -eq 1) {
            # Use DELETE instead of TRUNCATE since FKs are disabled
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database `
                -Query "DELETE FROM $table" -TrustServerCertificate -ErrorAction Stop
            Write-Host "✓" -ForegroundColor Green
            $cleared++
        } else {
            Write-Host "⊘ (does not exist)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ ($($_.Exception.Message))" -ForegroundColor Red
        $errors++
    }
}

# Re-enable foreign key constraints
Write-Host "  Re-enabling foreign key constraints... " -NoNewline
try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database `
        -Query "EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL'" -TrustServerCertificate -ErrorAction Stop
    Write-Host "✓" -ForegroundColor Green
} catch {
    Write-Host "✗ ($($_.Exception.Message))" -ForegroundColor Red
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Tables cleared: $cleared" -ForegroundColor Green
Write-Host "Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { "Yellow" } else { "Green" })
Write-Host "`nDatabase is now empty and ready for fresh import." -ForegroundColor Green
