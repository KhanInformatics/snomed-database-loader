<#
.SYNOPSIS
    Export GP Summary Data Sharing Exclusion Reference Sets to Excel

.DESCRIPTION
    Extracts all codes from the 4 GP Summary data sharing exclusion reference sets:
    - Termination of pregnancy (999004361000000107)
    - Gender related issues (999004351000000109)
    - Assisted fertilisation (999004371000000100)
    - Sexually transmitted disease (999004381000000103)

.PARAMETER ServerInstance
    SQL Server instance name (default: localhost)

.PARAMETER Database
    Database name (default: SNOMEDCT)

.PARAMETER OutputPath
    Output file path for Excel file (default: .\DataSharingExclusions.xlsx)

.EXAMPLE
    .\Export-DataSharingExclusions.ps1

.EXAMPLE
    .\Export-DataSharingExclusions.ps1 -ServerInstance "MyServer\Instance" -OutputPath "C:\Output\exclusions.xlsx"
#>

[CmdletBinding()]
param(
    [string]$ServerInstance = "localhost",
    [string]$Database = "SNOMEDCT",
    [string]$OutputPath = ".\DataSharingExclusions.xlsx"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GP Summary Data Sharing Exclusions Export" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if ImportExcel module is available
$hasImportExcel = Get-Module -ListAvailable -Name ImportExcel
if (-not $hasImportExcel) {
    Write-Host "ImportExcel module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
        Write-Host "ImportExcel module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install ImportExcel module. Will export as CSV instead." -ForegroundColor Yellow
        $OutputPath = $OutputPath -replace '\.xlsx$', '.csv'
    }
}

# SQL Query - includes Read v2 and CTV3 mappings from DMWB tables
$query = @"
-- Combined query for all 4 exclusion reference sets with Read code mappings
-- Uses subqueries to ensure exactly one row per concept per refset
;WITH BaseData AS (
    SELECT DISTINCT
        s.refsetid,
        s.referencedcomponentid
    FROM curr_simplerefset_f s
    WHERE CAST(s.refsetid AS VARCHAR(20)) IN (
        '999004361000000107',
        '999004351000000109',
        '999004371000000100',
        '999004381000000103'
    )
    AND CAST(s.active AS VARCHAR(1)) = '1'
),
-- Get one FSN per concept
FSN AS (
    SELECT conceptid, term,
        ROW_NUMBER() OVER (PARTITION BY conceptid ORDER BY id) AS rn
    FROM curr_description_f
    WHERE CAST(typeid AS VARCHAR(50)) = '900000000000003001'
    AND CAST(active AS VARCHAR(1)) = '1'
),
-- Get one Preferred Term per concept  
PT AS (
    SELECT conceptid, term,
        ROW_NUMBER() OVER (PARTITION BY conceptid ORDER BY id) AS rn
    FROM curr_description_f
    WHERE CAST(typeid AS VARCHAR(50)) = '900000000000013009'
    AND CAST(active AS VARCHAR(1)) = '1'
),
-- Get one refset name
RefName AS (
    SELECT conceptid, term,
        ROW_NUMBER() OVER (PARTITION BY conceptid ORDER BY id) AS rn
    FROM curr_description_f
    WHERE CAST(typeid AS VARCHAR(50)) = '900000000000003001'
    AND CAST(active AS VARCHAR(1)) = '1'
    AND conceptid IN ('999004361000000107','999004351000000109','999004371000000100','999004381000000103')
)
SELECT
    CASE bd.refsetid
        WHEN '999004361000000107' THEN 'Termination of Pregnancy'
        WHEN '999004351000000109' THEN 'Gender Related Issues'
        WHEN '999004371000000100' THEN 'Assisted Fertilisation'
        WHEN '999004381000000103' THEN 'Sexually Transmitted Disease'
    END AS Exclusion_Category,
    CAST(bd.refsetid AS VARCHAR(20)) AS RefsetID,
    CAST(rn.term AS VARCHAR(255)) AS Refset_Name,
    CAST(bd.referencedcomponentid AS VARCHAR(20)) AS SNOMED_ConceptID,
    CAST(fsn.term AS VARCHAR(500)) AS FSN_Term,
    CAST(pt.term AS VARCHAR(500)) AS Preferred_Term,
    CAST(c.active AS VARCHAR(1)) AS ConceptIsActive,
    -- Read v2 code from DMWB reverse map
    rct.ReadV2Code,
    rct.ReadV2Term,
    -- CTV3 code from DMWB reverse map
    ctv3.CTV3Code,
    ctv3.CTV3Term
FROM BaseData bd
-- Join to concept table
JOIN curr_concept_f c
    ON bd.referencedcomponentid = c.id
