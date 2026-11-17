# Only this projection crosses the boundary from private operational logs to the website.
$script:StepNames = @(
    'Check for new SNOMED release', 'Import SNOMED to database', 'Validate SNOMED import',
    'Check for new DMD release', 'Download DMD release', 'Import DMD to database',
    'Collect table statistics', 'Validate DMD against XML', 'Validate DMD against SNOMED CT',
    'Check for new DMWB release', 'Download DMWB release', 'Export DMWB to SQL Server',
    'Validate DMWB export', 'Validate current PCD RF2 snapshot',
    'Load current PCD supporting products', 'Validate current PCD supporting products',
    'Inspect legacy PCD enrichment tables', 'Skip'
)

function Get-PublicDuration {
    param($Value)
    if ([string]$Value -match '^\d{2,}:\d{2}(:\d{2})?$') { return [string]$Value }
    return '00:00'
}

function ConvertTo-PublicTerminologyRun {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Results)
    if ($Results.WhatIf) { throw 'Preview results cannot be published.' }
    if (-not $Results.RunId -or -not $Results.StartTime -or -not $Results.EndTime) {
        throw 'RunId, StartTime and EndTime are required.'
    }
    $runId = ([guid]$Results.RunId).ToString()
    $start = [datetimeoffset]$Results.StartTime
    $end = [datetimeoffset]$Results.EndTime
    if ($end -lt $start) { throw 'EndTime must follow StartTime.' }
    $products = @()
    $labels = @{ SNOMED='SNOMED CT'; DMD='dm+d'; DMWB='DMWB'; PCD='PCD refsets' }
    foreach ($key in @('SNOMED', 'DMD', 'DMWB', 'PCD')) {
        $group = $Results[$key]
        $status = if ($null -eq $group) { 'skipped' } elseif (-not $group.Success) { 'failed' } elseif ($group.NewRelease) { 'updated' } else { 'current' }
        if ($null -eq $group) { $group = @{} }
        $steps = @(foreach ($step in $group.Steps) {
            # Never copy Details, exception text, or dynamically supplied step names.
            $name = if ($step.Name -cin $script:StepNames) { [string]$step.Name } else { 'Update step' }
            $stepStatus = if (-not $step.Success) { 'failed' } elseif ($name -eq 'Skip') { 'skipped' } else { 'completed' }
            [ordered]@{ name=$name; status=$stepStatus; duration=(Get-PublicDuration $step.Duration) }
        })
        if (@($steps | Where-Object status -eq 'failed').Count) { $status = 'failed' }
        $metrics = @()
        $countMap = switch ($key) {
            SNOMED { [ordered]@{curr_concept_f='Concepts'; curr_description_f='Descriptions'; curr_relationship_f='Relationships'; curr_langrefset_f='Language refset rows'} }
            DMD { [ordered]@{vtm='VTM'; vmp='VMP'; amp='AMP'; vmpp='VMPP'; ampp='AMPP'; ingredient='Ingredients'; lookup='Lookups'} }
            PCD { [ordered]@{GPData_Cluster_Refset='GPData rows'; GDPPR_Cluster_Refset='GDPPR rows'; Refset_Content_by_Output='Legacy output rows'; Refset_Content_V2='Legacy refset rows'; Ruleset_Full_Name_Mappings_V2='Legacy ruleset mappings'; Service_Full_Name_Mappings_V2='Legacy service mappings'; Output_Descriptions_V2='Legacy output descriptions'} }
            default { @{} }
        }
        $counts = if ($key -eq 'SNOMED') { $group.RowCounts } else { $group.TableCounts }
        if ($null -eq $counts) { $counts = @{} }
        foreach ($table in $countMap.Keys) {
            $value = $counts[$table]
            if ($null -eq $value -and $key -eq 'PCD') { $value = $counts["PCD_$table"] }
            if ($null -ne $value -and [string]$value -match '^\d+$') {
                $change = $null
                if ($key -eq 'DMD' -and $group.TableChanges -and $null -ne $group.TableChanges[$table] -and [string]$group.TableChanges[$table] -match '^-?\d+$') { $change = [long]$group.TableChanges[$table] }
                $metrics += [ordered]@{label=$countMap[$table]; value=[long]$value; change=$change}
            }
        }
        if ($key -eq 'DMWB' -and $group.TableCounts.Count) {
            $metrics += [ordered]@{label='Tables'; value=[long]$group.TableCounts.Count; change=$null}
            $metrics += [ordered]@{label='Total records'; value=[long](($group.TableCounts.Values | Measure-Object -Sum).Sum); change=$null}
        }
        $checks = @(if ($key -eq 'PCD') {
            foreach ($item in @(@('RF2Status','Official RF2'), @('GPDataStatus','GPData'), @('GDPPRStatus','GDPPR'))) {
                $value = [string]$group[$item[0]]
                if ($value -cnotin @('Current','Mismatch','Failed','Unknown')) { $value = 'Unknown' }
                [ordered]@{label=$item[1]; value=$value}
            }
            if ($group.LegacyStatus -like 'N/A - not supplied in *') { [ordered]@{label='Legacy enrichment'; value='Not supplied in this release'} }
        })
        $version = if ([string]$group.ReleaseVersion -match '^\d{1,8}(\.\d{1,8}){1,4}$') { [string]$group.ReleaseVersion } else { $null }
        $releaseDate = if ([string]$group.ReleaseDate -match '^\d{4}-\d{2}-\d{2}$') { [string]$group.ReleaseDate } else { $null }
        $lastUpdated = if ([string]$group.LastUpdated -match '^\d{4}-\d{2}-\d{2}$') { [string]$group.LastUpdated } elseif ($status -eq 'updated') { $end.ToLocalTime().ToString('yyyy-MM-dd') } else { $null }
        # A failed update does not establish which release is installed.
        if ($status -eq 'failed') { $version=$null; $releaseDate=$null; $lastUpdated=$null }
        $products += [ordered]@{id=$key.ToLowerInvariant(); name=$labels[$key]; status=$status; releaseVersion=$version; releaseDate=$releaseDate; lastUpdated=$lastUpdated; metrics=$metrics; checks=$checks; steps=$steps}
    }
    $issues = @()
    foreach ($product in $products | Where-Object status -eq 'failed') { $issues += "$($product.name) update or validation failed. See the private update log for details." }
    foreach ($errorText in $Results.Errors) {
        if ([string]$errorText -like 'Azure SQL export failed:*') { $issues += 'The previous Azure SQL report export failed.' }
        elseif ([string]$errorText -like 'Email notification failed:*') { $issues += 'The email notification failed.' }
        elseif (-not $issues.Count) { $issues += 'The update encountered an error. See the private update log for details.' }
    }
    $success = [bool]$Results.Success -and -not $Results.Errors.Count -and -not @($products | Where-Object status -eq 'failed').Count
    if (-not $success -and -not $issues.Count) { $issues += 'The update encountered an error. See the private update log for details.' }
    [ordered]@{
        runId=$runId
        startedAt=$start.ToUniversalTime().ToString('o')
        completedAt=$end.ToUniversalTime().ToString('o')
        duration=(Get-PublicDuration $Results.Duration)
        status=$(if ($success) { 'success' } else { 'failed' })
        updatesFound=[int]$Results.UpdatesFound
        products=$products
        issues=@($issues | Select-Object -Unique)
    }
}

