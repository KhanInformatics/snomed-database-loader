<#
.SYNOPSIS
    Installs Windows Task Scheduler task for weekly terminology updates.

.DESCRIPTION
    Creates a scheduled task that runs the Weekly-TerminologyUpdate.ps1 script
    on a weekly schedule. Requires Administrator privileges.

.PARAMETER ConfigPath
    Path to TerminologyConfig.json

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it

.PARAMETER RunAs
    Specify a user account to run the task as. If not specified, uses SYSTEM.

.PARAMETER Test
    Run the task immediately after creation to test it

.EXAMPLE
    .\Install-WeeklyUpdateTask.ps1
    
.EXAMPLE
    .\Install-WeeklyUpdateTask.ps1 -Uninstall
    
.EXAMPLE
    .\Install-WeeklyUpdateTask.ps1 -RunAs "DOMAIN\ServiceAccount" -Test
#>

param(
    [string]$ConfigPath = ".\Config\TerminologyConfig.json",
    [switch]$Uninstall,
    [string]$RunAs,
    [switch]$Test
)

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires Administrator privileges."
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $scriptDir "Config\TerminologyConfig.json"
}
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$taskName = $config.schedule.taskName
$dayOfWeek = $config.schedule.dayOfWeek
$timeOfDay = $config.schedule.timeOfDay

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "   Weekly Terminology Update - Task Scheduler Setup" -ForegroundColor White
Write-Host "===============================================================================" -ForegroundColor Cyan

if ($Uninstall) {
    Write-Host ""
    Write-Host "Removing scheduled task: $taskName" -ForegroundColor Yellow
    
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Task '$taskName' removed successfully." -ForegroundColor Green
    } else {
        Write-Host "Task '$taskName' does not exist." -ForegroundColor Gray
    }
    return
}

Write-Host ""
Write-Host "Task Configuration:" -ForegroundColor Cyan
Write-Host "  Task Name:  $taskName" -ForegroundColor Gray
Write-Host "  Schedule:   Every $dayOfWeek at $timeOfDay" -ForegroundColor Gray
Write-Host "  Script:     Weekly-TerminologyUpdate.ps1" -ForegroundColor Gray
Write-Host "  Config:     $ConfigPath" -ForegroundColor Gray

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host ""
    Write-Warning "Task '$taskName' already exists. It will be replaced."
}

# Build the action
$mainScript = Join-Path $scriptDir "Weekly-TerminologyUpdate.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Error "Weekly-TerminologyUpdate.ps1 not found at $mainScript"
    exit 1
}

$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$mainScript`" -ConfigPath `"$ConfigPath`""

$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument $arguments `
    -WorkingDirectory $scriptDir

# Build the trigger (weekly)
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dayOfWeek -At $timeOfDay

# Build settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 5)

# Build principal (who runs the task)
if ($RunAs) {
    Write-Host ""
    Write-Host "The task will run as: $RunAs" -ForegroundColor Yellow
    Write-Host "You will be prompted for the password." -ForegroundColor Yellow
    $principal = New-ScheduledTaskPrincipal -UserId $RunAs -LogonType Password -RunLevel Highest
    $credential = Get-Credential -UserName $RunAs -Message "Enter credentials for the scheduled task"
    $password = $credential.GetNetworkCredential().Password
} else {
    Write-Host ""
    Write-Host "The task will run as: SYSTEM (no password required)" -ForegroundColor Gray
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $password = $null
}

# Register the task
Write-Host ""
Write-Host "Creating scheduled task..." -ForegroundColor Yellow

try {
    $taskParams = @{
        TaskName  = $taskName
        Action    = $action
        Trigger   = $trigger
        Settings  = $settings
        Principal = $principal
        Force     = $true
    }
    
    if ($password) {
        $taskParams.User = $RunAs
        $taskParams.Password = $password
    }
    
    Register-ScheduledTask @taskParams | Out-Null
    
    Write-Host ""
    Write-Host "[OK] Scheduled task created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    
    $task = Get-ScheduledTask -TaskName $taskName
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    
    Write-Host "  Name:           $($task.TaskName)" -ForegroundColor Gray
    Write-Host "  State:          $($task.State)" -ForegroundColor Gray
    Write-Host "  Next Run Time:  $($taskInfo.NextRunTime)" -ForegroundColor Gray
    Write-Host "  Last Run Time:  $($taskInfo.LastRunTime)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Yellow
    Write-Host "  # Run task manually:" -ForegroundColor Gray
    Write-Host "  Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Check task status:" -ForegroundColor Gray
    Write-Host "  Get-ScheduledTask -TaskName '$taskName' | Select-Object State" -ForegroundColor White
    Write-Host ""
    Write-Host "  # View last run result:" -ForegroundColor Gray
    Write-Host "  Get-ScheduledTaskInfo -TaskName '$taskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Uninstall task:" -ForegroundColor Gray
    Write-Host "  .\Install-WeeklyUpdateTask.ps1 -Uninstall" -ForegroundColor White
    
    # Test run if requested
    if ($Test) {
        Write-Host ""
        Write-Host "Starting test run..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $taskName
        
        Start-Sleep -Seconds 3
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        Write-Host "Task started. Check logs at: $($config.paths.logsBase)" -ForegroundColor Gray
    }
    
} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}

Write-Host ""
