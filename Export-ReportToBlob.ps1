<#
.SYNOPSIS
    Exports terminology update results to Azure Blob Storage as JSON.

.DESCRIPTION
    Takes the results hashtable from Weekly-TerminologyUpdate.ps1 and uploads
    a JSON file to Azure Blob Storage for direct consumption by Blazor app.
    This provides instant access without database cold-start delays.

.PARAMETER Results
    The results hashtable from Weekly-TerminologyUpdate.ps1

.PARAMETER ConfigPath
    Path to TerminologyConfig.json containing Azure Blob Storage details

.EXAMPLE
    .\Export-ReportToBlob.ps1 -Results $results -ConfigPath .\Config\TerminologyConfig.json

.NOTES
    Requires: Az.Storage module or Azure CLI
    Target: Azure Blob Storage container with public read access or SAS token
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Results,
    
    [string]$ConfigPath = ".\Config\TerminologyConfig.json"
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Get-SafeValue {
    param($Value, $Default = $null)
    if ($null -eq $Value) { return $Default }
    return $Value
}

#endregion

#region Main Script

Write-Host ""
Write-Host "Exporting results to Azure Blob Storage..." -ForegroundColor Cyan

# Load configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $scriptDir "Config\TerminologyConfig.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    return $false
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Check blob storage config
if (-not $config.azureBlobStorage) {
    Write-Warning "Azure Blob Storage configuration not found - skipping blob export"
    return @{ Success = $false; Reason = "No blob config" }
}

$blobConfig = $config.azureBlobStorage

if (-not $blobConfig.enabled) {
    Write-Host "  Blob export disabled in config" -ForegroundColor Gray
    return @{ Success = $false; Reason = "Disabled" }
}

Write-Host "  Storage Account: $($blobConfig.storageAccount)" -ForegroundColor Gray
Write-Host "  Container: $($blobConfig.containerName)" -ForegroundColor Gray

#region Build JSON payload

$runId = [guid]::NewGuid().ToString()
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

# Build the dashboard JSON
$dashboardJson = @{
    # Metadata
    exportedAt     = $timestamp
    runId          = $runId
    exportVersion  = "1.0"
    
    # Latest run summary
    latestRun = @{
        runId             = $runId
        startTime         = $Results.StartTime?.ToString("yyyy-MM-ddTHH:mm:ss")
        endTime           = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        durationFormatted = Get-SafeValue $Results.Duration "00:00:00"
        overallSuccess    = [bool](Get-SafeValue $Results.Success $false)
        updatesFound      = Get-SafeValue $Results.UpdatesFound 0
        serverName        = $env:COMPUTERNAME
        errorCount        = ($Results.Errors ?? @()).Count
    }
    
    # SNOMED CT details
    snomed = @{
        success        = [bool](Get-SafeValue $Results.SNOMED?.Success $false)
        newRelease     = [bool](Get-SafeValue $Results.SNOMED?.NewRelease $false)
        releaseVersion = Get-SafeValue $Results.SNOMED?.ReleaseVersion
        conceptCount   = Get-SafeValue $Results.SNOMED?.RowCounts?["curr_concept_f"] $Results.SNOMED?.ConceptCount
        descriptionCount = Get-SafeValue $Results.SNOMED?.RowCounts?["curr_description_f"] $Results.SNOMED?.DescriptionCount
        relationshipCount = Get-SafeValue $Results.SNOMED?.RowCounts?["curr_relationship_f"]
        steps = @(
            ($Results.SNOMED?.Steps ?? @()) | ForEach-Object {
                @{
                    name     = $_.Name
                    success  = [bool]$_.Success
                    details  = $_.Details
                    duration = $_.Duration
                }
            }
        )
    }
    
    # DM+D details
    dmd = @{
        success              = [bool](Get-SafeValue $Results.DMD?.Success $false)
        newRelease           = [bool](Get-SafeValue $Results.DMD?.NewRelease $false)
        releaseVersion       = Get-SafeValue $Results.DMD?.ReleaseVersion
        vtmCount             = Get-SafeValue $Results.DMD?.TableCounts?["vtm"] $Results.DMD?.VtmCount
        vmpCount             = Get-SafeValue $Results.DMD?.TableCounts?["vmp"] $Results.DMD?.VmpCount
        ampCount             = Get-SafeValue $Results.DMD?.TableCounts?["amp"] $Results.DMD?.AmpCount
        vmppCount            = Get-SafeValue $Results.DMD?.TableCounts?["vmpp"] $Results.DMD?.VmppCount
        amppCount            = Get-SafeValue $Results.DMD?.TableCounts?["ampp"] $Results.DMD?.AmppCount
        ingredientCount      = Get-SafeValue $Results.DMD?.TableCounts?["ingredient"]
        xmlValidationRate    = Get-SafeValue $Results.DMD?.ValidationRate
        snomedValidationRate = Get-SafeValue $Results.DMD?.SnomedValidationRate
        steps = @(
            ($Results.DMD?.Steps ?? @()) | ForEach-Object {
                @{
                    name     = $_.Name
                    success  = [bool]$_.Success
                    details  = $_.Details
                    duration = $_.Duration
                }
            }
        )
    }
    
    # Errors
    errors = @($Results.Errors ?? @())
}

