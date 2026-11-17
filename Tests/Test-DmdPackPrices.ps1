# Integration regression checks using a disposable SQL database and tiny XML feeds.
param([string]$ServerInstance = 'SILENTPRIORY\SQLEXPRESS')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$dmdDir = Join-Path $repoRoot 'DMD'
. (Join-Path $dmdDir 'PackPriceSupport.ps1')
$database = 'dmd_price_test_' + [guid]::NewGuid().ToString('N')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) $database
$fixtureDir = Join-Path $fixtureRoot 'CurrentReleases/nhsbsa_dmd_9.0.0_20260907000001'
$importer = Join-Path $dmdDir 'StandaloneImports/Import-PackPrices.ps1'
$validator = Join-Path $dmdDir 'Validate-PackPrices.ps1'
$master = New-DmdPriceConnection $ServerInstance 'master'
$connection = $null
$created = $false
$checks = 0

function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ($Actual -ne $Expected) { throw "$Label expected '$Expected', got '$Actual'" }
    $script:checks++
}
function Assert-Throws([scriptblock]$Action, [string]$Label) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw "$Label should have failed" }
    $script:checks++
}
function Write-Fixture([string]$AmppRows, [string]$TariffRows) {
    [IO.File]::WriteAllText((Join-Path $fixtureDir 'f_ampp2_test.xml'), "<ACTUAL_MEDICINAL_PROD_PACKS><MEDICINAL_PRODUCT_PRICE>$AmppRows</MEDICINAL_PRODUCT_PRICE></ACTUAL_MEDICINAL_PROD_PACKS>")
    [IO.File]::WriteAllText((Join-Path $fixtureDir 'f_vmpp2_test.xml'), "<VIRTUAL_MED_PRODUCT_PACK><DRUG_TARIFF_INFO>$TariffRows</DRUG_TARIFF_INFO></VIRTUAL_MED_PRODUCT_PACK>")
}
function Invoke-FixtureImport {
    & $importer -XmlPath $fixtureDir -ServerInstance $ServerInstance -DatabaseName $database
}
function Invoke-FixtureValidation {
    & $validator -XmlPath $fixtureDir -ServerInstance $ServerInstance -Database $database
}