-- Get one FSN
LEFT JOIN FSN fsn ON fsn.conceptid = bd.referencedcomponentid AND fsn.rn = 1
-- Get one Preferred Term
LEFT JOIN PT pt ON pt.conceptid = bd.referencedcomponentid AND pt.rn = 1
-- Get refset name
LEFT JOIN RefName rn ON rn.conceptid = bd.refsetid AND rn.rn = 1
-- Get Read v2 code (one per concept using ROW_NUMBER)
-- Term now sourced from READv2.dbo.Readv2Lookup (CS_AS collation) instead of DMWB T60
LEFT JOIN (
    SELECT SnomedConceptID, ReadV2Code, ReadV2Term
    FROM (
        SELECT 
            CAST(m.TCUI AS VARCHAR(20)) AS SnomedConceptID,
            CAST(m.SCUI AS VARCHAR(10)) AS ReadV2Code,
            rl.PreferredTerm AS ReadV2Term,
            ROW_NUMBER() OVER (PARTITION BY m.TCUI ORDER BY m.SCUI) AS rn
        FROM DMWB_Export.dbo.DMWB_NHS_Data_Migration_Maps_RCTSCTMAP m
        LEFT JOIN READv2.dbo.Readv2Lookup rl 
            ON CAST(m.SCUI AS VARCHAR(10)) COLLATE Latin1_General_CS_AS = rl.ReadCode
        WHERE m.STUI = '00'
    ) ranked
    WHERE rn = 1
) rct ON rct.SnomedConceptID = CAST(bd.referencedcomponentid AS VARCHAR(20))
-- Get CTV3 code (one per concept using ROW_NUMBER)
LEFT JOIN (
    SELECT SnomedConceptID, CTV3Code, CTV3Term
    FROM (
        SELECT 
            CAST(m.TCUI AS VARCHAR(20)) AS SnomedConceptID,
            CAST(m.SCUI AS NVARCHAR(10)) AS CTV3Code,
            CAST(ctv3_t.T60 AS NVARCHAR(60)) AS CTV3Term,
            ROW_NUMBER() OVER (PARTITION BY m.TCUI ORDER BY m.SCUI) AS rn
        FROM DMWB_Export.dbo.DMWB_NHS_Data_Migration_Maps_CTV3SCTMAP m
        LEFT JOIN DMWB_Export.dbo.DMWB_NHS_READ_CTV3 ctv3_t 
            ON CAST(m.SCUI AS NVARCHAR(20)) = ctv3_t.CUI AND ctv3_t.TUI = '00'
    ) ranked
    WHERE rn = 1
) ctv3 ON ctv3.SnomedConceptID = CAST(bd.referencedcomponentid AS VARCHAR(20))
ORDER BY 
    Exclusion_Category,
    CAST(pt.term AS VARCHAR(500));
"@

$summaryQuery = @"
SELECT
    CASE s.refsetid
        WHEN '999004361000000107' THEN 'Termination of Pregnancy'
        WHEN '999004351000000109' THEN 'Gender Related Issues'
        WHEN '999004371000000100' THEN 'Assisted Fertilisation'
        WHEN '999004381000000103' THEN 'Sexually Transmitted Disease'
    END AS Exclusion_Category,
    CAST(s.refsetid AS VARCHAR(20)) AS RefsetID,
    COUNT(DISTINCT s.referencedcomponentid) AS Total_Codes
FROM curr_simplerefset_f s
WHERE CAST(s.refsetid AS VARCHAR(20)) IN (
    '999004361000000107',
    '999004351000000109',
    '999004371000000100',
    '999004381000000103'
)
AND CAST(s.active AS VARCHAR(1)) = '1'
GROUP BY s.refsetid
ORDER BY Exclusion_Category;
"@

try {
    Write-Host "Connecting to SQL Server: $ServerInstance" -ForegroundColor Gray
    Write-Host "Database: $Database" -ForegroundColor Gray
    Write-Host ""

    # Execute main query
    Write-Host "Executing query..." -ForegroundColor Yellow
    $results = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query -TrustServerCertificate -ErrorAction Stop
    
    # Execute summary query
    $summary = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $summaryQuery -TrustServerCertificate
    
    # Display summary
    Write-Host ""
    Write-Host "Summary of codes by category:" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    $summary | Format-Table -AutoSize
    Write-Host ""
    
    $totalCodes = ($summary | Measure-Object -Property Total_Codes -Sum).Sum
    Write-Host "Total codes across all categories: $totalCodes" -ForegroundColor Green
    Write-Host ""

    if ($results.Count -eq 0) {
        Write-Host "No data found. Please check:" -ForegroundColor Red
        Write-Host "  - SQL Server instance is correct" -ForegroundColor Yellow
        Write-Host "  - Database name is correct" -ForegroundColor Yellow
        Write-Host "  - SNOMED CT data is loaded" -ForegroundColor Yellow
        Write-Host "  - Reference sets exist in the database" -ForegroundColor Yellow
        exit 1
    }

    # Export to Excel or CSV
    if (Get-Module -ListAvailable -Name ImportExcel) {
        Import-Module ImportExcel
        
        Write-Host "Exporting to Excel: $OutputPath" -ForegroundColor Yellow
        
        # Export main data
        $results | Export-Excel -Path $OutputPath -WorksheetName "All Exclusions" -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
        
        # Export summary
        $summary | Export-Excel -Path $OutputPath -WorksheetName "Summary" -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow -Show
        
        Write-Host ""
        Write-Host "✓ Export completed successfully!" -ForegroundColor Green
        Write-Host "  File: $OutputPath" -ForegroundColor Green
        Write-Host "  Worksheets: 'All Exclusions' and 'Summary'" -ForegroundColor Gray
    }
    else {
        Write-Host "Exporting to CSV: $OutputPath" -ForegroundColor Yellow
        $results | Export-Csv -Path $OutputPath -NoTypeInformation
        
        Write-Host ""
        Write-Host "✓ Export completed successfully!" -ForegroundColor Green
        Write-Host "  File: $OutputPath" -ForegroundColor Green
    }
}
catch {
    Write-Host ""
    Write-Host "Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
