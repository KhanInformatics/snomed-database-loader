$repoRoot = Split-Path -Parent $PSScriptRoot
$weeklyScript = Join-Path $repoRoot "Weekly-TerminologyUpdate.ps1"
$vmpIngredientScript = Join-Path $repoRoot "DMD\StandaloneImports\Import-VMP-Ingredients.ps1"
$runAllDmdImportsScript = Join-Path $repoRoot "DMD\StandaloneImports\Run-AllImports.ps1"
$sendReportScript = Join-Path $repoRoot "Send-UpdateReport.ps1"
$pcdSupportingProductsScript = Join-Path $repoRoot "MSSQL\Import-PCD-SupportingProducts.ps1"
$pcdProductLoaderScript = Join-Path $repoRoot "MSSQL\Import-PCD-GPData.ps1"
$pcdDatabaseSql = Join-Path $repoRoot "MSSQL\Create-PCD-Database.sql"
$pcdConsumersSql = Join-Path $repoRoot "MSSQL\Create-PCD-Canonical-Consumers.sql"

function Get-ParsedScript {
    param([Parameter(Mandatory = $true)][string]$Path)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    )

    return @{
        Ast = $ast
        Errors = @($errors)
        Source = [System.IO.File]::ReadAllText($Path)
    }
}

Describe "Weekly terminology update result handling" {
    It "parses without PowerShell syntax errors" {
        $parsed = Get-ParsedScript -Path $weeklyScript

        $parsed.Errors.Count | Should Be 0
    }

    It "uses the real common-parameter WhatIf state" {
        $parsed = Get-ParsedScript -Path $weeklyScript
        $unboundWhatIfReferences = @($parsed.Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $node.VariablePath.UserPath -eq "WhatIf"
        }, $true))

        # SupportsShouldProcess provides $WhatIfPreference and a PSBoundParameters
        # entry. It does not create a $WhatIf variable.
        $unboundWhatIfReferences.Count | Should Be 0
        $parsed.Source | Should Match '(?i)\$(WhatIfPreference|PSBoundParameters)'
    }

    It "does not pass a nested hashtable Steps property by reference" {
        $parsed = Get-ParsedScript -Path $weeklyScript

        # [ref]$hash.Steps refers to a temporary expression; appending through it
        # does not update $hash.Steps and caused failed steps to disappear.
        $parsed.Source | Should Not Match '(?i)\[ref\]\s*\$[a-z][a-z0-9_]*Results\.Steps'
    }

    It "persists a failed step and its error in the supplied result objects" {
        $parsed = Get-ParsedScript -Path $weeklyScript
        $invokeStepAst = $parsed.Ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq "Invoke-Step"
        }, $true)
        $invokeStepAst | Should Not BeNullOrEmpty

        . ([scriptblock]::Create($invokeStepAst.Extent.Text))

        $script:results = @{ Errors = @() }
        $resultGroup = @{ Steps = @() }
        $oldWhatIfPreference = $WhatIfPreference
        try {
            $WhatIfPreference = $false
            $succeeded = Invoke-Step -Name "isolated failure" -ResultGroup $resultGroup -Action {
                throw "isolated regression failure"
            }
        } finally {
            $WhatIfPreference = $oldWhatIfPreference
        }

        $succeeded | Should Be $false
        $resultGroup.Steps.Count | Should Be 1
        $resultGroup.Steps[0].Success | Should Be $false
        $resultGroup.Steps[0].Name | Should Be "isolated failure"
        $script:results.Errors.Count | Should Be 1
        $script:results.Errors[0] | Should Match 'isolated regression failure'
    }

    It "cannot leave the overall result successful when errors were recorded" {
        $parsed = Get-ParsedScript -Path $weeklyScript

        $parsed.Source | Should Match '(?is)if\s*\(\s*\$results\.Errors\.Count\s*-gt\s*0\s*\)\s*\{[^}]*\$results\.Success\s*=\s*\$false'
    }

    It "validates current PCD products without treating legacy shells as required" {
        $parsed = Get-ParsedScript -Path $weeklyScript

        $parsed.Source | Should Match 'Validate current PCD RF2 snapshot'
        $parsed.Source | Should Match 'Load current PCD supporting products'
        $parsed.Source | Should Match 'Validate current PCD supporting products'
        $parsed.Source | Should Match '\$\{productCode\}_Cluster_Refset_\*\.csv'
        $parsed.Source | Should Match '(?is)RequiredTables\s*=\s*@\([^)]*PCD_GPData_Cluster_Refset[^)]*PCD_GDPPR_Cluster_Refset'
        $parsed.Source | Should Match '(?is)OptionalTables\s*=\s*@\([^)]*PCD_Refset_Content_by_Output[^)]*PCD_Refset_Content_V2[^)]*PCD_Ruleset_Full_Name_Mappings_V2[^)]*PCD_Service_Full_Name_Mappings_V2[^)]*PCD_Output_Descriptions_V2'
        $parsed.Source | Should Match '(?is)Cluster_Category.+Cluster_ID.+Cluster_Desc.+Active_in_Refset.+Refset_Status_Date.+RefsetId.+Refset_Description.+ConceptId.+ConceptId_Description.+Active_Code_Status.+Code_Status_Date.+Type_of_Inclusion.+Sensitive_Status.+Sensitive_Status_Date'
        $parsed.Source | Should Match 'Get-PcdCsvEncoding'
        $parsed.Source | Should Match 'GetEncoding\(1252\)'
        $parsed.Source | Should Match '\$pcdDatabaseName'
        $parsed.Source | Should Not Match 'Only \$\(\$pcdResults\.TablesPassed\) of \$\(\$pcdResults\.TablesChecked\) expected tables contain data'
    }
}

