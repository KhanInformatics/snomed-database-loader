$root = Split-Path -Parent $PSScriptRoot
Import-Module "$root/Reporting/TerminologyPublicReport.psm1" -Force

function New-TestResults {
    @{RunId='abcdef12-1234-4321-9876-123456789012'; StartTime='2026-09-05T11:00:01Z'; EndTime='2026-09-05T11:20:07Z'; Duration='00:20:06'; Success=$true; UpdatesFound=0; Errors=@(); SNOMED=@{Success=$true; NewRelease=$false; Steps=@()}}
}

Describe 'Public terminology report boundary' {
    It 'represents no release and deliberately skipped products distinctly' {
        $run = ConvertTo-PublicTerminologyRun (New-TestResults)
        $run.products[0].status | Should Be 'current'
        $run.products[1].status | Should Be 'skipped'
        $run.products.Count | Should Be 4
    }
    It 'preserves release counts and changes while dropping private fields' {
        $r = New-TestResults
        $r.DMD = @{Success=$true;NewRelease=$true;ReleaseVersion='2026.9';TableCounts=@{amp=167099;secret_database=123};TableChanges=@{amp=65};Steps=@(@{Name='Collect table statistics';Success=$true;Details='Password=secret; 81.136.120.231 C:\private';Duration='00:04'})}
        $r.LogFile='C:\private'; $r.SNOMED.ReleaseName='secret server'; $r.SNOMED.ReleaseVersion='https://private'
        $run = ConvertTo-PublicTerminologyRun $r
        $run.products[1].status | Should Be 'updated'
        $run.products[1].metrics[0].change | Should Be 65
        ($run | ConvertTo-Json -Depth 15) | Should Not Match 'secret|81\.136|private|Password|LogFile'
    }
    It 'cannot hide a failed step behind successful group and overall flags' {
        $r = New-TestResults
        $r.SNOMED.Steps=@(@{Name='arbitrary private step';Success=$false;Details='token=secret';Duration='00:02'})
        $run = ConvertTo-PublicTerminologyRun $r
        $run.status | Should Be 'failed'
        $run.products[0].status | Should Be 'failed'
        $run.products[0].steps[0].name | Should Be 'Update step'
    }
    It 'does not claim failed reporting means the terminology import failed' {
        $r = New-TestResults; $r.Success=$false; $r.Errors=@('Azure SQL export failed: private IP address')
        $run = ConvertTo-PublicTerminologyRun $r
        $run.status | Should Be 'failed'
        $run.products[0].status | Should Be 'current'
        $run.issues[0] | Should Be 'The previous Azure SQL report export failed.'
    }
    It 'rejects synthetic WhatIf results' {
        $r = New-TestResults; $r.WhatIf=$true
        $caught=$false
        try { ConvertTo-PublicTerminologyRun $r } catch { $caught=$true }
        $caught | Should Be $true
    }
    It 'WhatIf never even reads the config or writes a report' {
        $r = & "$root/Export-ReportToGitHub.ps1" -ReplayPath 'missing.json' -ConfigPath 'missing.json' -WhatIf
        $r.Preview | Should Be $true
    }
}

