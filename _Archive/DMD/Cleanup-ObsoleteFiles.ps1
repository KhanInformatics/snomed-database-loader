# Cleanup script to remove obsolete and generated files from DMD directory
# Run this after reviewing the list to clean up the repository

param(
    [switch]$WhatIf = $true  # Default to preview mode, use -WhatIf:$false to actually delete
)

$FilesToRemove = @(
    # Duplicate import scripts (use StandaloneImports versions instead)
    "Import-AMP.ps1",
    "Import-GTIN.ps1",
    
    # Obsolete import methods (replaced by StandaloneImports\Run-AllImports.ps1)
    "Import-DMDData-Simple.ps1",
    "Import-DMDData-BulkInsert.ps1",
    "Import-DMDData-Batched.ps1",
    
    # Obsolete validation/processing scripts
    "Validate-Against-CSVs.ps1",
    "Compare-CSV-Database.ps1",
    "Process-DMDData.ps1",
    "Process-DMDData-Fixed.ps1",
    "Process-SNOMEDDrugData.ps1",
    "Simple-SNOMEDDrugImport.ps1",
    
    # Generated log files (should not be in repo)
    "import-log.txt",
    "simple-import-log.txt",
    "batched-import-log.txt",
    "full-import-log.txt",
    
    # Temporary files
    "current_schema.csv"
)

$DMDPath = "O:\GitHub\snomed-database-loader\DMD"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DMD REPOSITORY CLEANUP" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "PREVIEW MODE - No files will be deleted" -ForegroundColor Yellow
    Write-Host "Run with -WhatIf:`$false to actually delete files`n" -ForegroundColor Yellow
} else {
    Write-Host "DELETION MODE - Files will be removed!" -ForegroundColor Red
    Write-Host ""
}

$existingFiles = @()
$missingFiles = @()

foreach ($file in $FilesToRemove) {
    $fullPath = Join-Path $DMDPath $file
    
    if (Test-Path $fullPath) {
        $existingFiles += $file
        
        if ($WhatIf) {
            Write-Host "  [PREVIEW] Would delete: $file" -ForegroundColor Yellow
        } else {
            try {
                Remove-Item $fullPath -Force
                Write-Host "  [DELETED] $file" -ForegroundColor Red
            } catch {
                Write-Host "  [ERROR] Failed to delete $file : $_" -ForegroundColor Red
            }
        }
    } else {
        $missingFiles += $file
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Files found and " -NoNewline
if ($WhatIf) {
    Write-Host "would be deleted" -NoNewline -ForegroundColor Yellow
} else {
    Write-Host "deleted" -NoNewline -ForegroundColor Red
}
Write-Host ": $($existingFiles.Count)" -ForegroundColor White

if ($missingFiles.Count -gt 0) {
    Write-Host "Files already removed: $($missingFiles.Count)" -ForegroundColor Gray
}

Write-Host "`nKEPT (Important files):" -ForegroundColor Green
Write-Host "  ✓ create-database-dmd.sql" -ForegroundColor Green
Write-Host "  ✓ StandaloneImports\* (all import scripts)" -ForegroundColor Green
Write-Host "  ✓ Validate-RandomSamples.ps1" -ForegroundColor Green
Write-Host "  ✓ Validate-DMDImport.ps1" -ForegroundColor Green
Write-Host "  ✓ Check-NewDMDRelease.ps1" -ForegroundColor Green
Write-Host "  ✓ Download-DMDReleases.ps1" -ForegroundColor Green
Write-Host "  ✓ Clear-DMDTables.ps1" -ForegroundColor Green
Write-Host "  ✓ Complete-DMDWorkflow.ps1" -ForegroundColor Green
Write-Host "  ✓ SampleQueries.sql" -ForegroundColor Green
Write-Host "  ✓ README.md" -ForegroundColor Green
Write-Host "  ✓ IMPLEMENTATION_SUMMARY.md" -ForegroundColor Green
Write-Host "  ✓ Queries\* folder" -ForegroundColor Green
Write-Host "  ✓ SQL\* folder" -ForegroundColor Green

if ($WhatIf) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "To actually delete these files, run:" -ForegroundColor Yellow
    Write-Host "  .\Cleanup-ObsoleteFiles.ps1 -WhatIf:`$false" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Host ""
