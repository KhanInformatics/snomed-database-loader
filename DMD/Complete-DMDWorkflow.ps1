# Complete DM+D Database Setup and Update Workflow
# Save this as Complete-DMDWorkflow.ps1

param(
    [string]$ServerInstance = "SILENTPRIORY\SQLEXPRESS",
    [string]$Database = "dmd",
    [switch]$SkipDownload = $false,
    [switch]$SkipDatabaseCreate = $false,
    [switch]$SkipProcessing = $false,
    [switch]$SkipValidation = $false
)

Write-Host "=== DM+D Complete Workflow ===" -ForegroundColor Cyan
Write-Host "This script will perform the complete DM+D database setup:"
Write-Host "1. Check for new releases (optional)"
Write-Host "2. Download latest DM+D data from TRUD"  
Write-Host "3. Create/recreate DM+D database"
Write-Host "4. Process XML files and import data"
Write-Host "5. Validate imported data"
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Script directory: $scriptDir"

# Step 1: Check for new releases (optional)
if (-not $SkipDownload) {
    Write-Host "`n=== STEP 1: Checking for New Releases ===" -ForegroundColor Yellow
    & "$scriptDir\Check-NewDMDRelease.ps1"
    
    $continue = Read-Host "`nWould you like to continue with download? (Y/N)"
    if ($continue -notin @('Y', 'y', 'Yes', 'yes')) {
        Write-Host "Workflow cancelled by user."
        exit 0
    }
}

# Step 2: Download DM+D releases
if (-not $SkipDownload) {
    Write-Host "`n=== STEP 2: Downloading DM+D Releases ===" -ForegroundColor Yellow
    & "$scriptDir\Download-DMDReleases.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Download failed. Stopping workflow."
        exit 1
    }
    Write-Host "✅ Downloads completed successfully" -ForegroundColor Green
} else {
    Write-Host "`n=== STEP 2: SKIPPED - Download ===" -ForegroundColor Gray
}

# Step 3: Create database
if (-not $SkipDatabaseCreate) {
    Write-Host "`n=== STEP 3: Creating DM+D Database ===" -ForegroundColor Yellow
    
    $databaseScript = "$scriptDir\create-database-dmd.sql"
    if (-not (Test-Path $databaseScript)) {
        Write-Error "Database creation script not found: $databaseScript"
        exit 1
    }
    
    Write-Host "Creating database schema..."
    try {
        $sqlcmdCommand = "sqlcmd -S `"$ServerInstance`" -i `"$databaseScript`""
        Write-Host "Executing: $sqlcmdCommand"
        Invoke-Expression $sqlcmdCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Database created successfully" -ForegroundColor Green
        } else {
            Write-Error "Database creation failed"
            exit 1
        }
    } catch {
        Write-Error "Error creating database: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Host "`n=== STEP 3: SKIPPED - Database Creation ===" -ForegroundColor Gray
}

# Step 4: Process SNOMED Drug Extension data and import  
if (-not $SkipProcessing) {
    Write-Host "`n=== STEP 4: Processing SNOMED Drug Extension Data ===" -ForegroundColor Yellow
    Write-Host "Note: Processing SNOMED CT UK Drug Extension instead of pure DM+D XML" -ForegroundColor Cyan
    
    Write-Host "Processing RF2 files and generating import script..."
    & "$scriptDir\Process-SNOMEDDrugData.ps1" -ServerInstance $ServerInstance -Database $Database
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Data processing failed. Stopping workflow."
        exit 1
    }
    Write-Host "✅ SNOMED Drug Extension processing completed successfully" -ForegroundColor Green
} else {
    Write-Host "`n=== STEP 4: SKIPPED - Data Processing ===" -ForegroundColor Gray
}

# Step 5: Validate imported data
if (-not $SkipValidation) {
    Write-Host "`n=== STEP 5: Validating DM+D Import ===" -ForegroundColor Yellow
    
    & "$scriptDir\Validate-DMDImport.ps1" -ServerInstance $ServerInstance -Database $Database
    
    Write-Host "✅ Validation completed" -ForegroundColor Green
} else {
    Write-Host "`n=== STEP 5: SKIPPED - Validation ===" -ForegroundColor Gray
}

# Summary and next steps
Write-Host "`n=== WORKFLOW COMPLETE ===" -ForegroundColor Green
Write-Host "🎉 DM+D database setup completed successfully!"

Write-Host "`n📊 Database Information:"
Write-Host "  Server: $ServerInstance"
Write-Host "  Database: $Database"

Write-Host "`n📁 Available Resources:"
Write-Host "  • Database: Contains full DM+D hierarchy (VTM → VMP → AMP → VMPP → AMPP)"
Write-Host "  • Queries: See DMD\Queries folder for sample queries"
Write-Host "  • Documentation: Check DMD\README.md for usage guidance"

Write-Host "`n🔄 Regular Maintenance:"
Write-Host "  • Run Check-NewDMDRelease.ps1 weekly to check for updates"
Write-Host "  • DM+D releases are typically published weekly (Mondays at 4:00 AM)"
Write-Host "  • Use Download-DMDReleases.ps1 and Process-DMDData.ps1 to update"

Write-Host "`n🎯 Quick Start Commands:"
Write-Host "  # Check for updates"
Write-Host "  .\Check-NewDMDRelease.ps1"
Write-Host ""
Write-Host "  # Update data"  
Write-Host "  .\Download-DMDReleases.ps1"
Write-Host "  .\Process-DMDData.ps1"
Write-Host ""
Write-Host "  # Validate after update"
Write-Host "  .\Validate-DMDImport.ps1"

# Log completion
$logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - DM+D Complete Workflow completed successfully"
$logFile = "C:\DMD\workflow.log"

if (-not (Test-Path "C:\DMD")) {
    New-Item -ItemType Directory -Path "C:\DMD" | Out-Null
}

Add-Content -Path $logFile -Value $logEntry
Write-Host "`n📝 Workflow completion logged to: $logFile" -ForegroundColor Cyan