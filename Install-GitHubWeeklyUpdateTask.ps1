#Requires -Version 7.5
<# Installs and tests the credential-backed weekly task. Enter credentials locally only. #>
[CmdletBinding()]
param([string]$ConfigPath)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    throw 'Run the saved file instead of pasting its contents: pwsh -NoProfile -File ".\Install-GitHubWeeklyUpdateTask.ps1"'
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath=Join-Path $PSScriptRoot 'Config/TerminologyConfig.json'
}
$configPath=(Resolve-Path -LiteralPath $ConfigPath).Path
$config=Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$taskName=$config.schedule.taskName
$executable=(Get-Command pwsh -CommandType Application).Source
$wrapper=Join-Path $PSScriptRoot 'Invoke-WeeklyUpdateTask.ps1'
$arguments="-NoProfile -NonInteractive -WindowStyle Hidden -File `"$wrapper`" -ConfigPath `"$ConfigPath`""
$action=New-ScheduledTaskAction -Execute $executable -Argument $arguments -WorkingDirectory $PSScriptRoot
$trigger=New-ScheduledTaskTrigger -Weekly -DaysOfWeek $config.schedule.dayOfWeek -At $config.schedule.timeOfDay
# Do not restart a full database import just because publishing failed.
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4)
Write-Host 'Set up Saturday terminology updates and GitHub publishing.' -ForegroundColor Cyan
Write-Host "Enter the Windows password for $account (not your PIN). It is passed directly to Windows Task Scheduler."
$credential=Get-Credential -UserName $account -Message 'Windows credentials for the Saturday terminology task'
if (-not $credential -or $credential.UserName -ine $account) { throw 'Use the current Windows account so its stored credentials remain accessible.' }
$plainPassword=$credential.GetNetworkCredential().Password
$probeName="$taskName-GitHubPreflight"
try {
    $probeAction=New-ScheduledTaskAction -Execute $executable -Argument "$arguments -CheckOnly" -WorkingDirectory $PSScriptRoot
    Register-ScheduledTask -TaskName $probeName -Action $probeAction -Settings $settings -User $account -Password $plainPassword -RunLevel Limited -Force | Out-Null
    $probeStart=Get-Date
    Start-ScheduledTask -TaskName $probeName
    $deadline=(Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Seconds 2
        $info=Get-ScheduledTaskInfo -TaskName $probeName
        $state=(Get-ScheduledTask -TaskName $probeName).State
    } while (($info.LastRunTime -lt $probeStart.AddSeconds(-1) -or $state -eq 'Running') -and (Get-Date) -lt $deadline)
    $preflight=Get-Content (Join-Path $config.paths.logsBase 'WeeklyTaskPreflight.json') -Raw | ConvertFrom-Json
    if ($state -eq 'Running' -or $info.LastTaskResult -ne 0 -or -not $preflight.Success -or [datetimeoffset]$preflight.CheckedAt -lt $probeStart.ToUniversalTime()) { throw 'Scheduled credential test failed. Check WeeklyTaskPreflight.json in the log folder.' }
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User $account -Password $plainPassword -RunLevel Limited -Force | Out-Null
    @{Success=$true;Account=$account;InstalledAt=[datetimeoffset]::UtcNow.ToString('o');NextRun=(Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime} | ConvertTo-Json | Set-Content (Join-Path $config.paths.logsBase 'WeeklyTaskInstallation.json')
    Write-Host 'Saturday task installed. GitHub, TRUD credentials and local SQL access verified in the scheduled account.' -ForegroundColor Green
} finally {
    $plainPassword=$null
    $credential=$null
    if (Get-ScheduledTask -TaskName $probeName -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $probeName -Confirm:$false }
}