try {
    [void](New-Item -ItemType Directory -Path $fixtureDir -Force)
    Invoke-DmdPriceSql $master "CREATE DATABASE [$database];"
    $created = $true
    $connection = New-DmdPriceConnection $ServerInstance $database
    Invoke-DmdPriceSql $connection @'
CREATE TABLE dbo.ampp (appid VARCHAR(18) PRIMARY KEY);
CREATE TABLE dbo.vmpp (vppid VARCHAR(18) PRIMARY KEY);
CREATE TABLE dbo.lookup (type NVARCHAR(50), cd NVARCHAR(20), descr NVARCHAR(255));
INSERT INTO dbo.ampp VALUES ('1001'), ('1002'), ('1003');
INSERT INTO dbo.vmpp VALUES ('2001'), ('2002'), ('2003');
INSERT INTO dbo.lookup VALUES ('PRICE_BASIS', '0001', 'Indicative'), ('PRICE_BASIS', '0002', 'Unavailable'),
 ('DT_PAYMENT_CATEGORY', '0003', 'Category C'), ('DT_PAYMENT_CATEGORY', '0011', 'Category M');
'@
    $ampp1 = '<PRICE_INFO><APPID>1001</APPID><PRICE>4420</PRICE><PRICEDT>2025-06-06</PRICEDT><PRICE_PREV>4862</PRICE_PREV><PRICE_BASISCD>0001</PRICE_BASISCD></PRICE_INFO><PRICE_INFO><APPID>1002</APPID><PRICE>0</PRICE><PRICE_BASISCD>0002</PRICE_BASISCD></PRICE_INFO><PRICE_INFO><APPID>1003</APPID><PRICE_BASISCD>0002</PRICE_BASISCD></PRICE_INFO>'
    $tariff1 = '<DTINFO><VPPID>2001</VPPID><PAY_CATCD>0003</PAY_CATCD><PRICE>3153</PRICE><DT>2021-04-01</DT><PREVPRICE>2947</PREVPRICE></DTINFO><DTINFO><VPPID>2002</VPPID><PAY_CATCD>0011</PAY_CATCD><PRICE>0</PRICE></DTINFO>'
    Write-Fixture $ampp1 $tariff1
    Assert-Throws { Invoke-FixtureValidation } 'Missing pricing tables'
    Invoke-FixtureImport
    Assert-Equal (Invoke-FixtureValidation | Measure-Object).Count 2 'Both tables verified'
    Assert-Equal (Invoke-DmdPriceSql $connection 'SELECT price FROM dbo.ampp_price WHERE appid = ''1001''' -Scalar) 4420 'Raw price'
    Assert-Equal (Invoke-DmdPriceSql $connection 'SELECT COUNT(*) FROM dbo.ampp_price WHERE price = 0' -Scalar) 1 'Zero preserved'
    Assert-Equal (Invoke-DmdPriceSql $connection 'SELECT COUNT(*) FROM dbo.ampp_price WHERE price IS NULL' -Scalar) 1 'NULL preserved'
    Invoke-FixtureImport
    Assert-Equal (Invoke-DmdPriceSql $connection 'SELECT COUNT(*) FROM dbo.ampp_price' -Scalar) 3 'Idempotent rerun'

    # The streaming comparison must still check every field and distinguish
    # NULL from zero; lookup codes can have different leading-zero padding.
    Invoke-DmdPriceSql $connection "UPDATE dbo.lookup SET cd='1' WHERE type='PRICE_BASIS' AND cd='0001';"
    Assert-Equal (Invoke-FixtureValidation | Measure-Object).Count 2 'Numeric lookup codes normalised'
    $fieldChanges = @(
        @{ Table='ampp_price'; Key="appid='1001'"; Column='price'; Value='NULL'; Original='4420' },
        @{ Table='ampp_price'; Key="appid='1001'"; Column='pricedt'; Value="'2026-01-01'"; Original="'2025-06-06'" },
        @{ Table='ampp_price'; Key="appid='1001'"; Column='price_prev'; Value='0'; Original='4862' },
        @{ Table='ampp_price'; Key="appid='1001'"; Column='price_basiscd'; Value="'0002'"; Original="'0001'" },
        @{ Table='ampp_price'; Key="appid='1003'"; Column='price'; Value='0'; Original='NULL' },
        @{ Table='vmpp_drugtariffinfo'; Key="vppid='2001'"; Column='pay_catcd'; Value="'0011'"; Original="'0003'" },
        @{ Table='vmpp_drugtariffinfo'; Key="vppid='2001'"; Column='price'; Value='3154'; Original='3153' },
        @{ Table='vmpp_drugtariffinfo'; Key="vppid='2001'"; Column='dt'; Value='NULL'; Original="'2021-04-01'" },
        @{ Table='vmpp_drugtariffinfo'; Key="vppid='2001'"; Column='prevprice'; Value='0'; Original='2947' }
    )
    foreach ($change in $fieldChanges) {
        Invoke-DmdPriceSql $connection "UPDATE dbo.$($change.Table) SET $($change.Column)=$($change.Value) WHERE $($change.Key);"
        Assert-Throws { Invoke-FixtureValidation } "$($change.Table).$($change.Column) mismatch"
        Invoke-DmdPriceSql $connection "UPDATE dbo.$($change.Table) SET $($change.Column)=$($change.Original) WHERE $($change.Key);"
    }
    Assert-Equal (Invoke-FixtureValidation | Measure-Object).Count 2 'All fields restored'

    # Same IDs change their current/previous price, date and code. Missing optional
    # values clear the old data; tariff membership changes within the full snapshot.
    $ampp2 = '<PRICE_INFO><APPID>1001</APPID><PRICE_BASISCD>0002</PRICE_BASISCD></PRICE_INFO><PRICE_INFO><APPID>1002</APPID><PRICE>77</PRICE><PRICEDT>2026-09-01</PRICEDT><PRICE_PREV>0</PRICE_PREV><PRICE_BASISCD>0001</PRICE_BASISCD></PRICE_INFO>'
    $tariff2 = '<DTINFO><VPPID>2001</VPPID><PAY_CATCD>0011</PAY_CATCD><PRICE>61</PRICE><DT>2026-07-01</DT><PREVPRICE>59</PREVPRICE></DTINFO><DTINFO><VPPID>2003</VPPID><PAY_CATCD>0003</PAY_CATCD></DTINFO>'
    Write-Fixture $ampp2 $tariff2
    Assert-Throws { Invoke-FixtureValidation } 'Changed XML fails validation'
    Invoke-FixtureImport
    Assert-Equal (Invoke-FixtureValidation | Measure-Object).Count 2 'Changed release verified'
    Assert-Equal (Invoke-DmdPriceSql $connection "SELECT COUNT(*) FROM dbo.ampp_price WHERE appid='1001' AND price IS NULL AND pricedt IS NULL AND price_prev IS NULL AND price_basiscd='0002'" -Scalar) 1 'Cleared old optional fields'
    Assert-Equal (Invoke-DmdPriceSql $connection "SELECT COUNT(*) FROM dbo.vmpp_drugtariffinfo WHERE vppid='2002'" -Scalar) 0 'Withdrawn tariff removed'
    Assert-Equal (Invoke-DmdPriceSql $connection "SELECT COUNT(*) FROM dbo.vmpp_drugtariffinfo WHERE vppid='2003' AND price IS NULL" -Scalar) 1 'New tariff inserted'

    Invoke-DmdPriceSql $connection "UPDATE dbo.ampp_price SET price=999 WHERE appid='1002';"
    Assert-Throws { Invoke-FixtureValidation } 'Same count but wrong price fails'
    Invoke-FixtureImport
    Invoke-DmdPriceSql $connection "INSERT INTO dbo.vmpp_drugtariffinfo (vppid,pay_catcd) VALUES ('2002','0003');"
    Assert-Throws { Invoke-FixtureValidation } 'Extra database row fails'
    Invoke-FixtureImport

    Write-Fixture ($ampp2.Replace('<APPID>1001</APPID>', '<APPID>9999</APPID>')) $tariff2
    Assert-Throws { Invoke-FixtureImport } 'Orphan pack rejected'
    Write-Fixture $ampp2 ($tariff2.Replace('<PAY_CATCD>0011</PAY_CATCD>', '<PAY_CATCD>9999</PAY_CATCD>'))
    Assert-Throws { Invoke-FixtureImport } 'Unknown tariff category rejected'
    Write-Fixture ($ampp2 + $ampp2) $tariff2
    Assert-Throws { Invoke-FixtureImport } 'Duplicate source key rejected'
    Write-Fixture ($ampp2.Replace('<PRICE>77</PRICE>', '<PRICE>bad</PRICE>')) $tariff2
    Assert-Throws { Invoke-FixtureImport } 'Malformed amount rejected'
    Write-Fixture ($ampp2.Replace('2026-09-01', '2026-99-01')) $tariff2
    Assert-Throws { Invoke-FixtureImport } 'Malformed date rejected'
    Write-Fixture '' $tariff2
    Assert-Throws { Invoke-FixtureImport } 'Empty feed rejected'
    [IO.File]::WriteAllText((Join-Path $fixtureDir 'f_ampp2_test.xml'), '<ACTUAL_MEDICINAL_PROD_PACKS/>')
    Assert-Throws { Invoke-FixtureImport } 'Missing section rejected'

    # Force a failure in the second table after the first table has been updated.
    # Both tables must retain the previous successfully imported snapshot.
    Invoke-DmdPriceSql $connection 'ALTER TABLE dbo.vmpp_drugtariffinfo ADD CONSTRAINT CK_test_price CHECK (price < 10000);'
    Write-Fixture ($ampp2.Replace('<PRICE>77</PRICE>', '<PRICE>88</PRICE>')) ($tariff2.Replace('<PRICE>61</PRICE>', '<PRICE>10001</PRICE>'))
    Assert-Throws { Invoke-FixtureImport } 'Second table SQL failure rolls back'
    Assert-Equal (Invoke-DmdPriceSql $connection "SELECT price FROM dbo.ampp_price WHERE appid='1002'" -Scalar) 77 'First table rolled back'
    Write-Fixture $ampp2 $tariff2
    Assert-Equal (Invoke-FixtureValidation | Measure-Object).Count 2 'Previous snapshot intact after failed imports'

    # Exercise the actual weekly pricing action and result handling against the
    # fixture database. Never run download, notification or publishing steps.
    $parseTokens = $null; $parseErrors = $null
    $weeklyAst = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repoRoot 'Weekly-TerminologyUpdate.ps1'), [ref]$parseTokens, [ref]$parseErrors)
    Assert-Equal @($parseErrors).Count 0 'Weekly script parses'
    $stepFunction = $weeklyAst.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Step'
    }, $true)
    . ([scriptblock]::Create($stepFunction.Extent.Text))
    $priceCommand = $weeklyAst.Find({ param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Invoke-Step' -and
        $node.Extent.Text -like '*-Name "Validate DMD pack prices against XML"*'
    }, $true)
    $priceActionNode = $priceCommand.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }
    $priceAction = [scriptblock]::Create($priceActionNode.ScriptBlock.Extent.Text.Trim().Substring(1).TrimEnd().TrimEnd('}'))
    $config = [pscustomobject]@{
        paths = [pscustomobject]@{ dmdBase = $fixtureRoot }
        database = [pscustomobject]@{ serverInstance = $ServerInstance; dmdDatabase = $database }
    }
    $preUpdateCounts = @{ ampp_price = 1; vmpp_drugtariffinfo = 2 }
    $dmdResults = @{ Steps = @(); TableCounts = @{}; TableChanges = @{} }
    $script:results = @{ Errors = @() }
    $WhatIfPreference = $false
    Assert-Equal (Invoke-Step -Name 'Pricing fixture' -ResultGroup $dmdResults -Action $priceAction) $true 'Weekly check succeeds'
    Assert-Equal $dmdResults.TableCounts.ampp_price 2 'Weekly pricing count'
    Assert-Equal $dmdResults.TableChanges.ampp_price 1 'Weekly pricing change'
    Invoke-DmdPriceSql $connection "UPDATE dbo.vmpp_drugtariffinfo SET prevprice=123 WHERE vppid='2001';"
    Assert-Equal (Invoke-Step -Name 'Pricing fixture failure' -ResultGroup $dmdResults -Action $priceAction) $false 'Weekly stale value fails'
    Assert-Equal $script:results.Errors.Count 1 'Weekly failure recorded'
    Write-Host "PASS: $checks pack pricing integration checks." -ForegroundColor Green
} finally {
    if ($null -ne $connection) { $connection.Dispose() }
    if ($created -and $database -match '^dmd_price_test_[a-f0-9]{32}$') {
        Invoke-DmdPriceSql $master "ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$database];"
    }
    $master.Dispose()
    # The fixture directory was created by this test with the unique database name.
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $expectedFixture = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) $database))
    if ($resolvedFixture -eq $expectedFixture -and (Test-Path -LiteralPath $resolvedFixture)) {
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}