$jsonContent = $dashboardJson | ConvertTo-Json -Depth 10 -Compress:$false

#endregion

#region Upload to Azure Blob Storage

$blobName = $blobConfig.blobName ?? "terminology-dashboard.json"
$tempFile = Join-Path $env:TEMP $blobName

# Save to temp file
$jsonContent | Out-File -FilePath $tempFile -Encoding UTF8 -Force

try {
    # Method 1: Using connection string (simplest)
    if ($blobConfig.connectionString) {
        Write-Host "  Uploading via connection string..." -NoNewline
        
        # Try Az.Storage module first
        if (Get-Module -ListAvailable -Name Az.Storage) {
            Import-Module Az.Storage -ErrorAction SilentlyContinue
            $context = New-AzStorageContext -ConnectionString $blobConfig.connectionString
            Set-AzStorageBlobContent -File $tempFile -Container $blobConfig.containerName -Blob $blobName -Context $context -Force | Out-Null
            Write-Host " OK (Az.Storage)" -ForegroundColor Green
        }
        else {
            # Fall back to Azure CLI
            $env:AZURE_STORAGE_CONNECTION_STRING = $blobConfig.connectionString
            az storage blob upload --file $tempFile --container-name $blobConfig.containerName --name $blobName --overwrite 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " OK (Azure CLI)" -ForegroundColor Green
            } else {
                throw "Azure CLI upload failed"
            }
        }
    }
    # Method 2: Using SAS URL (for restricted access)
    elseif ($blobConfig.sasUrl) {
        Write-Host "  Uploading via SAS URL..." -NoNewline
        
        $uploadUrl = $blobConfig.sasUrl -replace '\?', "/$blobName`?"
        
        $headers = @{
            "x-ms-blob-type" = "BlockBlob"
            "Content-Type"   = "application/json"
        }
        
        Invoke-RestMethod -Uri $uploadUrl -Method Put -InFile $tempFile -Headers $headers | Out-Null
        Write-Host " OK" -ForegroundColor Green
    }
    # Method 3: Using storage account name + key from Credential Manager
    elseif ($blobConfig.storageAccount -and $blobConfig.keyCredentialTarget) {
        Write-Host "  Uploading via storage key..." -NoNewline
        
        Import-Module CredentialManager -ErrorAction Stop
        $cred = Get-StoredCredential -Target $blobConfig.keyCredentialTarget
        if (-not $cred) {
            throw "Storage key not found in Credential Manager: $($blobConfig.keyCredentialTarget)"
        }
        
        $storageKey = $cred.GetNetworkCredential().Password
        
        # Build connection string from account name and key
        $connString = "DefaultEndpointsProtocol=https;AccountName=$($blobConfig.storageAccount);AccountKey=$storageKey;EndpointSuffix=core.windows.net"
        
        if (Get-Module -ListAvailable -Name Az.Storage) {
            Import-Module Az.Storage
            $context = New-AzStorageContext -StorageAccountName $blobConfig.storageAccount -StorageAccountKey $storageKey
            Set-AzStorageBlobContent -File $tempFile -Container $blobConfig.containerName -Blob $blobName -Context $context -Force | Out-Null
            Write-Host " OK (Az.Storage)" -ForegroundColor Green
        }
        else {
            # Fall back to Azure CLI with connection string
            az storage blob upload --file $tempFile --container-name $blobConfig.containerName --name $blobName --connection-string $connString --overwrite 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " OK (Azure CLI)" -ForegroundColor Green
            } else {
                throw "Azure CLI upload failed"
            }
        }
    }
    else {
        throw "No valid authentication method configured (connectionString, sasUrl, or keyCredentialTarget required)"
    }
    
    # Build the public URL
    $blobUrl = "https://$($blobConfig.storageAccount).blob.core.windows.net/$($blobConfig.containerName)/$blobName"
    
    Write-Host ""
    Write-Host "✅ Blob export complete!" -ForegroundColor Green
    Write-Host "   URL: $blobUrl" -ForegroundColor Cyan
    Write-Host ""
    
    return @{
        Success = $true
        BlobUrl = $blobUrl
        RunId   = $runId
    }
}
catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Warning "Blob upload failed: $_"
    return @{
        Success = $false
        Error   = $_.ToString()
    }
}
finally {
    # Cleanup temp file
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#endregion