Describe "PCD supporting-product orchestration" {
    It "parses and invokes the canonical loader once for GPData and once for GDPPR" {
        $parsed = Get-ParsedScript -Path $pcdSupportingProductsScript

        $parsed.Errors.Count | Should Be 0
        $parsed.Source | Should Match 'Import-PCD-GPData\.ps1'
        $parsed.Source | Should Match '@\("GPData",\s*"GDPPR"\)'
        $parsed.Source | Should Match 'DatabaseName\s*=\s*"PCD"'
        $parsed.Source | Should Match 'WhatIf\s*=\s*\[bool\]\$WhatIfPreference'
        $parsed.Source | Should Match 'Products\s*=\s*@\(\$productResults\)'
    }

    It "parses the product loader and keeps products, encoding, and provenance explicit" {
        $parsed = Get-ParsedScript -Path $pcdProductLoaderScript

        $parsed.Errors.Count | Should Be 0
        $parsed.Source | Should Match 'ValidateSet\("GPData",\s*"GDPPR"\)'
        $parsed.Source | Should Match 'DatabaseName\s*=\s*"PCD"'
        $parsed.Source | Should Match 'GetEncoding\(1252\)'
        $parsed.Source | Should Match 'DecoderFallbackException'
        $parsed.Source | Should Match 'does not match ProductCode'
        $parsed.Source | Should Match '(?is)Source_Release\s*-eq\s*\$sourceRelease.+Source_File\s*-eq\s*\$sourceFile.+Source_SHA256\s*-eq\s*\$sourceHash.+Source_Encoding\s*-eq\s*\$sourceEncoding\.WebName'
        $parsed.Source | Should Match 'source file changed while it was being loaded'
        $parsed.Source | Should Not Match '(?i)(DROP|DELETE\s+FROM)\s+(dbo\.)?PCD_(Refset_Content|Output_Descriptions|Ruleset_Full_Name|Service_Full_Name)'
    }

    It "isolates canonical storage and exposes only current compatibility views" {
        $databaseSql = [System.IO.File]::ReadAllText($pcdDatabaseSql)
        $consumerSql = [System.IO.File]::ReadAllText($pcdConsumersSql)

        $databaseSql | Should Match '(?i)CREATE\s+DATABASE\s+PCD'
        $databaseSql | Should Match '(?i)REVOKE\s+SELECT\s+ON\s+SCHEMA::dbo\s+FROM\s+snomedreader'
        $databaseSql | Should Not Match '(?i)GRANT\s+SELECT\s+ON\s+SCHEMA::dbo'
        $consumerSql | Should Match 'PCD_GPData_Cluster_Refset_Active'
        $consumerSql | Should Match 'PCD_GDPPR_Cluster_Refset_Active'
        $consumerSql | Should Match 'PCD_SupportingProduct_Cluster_Refset_Current'
        $consumerSql | Should Match 'FROM\s+PCD\.dbo\.PCD_GPData_Cluster_Refset_Active'
        $consumerSql | Should Match '(?is)ISNULL\(CAST\(ConceptId\s+AS\s+VARCHAR\(255\)\).+AS\s+SNOMED_code'
        $consumerSql | Should Match '(?i)GRANT\s+SELECT\s+ON\s+OBJECT::dbo\.PCD_GPData_Cluster_Refset_Active\s+TO\s+snomedreader'
        $consumerSql | Should Match '(?i)GRANT\s+EXECUTE\s+ON\s+OBJECT::dbo\.GetSNOMEDCodesByClusterID\s+TO\s+snomedreader'
    }
}

