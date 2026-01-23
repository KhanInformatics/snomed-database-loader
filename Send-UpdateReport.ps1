<#
.SYNOPSIS
    Sends terminology update reports via SMTP email.

.DESCRIPTION
    Generates and sends HTML-formatted email reports for weekly terminology updates.
    Supports Windows Credential Manager for SMTP authentication.

.PARAMETER Results
    Hashtable containing update results from Weekly-TerminologyUpdate.ps1

.PARAMETER ConfigPath
    Path to TerminologyConfig.json

.PARAMETER TestMode
    Send to sender only for testing

.EXAMPLE
    $results | Send-UpdateReport -ConfigPath ".\TerminologyConfig.json"
#>

param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [hashtable]$Results,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ".\Config\TerminologyConfig.json",
    
    [switch]$TestMode
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $scriptDir "Config\TerminologyConfig.json"
}
if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if (-not $config.notifications.enabled) {
    Write-Host "Notifications are disabled in configuration" -ForegroundColor Yellow
    return
}

# Build HTML report
function Build-HtmlReport {
    param([hashtable]$Results)
    
    $overallStatus = if ($Results.Success) { 
        '<span style="color: #28a745; font-weight: bold;">&#10003; SUCCESS</span>' 
    } else { 
        '<span style="color: #dc3545; font-weight: bold;">&#10007; FAILED</span>' 
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #0066cc; padding-bottom: 10px; }
        h2 { color: #0066cc; margin-top: 25px; }
        .summary { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .success { color: #28a745; }
        .failure { color: #dc3545; }
        .warning { color: #ffc107; }
        .info { color: #17a2b8; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #0066cc; color: white; }
        tr:hover { background: #f5f5f5; }
        .metric { font-size: 24px; font-weight: bold; }
        .label { color: #666; font-size: 12px; text-transform: uppercase; }
        .grid { display: flex; gap: 20px; flex-wrap: wrap; }
        .card { flex: 1; min-width: 150px; background: #f8f9fa; padding: 15px; border-radius: 5px; text-align: center; }
        .timestamp { color: #999; font-size: 12px; }
        .error-box { background: #fff3cd; border: 1px solid #ffc107; padding: 10px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>&#127973; Terminology Update Report</h1>
        <p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        
        <div class="summary">
            <div class="grid">
                <div class="card">
                    <div class="label">Overall Status</div>
                    <div class="metric">$overallStatus</div>
                </div>
                <div class="card">
                    <div class="label">Duration</div>
                    <div class="metric">$($Results.Duration)</div>
                </div>
                <div class="card">
                    <div class="label">Updates Found</div>
                    <div class="metric">$($Results.UpdatesFound)</div>
                </div>
            </div>
        </div>
"@

    # SNOMED CT Section
    if ($Results.SNOMED) {
        $snomedStatus = if ($Results.SNOMED.Success) { '<span class="success">&#10003;</span>' } else { '<span class="failure">&#10007;</span>' }
        $html += @"
        
        <h2>$snomedStatus SNOMED CT</h2>
        <table>
            <tr><th>Step</th><th>Status</th><th>Details</th><th>Duration</th></tr>
"@
        foreach ($step in $Results.SNOMED.Steps) {
            $stepStatus = if ($step.Success) { '<span class="success">&#10003; Completed</span>' } else { '<span class="failure">&#10007; Failed</span>' }
            $html += "<tr><td>$($step.Name)</td><td>$stepStatus</td><td>$($step.Details)</td><td>$($step.Duration)</td></tr>"
        }
        $html += "</table>"
        
        if ($Results.SNOMED.NewRelease) {
            $html += "<p><strong>New Release:</strong> $($Results.SNOMED.ReleaseVersion)</p>"
        } else {
            $html += "<p><em>No new release available</em></p>"
        }
        if ($Results.SNOMED.RowCounts -and $Results.SNOMED.RowCounts.Count -gt 0) {
            $html += "<p><strong>Row Counts:</strong></p><ul>"
            foreach ($table in $Results.SNOMED.RowCounts.Keys) {
                $html += "<li>$table : $($Results.SNOMED.RowCounts[$table].ToString('N0'))</li>"
            }
            $html += "</ul>"
        }
    }

    # DMD Section
    if ($Results.DMD) {
        $dmdStatus = if ($Results.DMD.Success) { '<span class="success">&#10003;</span>' } else { '<span class="failure">&#10007;</span>' }
        $html += @"
        
        <h2>$dmdStatus Dictionary of Medicines and Devices (dm+d)</h2>
        <table>
            <tr><th>Step</th><th>Status</th><th>Details</th><th>Duration</th></tr>
"@
        foreach ($step in $Results.DMD.Steps) {
            $stepStatus = if ($step.Success) { '<span class="success">&#10003; Completed</span>' } else { '<span class="failure">&#10007; Failed</span>' }
            $html += "<tr><td>$($step.Name)</td><td>$stepStatus</td><td>$($step.Details)</td><td>$($step.Duration)</td></tr>"
        }
        $html += "</table>"
        
        if ($Results.DMD.NewRelease) {
            $html += "<p><strong>New Release:</strong> $($Results.DMD.ReleaseVersion)</p>"
        } else {
            $html += "<p><em>No new release available</em></p>"
        }
        
        if ($Results.DMD.TableCounts -and $Results.DMD.TableCounts.Count -gt 0) {
            $html += "<p><strong>Table Counts:</strong></p><table><tr><th>Table</th><th>Records</th><th>Change</th></tr>"
            foreach ($table in $Results.DMD.TableCounts.Keys) {
                $count = $Results.DMD.TableCounts[$table]
                $change = if ($Results.DMD.TableChanges -and $Results.DMD.TableChanges.ContainsKey($table)) { 
                    $c = $Results.DMD.TableChanges[$table]
                    if ($c -gt 0) { "<span class='success'>+$c</span>" } elseif ($c -lt 0) { "<span class='failure'>$c</span>" } else { "0" }
                } else { "-" }
                $html += "<tr><td>$table</td><td>$($count.ToString('N0'))</td><td>$change</td></tr>"
            }
            $html += "</table>"
        }
        if ($Results.DMD.ValidationRate) {
            $validationColor = if ($Results.DMD.ValidationRate -ge 99) { "success" } elseif ($Results.DMD.ValidationRate -ge 90) { "warning" } else { "failure" }
            $html += "<p><strong>XML Validation Rate:</strong> <span class='$validationColor'>$($Results.DMD.ValidationRate)%</span></p>"
        }
        if ($Results.DMD.SnomedValidationRate) {
            $html += "<p><strong>SNOMED CT Validation Rate:</strong> $($Results.DMD.SnomedValidationRate)%</p>"
        }
    }

    # Errors Section
    if ($Results.Errors -and $Results.Errors.Count -gt 0) {
        $html += @"
        
        <h2>&#9888; Errors</h2>
"@
        foreach ($error in $Results.Errors) {
            $html += "<div class='error-box'>$([System.Web.HttpUtility]::HtmlEncode($error))</div>"
        }
    }

    $html += @"
        
        <hr style="margin-top: 30px;">
        <p class="timestamp">
            Server: $env:COMPUTERNAME | 
            Script: Weekly-TerminologyUpdate.ps1 |
            Log: $($Results.LogFile)
        </p>
    </div>
</body>
</html>
"@

    return $html
}

# Get SMTP credentials from Credential Manager
function Get-SmtpCredential {
    param([string]$Target)
    
    try {
        Import-Module CredentialManager -ErrorAction Stop
        $cred = Get-StoredCredential -Target $Target
        if ($cred) {
            return $cred
        }
    } catch {
        Write-Warning "CredentialManager module not available or credential '$Target' not found"
    }
    return $null
}

# Send the email using .NET SmtpClient
function Send-SmtpEmail {
    param(
        [string]$From,
        [string[]]$To,
        [string]$Subject,
        [string]$Body,
        [string]$SmtpServer,
        [int]$Port,
        [bool]$UseSsl,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    $mail = New-Object System.Net.Mail.MailMessage
    $mail.From = $From
    foreach ($recipient in $To) {
        $mail.To.Add($recipient)
    }
    $mail.Subject = $Subject
    $mail.Body = $Body
    $mail.IsBodyHtml = $true
    $mail.BodyEncoding = [System.Text.Encoding]::UTF8
    $mail.SubjectEncoding = [System.Text.Encoding]::UTF8
    
    $smtp = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
    $smtp.EnableSsl = $UseSsl
    $smtp.Timeout = 30000  # 30 seconds
    
    if ($Credential) {
        $smtp.Credentials = New-Object System.Net.NetworkCredential(
            $Credential.UserName, 
            $Credential.GetNetworkCredential().Password
        )
    }
    
    try {
        $smtp.Send($mail)
    }
    finally {
        $mail.Dispose()
        $smtp.Dispose()
    }
}

try {
    Add-Type -AssemblyName System.Web
    $htmlBody = Build-HtmlReport -Results $Results
    
    # Determine subject
    $statusText = if ($Results.Success) { "Success" } else { "FAILED" }
    $updatesText = if ($Results.UpdatesFound -gt 0) { "$($Results.UpdatesFound) update(s)" } else { "No updates" }
    $subject = "$($config.notifications.subjectPrefix) $statusText - $updatesText - $(Get-Date -Format 'yyyy-MM-dd')"
    
    # Get recipients
    $recipients = if ($TestMode) { 
        @($config.notifications.fromAddress) 
    } else { 
        $config.notifications.toAddresses 
    }
    
    # Get credentials if configured
    $smtpCred = $null
    if ($config.notifications.smtpCredentialTarget) {
        $smtpCred = Get-SmtpCredential -Target $config.notifications.smtpCredentialTarget
    }
    
    # Send email using .NET SmtpClient
    Send-SmtpEmail -From $config.notifications.fromAddress `
                   -To $recipients `
                   -Subject $subject `
                   -Body $htmlBody `
                   -SmtpServer $config.notifications.smtpServer `
                   -Port $config.notifications.smtpPort `
                   -UseSsl $config.notifications.smtpUseSsl `
                   -Credential $smtpCred
    
    Write-Host "[OK] Email report sent to: $($recipients -join ', ')" -ForegroundColor Green
    return $true
    
} catch {
    Write-Error "Failed to send email: $_"
    
    # Save HTML report locally as fallback
    $logsDir = $config.paths.logsBase
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    $fallbackPath = Join-Path $logsDir "UpdateReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $htmlBody | Out-File -FilePath $fallbackPath -Encoding UTF8
    Write-Warning "Report saved locally: $fallbackPath"
    return $false
}
