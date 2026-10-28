BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . (Join-Path $root 'scripts/Checks/SharedFunctions.ps1')
    . (Join-Path $root 'scripts/Checks/EncodingChecks.ps1')
    . (Join-Path $root 'scripts/Checks/HeuristicChecks.ps1')
    . (Join-Path $root 'scripts/Checks/ParserChecks.ps1')
    $smartQuotePattern = [regex]'[\u2018\u2019\u201c\u201d\u00ab\u00bb]'
    $nbspPattern = [regex]'\u00a0'
    $unicodePunctuationPattern = [regex]'[\u2013\u2014\u2026]'
    $danishPattern = [regex]'[\u00e6\u00f8\u00e5\u00c6\u00d8\u00c5]'
    $danishMojibakePattern = [regex]'\u00c3\u00a6'
}

Describe 'Validator checks' {
    It 'detects encoding and character defects and expected BOM' {
        $findings = [System.Collections.Generic.List[object]]::new()
        $text = "`u{2018}`u{00a0}`u{2013}`u{00c3}`u{00a6}`u{00e6}`r`nsecond`n"
        $bytes = [byte[]](0xef,0xbb,0xbf,0)
        Invoke-EncodingChecks $findings 'input.ps1' @($text) $bytes $text 'Absent' $true
        foreach ($rule in @('utf8-bom-present','utf8-bom-unexpected','null-byte','mixed-line-endings','smart-quotes','nbsp','unicode-punctuation','danish-mojibake','danish-letters')) {
            $findings.Rule | Should -Contain $rule
        }
        $missing = [System.Collections.Generic.List[object]]::new()
        Invoke-EncodingChecks $missing 'input.ps1' @('plain') ([byte[]](65)) 'plain' 'Present' $false
        $missing.Rule | Should -Contain 'utf8-bom-missing'
    }
    It 'detects risky rename and unwrapped count while accepting wrapped values' {
        $findings = [System.Collections.Generic.List[object]]::new()
        $lines = @(('Rename-Item -NewName ' + '$targetPath'), '$items = Get-ChildItem', '$items.Count', '$items = @(Get-ChildItem)', '$items.Count')
        Invoke-HeuristicChecks $findings 'input.ps1' $lines
        $findings.Rule | Should -Contain 'rename-item-newname-path'
        @($findings | Where-Object Rule -eq 'unwrapped-command-count').Count | Should -Be 1
    }
    It 'classifies parser diagnostics and common unsafe patterns' {
        foreach ($case in @(
            @{ Text = '"$name: bad"'; Rule = 'variable-colon' },
            @{ Text = '@" invalid'; Rule = 'herestring-header' },
            @{ Text = 'if ('; Rule = 'parse-error' },
            @{ Text = 'foreach ($x in 1) { $items += $x }'; Rule = 'array-plus-equals' },
            @{ Text = 'if ($x = 1) { }'; Rule = 'assignment-in-condition' },
            @{ Text = '$x -eq $null'; Rule = 'null-comparison' },
            @{ Text = '$h.Keys'; Rule = 'dictionary-member-shadowing' },
            @{ Text = 'ConvertTo-Json $x'; Rule = 'convertto-json-depth' },
            @{ Text = 'git status | Out-Null'; Rule = 'lastexitcode-check' }
        )) {
            $findings = [System.Collections.Generic.List[object]]::new()
            Invoke-ParserChecks $findings 'input.ps1' $case.Text @($case.Text)
            $findings.Rule | Should -Contain $case.Rule -Because $case.Text
        }
    }
    It 'does not warn for protected members, JSON depth or checked commands' {
        $text = '$h.PSBase.Keys; $h.PSBase.Values; $h.Clear(); $h.$name; $h.Other; ConvertTo-Json $x -Depth 5; ConvertTo-Json @args; git status | Out-Null; $LASTEXITCODE'
        $findings = [System.Collections.Generic.List[object]]::new()
        Invoke-ParserChecks $findings 'input.ps1' $text @($text)
        $findings.Count | Should -Be 0
    }
    It 'handles target paths and assignment variants' {
        { Get-TargetFiles (Join-Path $TestDrive 'missing') $false } | Should -Throw
        $file = Join-Path $TestDrive 'input.ps1'
        Set-Content -LiteralPath $file -Value 'test'
        @(Get-TargetFiles $file $false).Count | Should -Be 1
        @(Get-TargetFiles $TestDrive $true).Count | Should -Be 1
        $lines = @('$x = Get-Thing', '$x = @{}', '$x = [int]1', '$x = $other', '$x = "text"', '$x = 1', '$x = (Get-Thing)', '$x = !foo', '$x = Get-Thing | Select-Object', '$x.Count')
        @(Get-UnwrappedCommandCountFindings $lines).Count | Should -Be 1
    }
    It 'handles assignments outside loop bodies and unnamed pipeline commands' {
        $text = 'for ($i = 0; $i -lt 1; $i += 1) { $x = 1 }; 1 | Out-Null'
        $findings = [System.Collections.Generic.List[object]]::new()
        Invoke-ParserChecks $findings 'input.ps1' $text @($text)
        @($findings | Where-Object Rule -eq 'array-plus-equals').Count | Should -Be 0
    }
    It 'runs the validator with clean, warning and error files' {
        $validator = Join-Path $root 'scripts/Test-PowerShellValidation.ps1'
        $clean = Join-Path $TestDrive 'clean.ps1'
        Set-Content -LiteralPath $clean -Value '$x = 1'
        & $validator -Path $clean
        $LASTEXITCODE | Should -Be 0
        $warning = Join-Path $TestDrive 'warning.ps1'
        Set-Content -LiteralPath $warning -Value 'ConvertTo-Json $x'
        & $validator -Path $warning -FailOn Warning
        $LASTEXITCODE | Should -Be 1
        & $validator -Path $warning -FailOn None
        $LASTEXITCODE | Should -Be 0
        $invalid = Join-Path $TestDrive 'invalid.ps1'
        Set-Content -LiteralPath $invalid -Value 'if ('
        & $validator -Path $invalid
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'Package and version operations' {
    It 'runs release version cases' {
        & (Join-Path $root 'tests/Test-SkillVersion.ps1') | Should -Contain 'Skill version tests passed.'
    }
    It 'rejects missing stable tags and git failures' {
        $versionScript = Join-Path $root 'scripts/Get-NextSkillVersion.ps1'
        Mock git { $global:LASTEXITCODE = 0 }
        { & $versionScript } | Should -Throw '*No reachable stable SemVer tag*'
        Mock git { $global:LASTEXITCODE = 1 }
        { & $versionScript } | Should -Throw '*Could not list reachable tags*'
        Mock git {
            if ($args[0] -eq 'tag') { $global:LASTEXITCODE = 0; 'v1.0.0' }
            else { $global:LASTEXITCODE = 1 }
        }
        { & $versionScript } | Should -Throw '*Could not read commits*'
    }
    It 'copies a skill and handles invalid metadata and extra files' {
        $source = Join-Path $TestDrive 'source'
        $target = Join-Path $TestDrive 'target'
        $null = New-Item -ItemType Directory -Force -Path $source
        $installer = Join-Path $root 'tools/Copy-AgentSkillToUserProfile.ps1'
        { & $installer -SourceRoot $source -TargetRoot $target } | Should -Throw '*entrypoint*'
        Set-Content -LiteralPath (Join-Path $source 'SKILL.md') -Value 'invalid'
        { & $installer -SourceRoot $source -TargetRoot $target } | Should -Throw '*valid skill name*'
        Set-Content -LiteralPath (Join-Path $source 'SKILL.md') -Value "---`nname: example`n---"
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $source 'scripts')
        Set-Content -LiteralPath (Join-Path $source 'scripts/example.ps1') -Value 'test'
        & $installer -SourceRoot $source -TargetRoot $target
        Test-Path -LiteralPath (Join-Path $target 'skills/example/scripts/example.ps1') | Should -BeTrue
        $extra = Join-Path $target 'skills/example/extra.txt'
        Set-Content -LiteralPath $extra -Value 'extra'
        & $installer -SourceRoot $source -TargetRoot $target
        Test-Path -LiteralPath $extra | Should -BeTrue
        & $installer -SourceRoot $source -TargetRoot $target -RemoveExtraFiles
        Test-Path -LiteralPath $extra | Should -BeFalse
    }
    It 'installs from the repository wrapper' {
        & (Join-Path $root 'Copy-AgentsToUserProfile.ps1') -TargetRoot (Join-Path $TestDrive 'wrapper')
        Test-Path -LiteralPath (Join-Path $TestDrive 'wrapper/skills/powershell-validate/SKILL.md') | Should -BeTrue
    }
}