Describe 'GitHub history publishing' {
    BeforeEach {
        $script:run = ConvertTo-PublicTerminologyRun (New-TestResults)
    }
    It 'does not create another commit for an identical replay' {
        $global:testReport = @{schemaVersion=1;generatedAt='2026-09-05T11:20:08Z';runs=@($script:run)}
        Mock Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport { @{sha='old';content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($global:testReport | ConvertTo-Json -Depth 20)))} }
        $result = Publish-TerminologyRun -Run $script:run -Repository 'owner/repo'
        $result.Changed | Should Be $false
        Assert-MockCalled Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport -Times 0 -ParameterFilter {$Method -eq 'PUT'}
    }
    It 'merges on a conflict using the freshly read file SHA' {
        $global:testGets=0; $global:testPuts=0; $global:usedSha=''
        Mock Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport {
            if ($Method -eq 'PUT') {
                $global:testPuts++
                if ($global:testPuts -eq 1) { $ex=[Exception]::new('conflict');$ex.Data['StatusCode']=409;throw $ex }
                $global:usedSha=$Body.sha
                return @{commit=@{sha='newcommit'}}
            }
            $global:testGets++
            @{sha="sha$global:testGets";content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"schemaVersion":1,"runs":[]}'))}
        }
        $result = Publish-TerminologyRun -Run $script:run -Repository 'owner/repo' -RetryDelaySeconds 0
        $global:usedSha | Should Be 'sha2'
        $result.CommitSha | Should Be 'newcommit'
    }
    It 'preserves a later issue resolution when replaying the original failed run' {
        $r=New-TestResults; $r.Success=$false; $r.Errors=@('Azure SQL export failed: original error')
        $original=ConvertTo-PublicTerminologyRun $r
        $annotated=ConvertTo-PublicTerminologyRun $r
        $annotated.resolvedIssues=@(@{issue='The previous Azure SQL report export failed.';resolvedAt='2026-09-08T15:00:00Z';resolution='Reports now publish through GitHub Actions. The legacy Azure SQL report export is disabled.'})
        $global:testReport=@{schemaVersion=1;runs=@($annotated)}
        Mock Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport { @{sha='old';content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($global:testReport | ConvertTo-Json -Depth 20)))} }
        $result=Publish-TerminologyRun -Run $original -Repository 'owner/repo'
        $result.Changed | Should Be $false
        $original.status | Should Be 'failed'
        $original.resolvedIssues.Count | Should Be 1
    }
    It 'retains 52 newest runs when replaying an old report' {
        $global:history=@(1..52 | ForEach-Object { $r=New-TestResults; $r.RunId=[guid]::NewGuid().ToString(); $r.StartTime=([datetimeoffset]'2026-09-05T12:00:00Z').AddDays($_); $r.EndTime=([datetimeoffset]$r.StartTime).AddMinutes(10); ConvertTo-PublicTerminologyRun $r })
        $global:posted=$null
        Mock Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport {
            if ($Method -eq 'PUT') { $global:posted=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Body.content)) | ConvertFrom-Json; return @{commit=@{sha='x'}} }
            @{sha='old';content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((@{schemaVersion=1;runs=$global:history} | ConvertTo-Json -Depth 25)))}
        }
        Publish-TerminologyRun -Run $script:run -Repository 'owner/repo' | Out-Null
        $global:posted.runs.Count | Should Be 52
        @($global:posted.runs | Where-Object runId -eq $script:run.runId).Count | Should Be 0
    }
    It 'fails immediately for missing authentication' {
        Mock Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport { $ex=[Exception]::new('unauthorized');$ex.Data['StatusCode']=401;throw $ex }
        $caught=$false
        try { Publish-TerminologyRun -Run $script:run -Repository 'owner/repo' -RetryDelaySeconds 0 } catch { $caught=$true }
        $caught | Should Be $true
        Assert-MockCalled Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport -Times 1 -Exactly -Scope It
    }
    It 'retains installed version and last update on a no-release week' {
        $r=New-TestResults
        $prior=ConvertTo-PublicTerminologyRun $r
        $prior.products[0].releaseVersion='42.5.0'; $prior.products[0].lastUpdated='2026-09-05'
        $r.RunId=[guid]::NewGuid().ToString();$r.StartTime='2026-09-12T11:00:01Z';$r.EndTime='2026-09-12T11:10:00Z'
        $next=ConvertTo-PublicTerminologyRun $r
        $global:testReport=@{schemaVersion=1;runs=@($prior)}
        Mock Invoke-ReportGitHubApi -ModuleName TerminologyPublicReport {
            if ($Method -eq 'PUT') { return @{commit=@{sha='new'}} }
            @{sha='old';content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($global:testReport | ConvertTo-Json -Depth 20)))}
        }
        Publish-TerminologyRun -Run $next -Repository 'owner/repo' | Out-Null
        $next.products[0].releaseVersion | Should Be '42.5.0'
        $next.products[0].lastUpdated | Should Be '2026-09-05'
    }
    It 'does not give a failed new import a new installed version or update date' {
        $r=New-TestResults; $r.SNOMED.Success=$false;$r.SNOMED.NewRelease=$true;$r.SNOMED.ReleaseVersion='43.0.0'
        $run=ConvertTo-PublicTerminologyRun $r
        $run.products[0].releaseVersion | Should BeNullOrEmpty
        $run.products[0].lastUpdated | Should BeNullOrEmpty
    }
}
Describe 'Replay storage' {
    It 'saves private and public reports locally without an upload in SaveOnly mode' {
        $localConfig = Join-Path $TestDrive 'config.json'
        @{paths=@{logsBase=(Get-Item TestDrive:\).FullName};githubReporting=@{enabled=$true;repository='owner/repo';branch='main'}} | ConvertTo-Json -Depth 5 | Set-Content $localConfig
        $r=New-TestResults; $r.Errors=@('Azure SQL export failed: private-password');$r.Success=$false
        $result = & "$root/Export-ReportToGitHub.ps1" -Results $r -ConfigPath $localConfig -SaveOnly
        Test-Path -LiteralPath $result.SavedPath | Should Be $true
        (Get-Content -LiteralPath $result.SavedPath -Raw) | Should Match 'private-password'
        $publicPath=Join-Path $TestDrive "GitHubReports/$($r.RunId).public.json"
        (Get-Content -LiteralPath $publicPath -Raw) | Should Not Match 'private-password'
        $saved=(Get-Content -LiteralPath $result.SavedPath -Raw | ConvertFrom-Json)
        $saved.RunId | Should Be $r.RunId
    }
}