Describe "DM+D VMP ingredient import key and upsert behavior" {
    BeforeEach {
        $global:WeeklyUpdateTestSqlQueries = @()
        $global:WeeklyUpdateTestExistingVpid = "21394911000001108"
        $global:WeeklyUpdateTestExistingIsid = "108500007"
        $global:WeeklyUpdateTestNewVpid = "999999999999999991"
        $global:WeeklyUpdateTestNewIsid = "999999999999999992"

        $fixtureXml = @"
<VIRTUAL_MED_PRODUCTS>
  <VIRTUAL_PRODUCT_INGREDIENT>
    <VPI>
      <VPID>$global:WeeklyUpdateTestExistingVpid</VPID>
      <ISID>$global:WeeklyUpdateTestExistingIsid</ISID>
      <BASIS_STRNTCD>0002</BASIS_STRNTCD>
      <BS_SUBID>372909002</BS_SUBID>
      <STRNT_NMRTR_VAL>200</STRNT_NMRTR_VAL>
      <STRNT_NMRTR_UOMCD>258684004</STRNT_NMRTR_UOMCD>
    </VPI>
    <VPI>
      <VPID>$global:WeeklyUpdateTestNewVpid</VPID>
      <ISID>$global:WeeklyUpdateTestNewIsid</ISID>
      <BASIS_STRNTCD>0001</BASIS_STRNTCD>
      <STRNT_NMRTR_VAL>10</STRNT_NMRTR_VAL>
      <STRNT_NMRTR_UOMCD>258684004</STRNT_NMRTR_UOMCD>
    </VPI>
  </VIRTUAL_PRODUCT_INGREDIENT>
</VIRTUAL_MED_PRODUCTS>
"@

        $fixturePath = Join-Path $TestDrive "f_vmp2_regression.xml"
        Set-Content -LiteralPath $fixturePath -Value $fixtureXml -Encoding UTF8

        Mock Invoke-Sqlcmd {
            $global:WeeklyUpdateTestSqlQueries += [string]$Query

            if ($Query -match '(?i)FROM\s+sys\.columns') {
                return @(
                    [pscustomobject]@{ name = "strnt_nmrtr_val"; type_name = "decimal"; precision = 18; scale = 5 },
                    [pscustomobject]@{ name = "strnt_dnmtr_val"; type_name = "decimal"; precision = 18; scale = 5 }
                )
            }

            if ($Query -match '(?i)^\s*SELECT\s+COUNT\(\*\)') {
                return [pscustomobject]@{ cnt = 1 }
            }

            if ($Query -match '(?is)^\s*SELECT\s+.+\s+FROM\s+(dbo\.)?vmp_ingredient') {
                return [pscustomobject]@{
                    vpid = $global:WeeklyUpdateTestExistingVpid
                    isid = $global:WeeklyUpdateTestExistingIsid
                    basis_strntcd = "0001"
                    bs_subid = $null
                    strnt_nmrtr_val = 100
                    strnt_nmrtr_uomcd = "258684004"
                    strnt_dnmtr_val = $null
                    strnt_dnmtr_uomcd = $null
                }
            }

            # Model the real two-column primary key. A corrected importer must
            # update/merge the changed row instead of trying a plain duplicate INSERT.
            if ($Query -match '(?is)^\s*INSERT\s+INTO\s+(dbo\.)?vmp_ingredient' -and
                $Query -match [regex]::Escape($global:WeeklyUpdateTestExistingVpid) -and
                $Query -match [regex]::Escape($global:WeeklyUpdateTestExistingIsid)) {
                throw "Simulated PRIMARY KEY violation for (vpid, isid)"
            }

            if ($Query -match '(?i)^\s*;?\s*MERGE\s+(INTO\s+)?(dbo\.)?vmp_ingredient') {
                return @(
                    [pscustomobject]@{ MergeAction = "UPDATE" },
                    [pscustomobject]@{ MergeAction = "INSERT" }
                )
            }

            return [pscustomobject]@{ cnt = 2 }
        }
    }

    AfterEach {
        Remove-Variable WeeklyUpdateTestSqlQueries -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable WeeklyUpdateTestExistingVpid -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable WeeklyUpdateTestExistingIsid -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable WeeklyUpdateTestNewVpid -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable WeeklyUpdateTestNewIsid -Scope Global -ErrorAction SilentlyContinue
    }

    It "parses without PowerShell syntax errors" {
        $parsed = Get-ParsedScript -Path $vmpIngredientScript

        $parsed.Errors.Count | Should Be 0
    }

    It "uses the database primary key and updates a changed existing pair while inserting a new pair" {
        $caughtError = $null
        try {
            & $vmpIngredientScript -XmlPath $TestDrive -ServerInstance "mock" -DatabaseName "mock" -BatchSize 50
        } catch {
            $caughtError = $_
        }
        $caughtError | Should BeNullOrEmpty

        $mutations = @($global:WeeklyUpdateTestSqlQueries | Where-Object {
            $_ -match '(?i)^\s*;?\s*(INSERT|UPDATE|MERGE)'
        })
        $mutationText = $mutations -join "`n"

        # The existing (vpid,isid) row changed BASIS_STRNTCD from 0001 to 0002.
        # It must be handled by UPDATE or MERGE, and the new pair must be inserted.
        $mutationText | Should Match '(?is)ON\s+target\.vpid\s*=\s*source\.vpid\s+AND\s+target\.isid\s*=\s*source\.isid\s+WHEN MATCHED'
        $mergeOnClause = [regex]::Match($mutationText, '(?is)ON\s+(?<clause>.+?)\s+WHEN MATCHED').Groups['clause'].Value
        $mergeOnClause | Should Not Match 'basis_strntcd'
        $mutationText | Should Match '(?is)WHEN MATCHED.+UPDATE SET.+basis_strntcd'
        $mutationText | Should Match '(?is)WHEN NOT MATCHED BY TARGET.+INSERT'
        $mutationText | Should Match '(?is)MERGE.+21394911000001108.+108500007'
        $mutationText | Should Match '0002'
        $mutationText | Should Match '999999999999999991'
        $mutationText | Should Match '999999999999999992'
    }
}

