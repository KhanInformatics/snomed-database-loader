# Complete Data Migration Workbench Download Workflow
# Save this as Complete-DMWBWorkflow.ps1

param(
    [switch]$SkipCheck = $false,
    [switch]$Force = $false
)

Write-Host "=== NHS Data Migration Workbench Complete Workflow ===" -ForegroundColor Cyan
Write-Host "This script will perform the complete DMWB setup:" -ForegroundColor Cyan
Write-Host "1. Check for new releases from TRUD" -ForegroundColor White
Write-Host "2. Download latest DMWB tools" -ForegroundColor White
Write-Host "3. Extract and organize files" -ForegroundColor White
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Script directory: $scriptDir" -ForegroundColor Gray
Write-Host ""

# Step 1: Check for new releases
if (-not $SkipCheck) {
    Write-Host "=== STEP 1: Checking for New Releases ===" -ForegroundColor Yellow
    Write-Host ""
    
    & "$scriptDir\Check-NewDMWBRelease.ps1"
    
    if (-not $Force) {
        Write-Host ""
        $continue = Read-Host "Would you like to continue with download? (Y/N)"
        if ($continue -notin @('Y', 'y', 'Yes', 'yes')) {
            Write-Host "Workflow cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "`nForce flag set - proceeding automatically..." -ForegroundColor Gray
    }
} else {
    Write-Host "=== STEP 1: SKIPPED - Release Check ===" -ForegroundColor Gray
    Write-Host ""
}

# Step 2: Download DMWB releases
Write-Host ""
Write-Host "=== STEP 2: Downloading Data Migration Workbench ===" -ForegroundColor Yellow
Write-Host ""

try {
    & "$scriptDir\Download-DMWBReleases.ps1"
    
    if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
        Write-Host ""
        Write-Host "✅ Download completed successfully" -ForegroundColor Green
    } else {
        Write-Error "Download failed with exit code: $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Error "Error during download: $($_.Exception.Message)"
    exit 1
}

# Step 3: Completion summary
Write-Host ""
Write-Host "=== WORKFLOW COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ All steps completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "DMWB Tools Location:" -ForegroundColor Yellow
Write-Host "  C:\DMWB\CurrentReleases\" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Navigate to C:\DMWB\CurrentReleases\" -ForegroundColor White
Write-Host "  2. Review the DMWB documentation included in the release" -ForegroundColor White
Write-Host "  3. Use the DMWB tools for your data migration projects" -ForegroundColor White
Write-Host ""
Write-Host "For more information, see: README.md" -ForegroundColor Gray
Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
