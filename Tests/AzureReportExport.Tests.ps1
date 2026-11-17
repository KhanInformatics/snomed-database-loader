$exportScript = Join-Path (Split-Path -Parent $PSScriptRoot) "Export-ReportToAzure.ps1"
$parseTokens = $null
$parseErrors = $null
$exportAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $exportScript, [ref]$parseTokens, [ref]$parseErrors
)

# Load helpers without executing the script or reading production configuration.
foreach ($functionName in @("Get-RedactedErrorMessage", "Get-AzureSqlFirewallDenial", "Invoke-AzureSql")) {
    $functionAst = $exportAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
    }, $true)
    . ([scriptblock]::Create($functionAst.Extent.Text))
}

# Pester 3 requires commands to exist before they can be mocked. These stubs
# also make accidental unmocked calls fail without touching credentials or SQL.
if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
    function Invoke-Sqlcmd {
        [CmdletBinding()]
        param([string]$ConnectionString, [string]$Query)
        throw "Unmocked SQL call in Azure exporter test"
    }
}
if (-not (Get-Command Get-StoredCredential -ErrorAction SilentlyContinue)) {
    function Get-StoredCredential {
        param([string]$Target)
        throw "Unmocked credential lookup in Azure exporter test"
    }
}

Describe "Azure SQL connection failure handling" {
    BeforeEach {
        Mock Start-Sleep {}
        $script:sqlAttempts = 0
    }

    It "parses without PowerShell syntax errors" {
        @($parseErrors).Count | Should Be 0
    }

    It "fails immediately with the denied IP and server instead of retrying unchanged" {
        Mock Invoke-Sqlcmd {
            throw "Cannot open server 'azuresnnomedct' requested by the login. Client with IP address '81.136.120.231' is not allowed to access the server."
        }

        $failure = $null
        try {
            Invoke-AzureSql -ConnectionString "mock" -Query "SELECT 1" -MaxRetries 2 -RetryDelaySeconds 1
        } catch { $failure = $_.Exception.Message }

        $failure | Should Match "firewall denied client IP '81.136.120.231' on server 'azuresnnomedct'"
        $failure | Should Match 'allow that single IP'
        $failure | Should Match 'ConnectionTestOnly'
        Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -Scope It
        Assert-MockCalled Start-Sleep -Times 0 -Exactly -Scope It
    }

    It "recognizes error 40615 through an inner provider exception" {
        Mock Invoke-Sqlcmd {
            $providerError = [System.InvalidOperationException]::new("Provider denied network access")
            $providerError | Add-Member -NotePropertyName Number -NotePropertyValue 40615
            throw [System.InvalidOperationException]::new("SQL command failed", $providerError)
        }

        { Invoke-AzureSql -ConnectionString "mock" -Query "SELECT 1" -MaxRetries 2 -RetryDelaySeconds 1 } |
            Should Throw 'firewall denied'
        Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -Scope It
        Assert-MockCalled Start-Sleep -Times 0 -Exactly -Scope It
    }

    It "does not mistake a login failure for a firewall denial" {
        $loginError = [System.InvalidOperationException]::new("Cannot open server 'mock' requested by the login. The login failed.")
        Get-AzureSqlFirewallDenial -Exception $loginError | Should BeNullOrEmpty
    }

    It "retries transient connection failures and then succeeds" {
        Mock Invoke-Sqlcmd {
            $script:sqlAttempts++
            if ($script:sqlAttempts -lt 3) { throw "Database is temporarily unavailable" }
            return 1
        }

        Invoke-AzureSql -ConnectionString "mock" -Query "SELECT 1" -MaxRetries 2 -RetryDelaySeconds 1 -WarningAction SilentlyContinue

        Assert-MockCalled Invoke-Sqlcmd -Times 3 -Exactly -Scope It
        Assert-MockCalled Start-Sleep -Times 2 -Exactly -Scope It
    }

    It "stops after the configured retries are exhausted" {
        Mock Invoke-Sqlcmd { throw "Database is temporarily unavailable" }

        { Invoke-AzureSql -ConnectionString "mock" -Query "SELECT 1" -MaxRetries 2 -WarningAction SilentlyContinue } |
            Should Throw 'failed after 3 attempt(s)'
        Assert-MockCalled Invoke-Sqlcmd -Times 3 -Exactly -Scope It
        Assert-MockCalled Start-Sleep -Times 0 -Exactly -Scope It
    }

    It "redacts credentials in a firewall failure" {
        Mock Invoke-Sqlcmd {
            throw "Client with IP address '81.136.120.231' is not allowed to access the server. User ID=private-login;Password=private-password;Pwd=private-short-password;UID=private-uid;Access Token=private-token;"
        }
        $failure = $null
        try {
            Invoke-AzureSql -ConnectionString "mock" -Query "SELECT 1" -MaxRetries 2
        } catch { $failure = $_.Exception.Message }

        $failure | Should Match 'firewall denied'
        $failure | Should Match '<redacted>'
        $failure | Should Not Match 'private-'
    }
}