Describe "DM+D import routing" {
    It "loads GTIN from the main release and detects importer exit failures" {
        $parsed = Get-ParsedScript -Path $runAllDmdImportsScript

        $parsed.Errors.Count | Should Be 0
        $parsed.Source | Should Match '(?is)Name\s*=\s*"GTIN \(Barcodes\)"[^\r\n]*UsesBonus\s*=\s*\$false'
        $parsed.Source | Should Match '(?is)if\s*\(\s*\$LASTEXITCODE\s*-ne\s*0\s*\)\s*\{[^}]*throw'
    }
}

Describe "Terminology email report PCD status" {
    It "renders RF2, both current supporting products, and legacy N/A as distinct states" {
        $parsed = Get-ParsedScript -Path $sendReportScript
        $buildHtmlAst = $parsed.Ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq "Build-HtmlReport"
        }, $true)
        $buildHtmlAst | Should Not BeNullOrEmpty
        . ([scriptblock]::Create($buildHtmlAst.Extent.Text))

        $html = Build-HtmlReport -Results @{
            Success = $false
            Errors = @("Current PCD supporting-product validation failed")
            Duration = "00:00:15"
            UpdatesFound = 0
            PCD = @{
                Success = $false
                Steps = @()
                TablesChecked = 2
                TablesPassed = 0
                ValidationRate = 0
                DatabaseName = "PCD"
                RF2Status = "Current"
                GPDataStatus = "Stale"
                GDPPRStatus = "Current"
                SupportingProductsStatus = "Mismatch"
                LegacyStatus = "N/A - not supplied in the current RF2 package"
                OptionalTables = @("PCD_Output_Descriptions_V2")
                TableCounts = @{
                    "PCD_GPData_Cluster_Refset" = 126144
                    "PCD_GDPPR_Cluster_Refset" = 69584
                    "PCD_Output_Descriptions_V2" = 0
                }
            }
        }

        $html | Should Match '&#10007; FAILED'
        $html | Should Match '(?is)Official RF2 PCD:.+Current'
        $html | Should Match '(?is)GPData supporting product:.+Stale'
        $html | Should Match '(?is)GDPPR supporting product:.+Current'
        $html | Should Match '(?is)Canonical PCD database:.+PCD'
        $html | Should Match '0/2 current'
        $html | Should Match 'N/A \(legacy\)'
    }
}

Describe "Terminology email report DMD failures" {
    It "does not claim no new release when the check or import failed" {
        $parsed = Get-ParsedScript -Path $sendReportScript
        $buildHtmlAst = $parsed.Ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq "Build-HtmlReport"
        }, $true)
        . ([scriptblock]::Create($buildHtmlAst.Extent.Text))
        $result = @{
            Success = $false; Errors = @('dm+d timeout'); Duration = '00:03:00'; UpdatesFound = 0
            DMD = @{ Success = $false; NewRelease = $false; Steps = @() }
        }
        $html = Build-HtmlReport -Results $result
        $html | Should Match 'Release check or update failed'
        $html | Should Not Match 'No new release available'

        $result.Success = $true
        $result.Errors = @()
        $result.DMD.Success = $true
        (Build-HtmlReport -Results $result) | Should Match 'No new release available'
    }
}
