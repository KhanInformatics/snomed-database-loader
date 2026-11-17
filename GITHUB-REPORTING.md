# Weekly website reports

The **Server Status** page at `/terminology-dashboard` (also `/terminology`) now
reads `wwwroot/data/terminology-updates.json` from the website itself. There are
no SQL, Azure Function, Blob or GitHub API requests from this page. Loading or
refreshing the report makes one static file request; changing history is local.

## Saturday publishing

`Weekly-TerminologyUpdate.ps1` assigns a run ID at startup. After imports,
validations and notifications, it passes the outcome to `Export-ReportToGitHub.ps1`,
including failed and unchanged runs. PowerShell **7.5 or newer** and an authenticated
GitHub CLI are required. The configured Windows account needs repository contents
write access, its existing TRUD credential and local SQL permissions.

Enable `githubReporting.enabled` in the local configuration, with repository
`KhanInformatics/StaticBlazorSnomed` and branch `main`. The publisher saves private
results and a public projection under `<logsBase>/GitHubReports`, then updates
only the report JSON through GitHub's Contents API. It does not stage or push a
local working tree. It merges against the current file SHA, retries temporary
failures up to three times and retains the latest 52 runs. An identical replay
does not create another commit.

Each report commit triggers the website's existing GitHub Actions deployment.
The workflow validates the strict public schema and serializes deployments.
`generatedAt` means report data preparation, not confirmation of deployment.
The old static page remains available if publishing or deployment fails.

Only selected product names, step names, status values, release numbers/dates,
counts, changes and fixed issue summaries are public. Raw step output, arbitrary
exception text, paths, hostnames, account names and credentials stay local.
Missing releases or metrics remain absent. A reporting failure does not change
a successful product import into a failed product import.

## Install the scheduled task

Run `Install-GitHubWeeklyUpdateTask.ps1` in a local PowerShell window. Enter the
current account's Windows password locally, never in chat or a command argument.
The installer creates a temporary credential-backed task which checks GitHub,
TRUD credential access and local SQL, then installs `WeeklyTerminologyUpdate` for
Saturday at 12:00 in the Windows timezone (this machine uses GMT Standard Time).
It runs while signed out, catches up after downtime and ignores overlapping runs.
It does not automatically restart the full import on a reporting failure.

The task runs `Invoke-WeeklyUpdateTask.ps1`. Its `-CheckOnly` mode performs no
imports, publishes no report and sends no email. Check `WeeklyTaskPreflight.json`
and `WeeklyTaskInstallation.json` in the private log directory for setup results.
An unavailable GitHub service does not prevent the normal weekly imports.

## Replay a failed upload

```powershell
./Export-ReportToGitHub.ps1 -ReplayPath 'C:/TerminologyLogs/GitHubReports/<run-id>.results.json'
```

This only saves/publishes that report. It never imports data or sends email.
`-SaveOnly` prepares local reports without contacting GitHub. `-WhatIf` does not
read a config, write a report, or make a network call. Results marked WhatIf are
rejected by the public projection as well.

Once a real report is verified on the deployed page, set
`azureReporting.enabled` and `azureBlobStorage.enabled` to false. Do not delete
their resources: other applications may still use them. To roll back reporting,
disable GitHub publishing and explicitly re-enable the required previous exporter.

The initial September 5 report was reconstructed from the supplied email and
the original transcript, without rerunning imports. Its final duration is 20:06
from the transcript; the email's 09:17 omitted reporting retries. That historical
run correctly remains failed because its Azure SQL report export failed.

On 8 September 2026 its reporting issue was explicitly marked resolved after
verifying GitHub publishing and disabling the legacy SQL exporter. Optional
`resolvedIssues` annotations preserve the original failed outcome and describe
the dated remedy. The page distinguishes resolved issues from active failures;
unrelated failures remain visible. Replaying old results preserves matching
resolution annotations already recorded in GitHub.

## Verification

```powershell
Invoke-Pester -Script Tests/GitHubReportExport.Tests.ps1
./Invoke-WeeklyUpdateTask.ps1 -CheckOnly
```

In the website checkout, run `dotnet build`,
`python Tools/test_validate_terminology_report.py`,
`python Tools/validate_terminology_report.py`, and
`dotnet run --project Tools/ScheduleChecks/ScheduleChecks.csproj`.
Browser tests in `Tools/test_terminology_browser.py` take a local site URL, a
saved public run JSON and an output directory. Their synthetic states are
intercepted in an isolated test browser and are never written to production.

The page displays UK time and flags a missing run after Saturday 16:30. It shows
the latest completed report, not progress while an import is running. Reports
and deployment use the existing static hosting and included Actions allowance;
the account's $0 paid Actions budget should remain in place.

### Installed versions and update dates
The static Status column shows each product's installed version, release date and last successful update date. These describe the selected report, not the date a visitor loads the page. Successful imports establish the update date; checks with no new release retain the previously confirmed version and date. Failed imports retain only the last confirmed metadata and label it accordingly. Missing historical metadata is displayed as "Not recorded". The September 2026 report was enriched from successful local import records; its original outcome and resolution annotation are preserved.