Describe "Azure SQL exporter connection-only mode" {
    BeforeEach {
        $global:AzureExportTestQueries = @()
        $fixtureConfigPath = Join-Path $TestDrive "azure-test-config.json"
        @{
            azureReporting = @{
                server = "mock.database.windows.net"
                database = "ReportingTest"
                sqlCredentialTarget = "mock-credential"
                connectionTimeout = 1
            }
            options = @{ retryOnFailure = $true; maxRetries = 2; retryDelaySeconds = 0 }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $fixtureConfigPath -Encoding UTF8

        Mock Import-Module {} -ParameterFilter { $Name -eq "CredentialManager" }
        Mock Get-StoredCredential {
            [pscredential]::new("mock-user", (ConvertTo-SecureString "mock-password" -AsPlainText -Force))
        }
        Mock Invoke-Sqlcmd {
            $global:AzureExportTestQueries += $Query
            return 1
        }
        Mock Start-Sleep {}
    }

    AfterEach {
        Remove-Variable AzureExportTestQueries -Scope Global -ErrorAction SilentlyContinue
    }

    It "executes only SELECT 1 without requiring Results or inserting a report" {
        $result = & $exportScript -ConnectionTestOnly -ConfigPath $fixtureConfigPath

        $result.Success | Should Be $true
        $result.ConnectionTestOnly | Should Be $true
        $result.Database | Should Be "ReportingTest"
        $global:AzureExportTestQueries.Count | Should Be 1
        $global:AzureExportTestQueries[0] | Should Be "SELECT 1"
        Assert-MockCalled Get-StoredCredential -Times 1 -Exactly -Scope It -ParameterFilter { $Target -eq "mock-credential" }
    }

    It "cannot enter export mode by passing a false connection-test switch" {
        $result = & $exportScript -ConnectionTestOnly:$false -ConfigPath $fixtureConfigPath

        $result.ConnectionTestOnly | Should Be $true
        $global:AzureExportTestQueries.Count | Should Be 1
        $global:AzureExportTestQueries[0] | Should Be "SELECT 1"
    }

    It "requires Results for the normal export parameter set" {
        $exportSet = (Get-Command $exportScript).ParameterSets | Where-Object { $_.Name -eq "Export" }
        ($exportSet.Parameters | Where-Object { $_.Name -eq "Results" }).IsMandatory | Should Be $true
    }

    It "does not write anything when the connection test is denied by the firewall" {
        Mock Invoke-Sqlcmd {
            $global:AzureExportTestQueries += $Query
            throw "Client with IP address '81.136.120.231' is not allowed to access the server."
        }

        { & $exportScript -ConnectionTestOnly -ConfigPath $fixtureConfigPath } | Should Throw 'firewall denied'
        $global:AzureExportTestQueries.Count | Should Be 1
        $global:AzureExportTestQueries[0] | Should Be "SELECT 1"
        Assert-MockCalled Start-Sleep -Times 0 -Exactly -Scope It
    }

    It "still exports ordinary Results and never retries a failed INSERT" {
        Mock Invoke-Sqlcmd {
            $global:AzureExportTestQueries += $Query
            if ($Query -match '^\s*INSERT') { throw "Connection was lost after sending INSERT" }
            return 1
        }
        $testResults = @{
            StartTime = [datetime]"2026-09-05T12:00:01"
            Duration = "00:09:17"
            UpdatesFound = 2
            Success = $true
        }

        { & $exportScript -Results $testResults -ConfigPath $fixtureConfigPath } | Should Throw 'failed after 1 attempt(s)'
        $global:AzureExportTestQueries.Count | Should Be 2
        $global:AzureExportTestQueries[0] | Should Be "SELECT 1"
        $global:AzureExportTestQueries[1] | Should Match '^\s*INSERT INTO update_runs'
        Assert-MockCalled Start-Sleep -Times 0 -Exactly -Scope It
    }
}