function Invoke-ReportGitHubApi {
    param([string]$Endpoint, [string]$Method='GET', $Body)
    # gh reads the existing Windows keyring. Tokens never pass through our files/output.
    $args = @('api', '--hostname', 'github.com', '--method', $Method, $Endpoint)
    if ($null -ne $Body) {
        $json = ConvertTo-Json $Body -Depth 30 -Compress
        $output = $json | & gh @args --input - 2>&1
    } else { $output = & gh @args 2>&1 }
    if ($LASTEXITCODE -ne 0) {
        $text = $output | Out-String
        $status = if ($text -match 'HTTP (\d{3})') { [int]$Matches[1] } else { 0 }
        $error = [InvalidOperationException]::new("GitHub report request failed (HTTP $status). Check authentication and repository access.")
        $error.Data['StatusCode'] = $status
        throw $error
    }
    ($output -join "`n") | ConvertFrom-Json -AsHashtable
}

function Publish-TerminologyRun {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Run, [Parameter(Mandatory)][string]$Repository, [string]$Branch='main', [string]$Path='wwwroot/data/terminology-updates.json', [int]$RetryDelaySeconds=5)
    if ($Repository -notmatch '^[\w.-]+/[\w.-]+$') { throw 'Invalid repository.' }
    $endpoint = "repos/$Repository/contents/$Path"
    for ($attempt=1; $attempt -le 3; $attempt++) {
        try {
            $existing = $null
            try { $existing = Invoke-ReportGitHubApi -Endpoint "$endpoint`?ref=$([uri]::EscapeDataString($Branch))" }
            catch { if ($_.Exception.Data['StatusCode'] -ne 404) { throw } }
            $history = @()
            if ($existing) {
                $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($existing.content)) | ConvertFrom-Json -AsHashtable -DateKind String
                if ($decoded.schemaVersion -ne 1) { throw 'Unsupported report history schema; refusing to overwrite it.' }
                $history = @($decoded.runs)
                $isReplay = @($history | Where-Object runId -eq $Run.runId).Count -gt 0
                foreach ($product in $Run.products) {
                    $previous = @($history | Where-Object { [datetimeoffset]$_.startedAt -le [datetimeoffset]$Run.startedAt } | Sort-Object { [datetimeoffset]$_.startedAt } -Descending | ForEach-Object { $_.products | Where-Object { $_.id -eq $product.id -and $_.releaseVersion } } | Select-Object -First 1)
                    if ($previous.Count -and $product.status -ne 'skipped') {
                        $prior=$previous[0]
                        if (-not $product.releaseVersion -and ($product.status -ne 'updated' -or $isReplay)) { $product.releaseVersion=$prior.releaseVersion; $product.releaseDate=$prior.releaseDate }
                        if ($product.releaseVersion -eq $prior.releaseVersion) {
                            if (-not $product.releaseDate) { $product.releaseDate=$prior.releaseDate }
                            if (-not $product.lastUpdated) { $product.lastUpdated=$prior.lastUpdated }
                        }
                    }
                }
                $same = @($history | Where-Object runId -eq $Run.runId)
                # Resolution is an audited later event, not a changed import outcome.
                # A replay of the original results must not erase that annotation.
                if ($same.Count -and $same[0].resolvedIssues) {
                    $Run['resolvedIssues'] = @($same[0].resolvedIssues | Where-Object { $_.issue -in $Run.issues })
                }
                if ($same.Count -and (ConvertTo-Json $same[0] -Depth 30 -Compress) -ceq (ConvertTo-Json $Run -Depth 30 -Compress)) { return @{Success=$true; Changed=$false; RunId=$Run.runId} }
            }
            $history = @(@($history | Where-Object runId -ne $Run.runId) + @($Run) | Sort-Object { [datetimeoffset]$_.startedAt } -Descending | Select-Object -First 52)
            $document = [ordered]@{schemaVersion=1; generatedAt=[datetimeoffset]::UtcNow.ToString('o'); runs=$history}
            $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $document -Depth 30))
            if ($bytes.Length -gt 900000) { throw 'Report history exceeds the 900 KB publishing limit.' }
            $body = @{message="Update weekly terminology report ($($Run.runId))"; branch=$Branch; content=[Convert]::ToBase64String($bytes)}
            if ($existing) { $body.sha = $existing.sha }
            $commit = Invoke-ReportGitHubApi -Endpoint $endpoint -Method PUT -Body $body
            return @{Success=$true; Changed=$true; RunId=$Run.runId; CommitSha=$commit.commit.sha}
        } catch {
            $status = $_.Exception.Data['StatusCode']
            if ($attempt -eq 3 -or $null -eq $status -or $status -in @(401,403,404,422)) { throw }
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

Export-ModuleMember -Function ConvertTo-PublicTerminologyRun, Publish-TerminologyRun, Invoke-ReportGitHubApi
