<#
.SYNOPSIS
    Processes the August Read code survey file and produces summary reports.

.DESCRIPTION
    Streams through the large aug_survey.txt file (CSV format) to aggregate
    Read code usage across all sites. Produces:
    - A summary CSV with one row per ReadCode showing total usage, site count, and term
    - Optional filtering by specific Read codes of interest

.PARAMETER InputFile
    Path to the aug_survey.txt file. Defaults to aug_survey.txt in the same directory.

.PARAMETER OutputFile
    Path for the summary CSV output. Defaults to aug_survey_summary.csv.

.PARAMETER FilterCodes
    Optional array of specific Read codes to filter for. If omitted, all codes are summarised.

.PARAMETER FilterFile
    Optional path to a text file containing Read codes to filter (one per line).

.PARAMETER Top
    If specified, only output the top N codes by total usage count.

.EXAMPLE
    .\Survey-ReadCodes.ps1
    # Produces full summary of all Read codes

.EXAMPLE
    .\Survey-ReadCodes.ps1 -FilterCodes "H333.","8H62.","E23.."
    # Produces summary filtered to specific codes

.EXAMPLE
    .\Survey-ReadCodes.ps1 -FilterFile "codes_of_interest.txt" -Top 50
    # Filter by file and limit to top 50
#>
[CmdletBinding()]
param(
    [string]$InputFile = (Join-Path $PSScriptRoot "aug_survey.txt"),
    [string]$OutputFile = (Join-Path $PSScriptRoot "aug_survey_summary.csv"),
    [string[]]$FilterCodes,
    [string]$FilterFile,
    [int]$Top = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Build a filter set if codes are specified
$filterSet = $null
if ($FilterFile -and (Test-Path $FilterFile)) {
    $filterSet = @{}
    Get-Content $FilterFile | ForEach-Object {
        $code = $_.Trim()
        if ($code -and -not $code.StartsWith('#')) {
            $filterSet[$code] = $true
        }
    }
    Write-Host "Loaded $($filterSet.Count) codes from filter file." -ForegroundColor Cyan
}
if ($FilterCodes) {
    if (-not $filterSet) { $filterSet = @{} }
    foreach ($c in $FilterCodes) {
        $filterSet[$c.Trim()] = $true
    }
    Write-Host "Filter includes $($filterSet.Count) total codes." -ForegroundColor Cyan
}

if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    return
}

Write-Host "Processing: $InputFile" -ForegroundColor Green
Write-Host "This may take a few minutes for large files..." -ForegroundColor Yellow

# Use StreamReader for performance on large files
$reader = [System.IO.StreamReader]::new($InputFile)
$header = $reader.ReadLine()  # skip header

# Aggregation dictionaries
# Key = ReadCode, Value = hashtable with TotalCount, SiteCount, Sites (hashset), Term, MaxDate, FullRead
$codeStats = @{}
$lineCount = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()

while ($null -ne ($line = $reader.ReadLine())) {
    $lineCount++

    if ($lineCount % 1000000 -eq 0) {
        Write-Host ("  Processed {0:N0} lines ({1:N1}s)..." -f $lineCount, $sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
    }

    # Parse CSV - split on first 5 commas only (Term field may contain commas)
    $parts = $line.Split(',', 6)
    if ($parts.Count -lt 6) { continue }

    $siteName = $parts[0]
    $rcount   = 0
    [void][int]::TryParse($parts[1], [ref]$rcount)
    $maxDate  = $parts[2]
    $readCode = $parts[3]
    $fullRead = $parts[4]
    $term     = $parts[5]

    # Apply filter if specified
    if ($filterSet -and -not $filterSet.ContainsKey($readCode)) { continue }

    if ($codeStats.ContainsKey($readCode)) {
        $entry = $codeStats[$readCode]
        $entry.TotalCount += $rcount
        if (-not $entry.Sites.Contains($siteName)) {
            $entry.Sites.Add($siteName) | Out-Null
        }
        # Keep the most recent MaxDate
        if ($maxDate -gt $entry.MaxDate) {
            $entry.MaxDate = $maxDate
        }
    }
    else {
        $sites = [System.Collections.Generic.HashSet[string]]::new()
        $sites.Add($siteName) | Out-Null
        $codeStats[$readCode] = @{
            ReadCode   = $readCode
            FullRead   = $fullRead
            Term       = $term
            TotalCount = $rcount
            Sites      = $sites
            MaxDate    = $maxDate
        }
    }
}
$reader.Close()

$sw.Stop()
Write-Host ("Finished processing {0:N0} lines in {1:N1} seconds." -f $lineCount, $sw.Elapsed.TotalSeconds) -ForegroundColor Green
Write-Host ("Found {0:N0} unique Read codes." -f $codeStats.Count) -ForegroundColor Green

# Build output
$results = $codeStats.Values | ForEach-Object {
    [PSCustomObject]@{
        ReadCode   = $_.ReadCode
        FullRead   = $_.FullRead
        Term       = $_.Term
        TotalCount = $_.TotalCount
        SiteCount  = $_.Sites.Count
        MaxDate    = $_.MaxDate
    }
} | Sort-Object TotalCount -Descending

if ($Top -gt 0) {
    $results = $results | Select-Object -First $Top
}

# Export to CSV
$results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
Write-Host "Summary exported to: $OutputFile" -ForegroundColor Green
Write-Host ""

# Display top 20 on screen
Write-Host "=== Top 20 Read Codes by Total Usage ===" -ForegroundColor Cyan
$results | Select-Object -First 20 | Format-Table ReadCode, TotalCount, SiteCount, Term -AutoSize
