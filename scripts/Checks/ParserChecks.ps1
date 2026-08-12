function Invoke-ParserChecks {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$File,
        [string]$Text,
        [string[]]$Lines
    )

    $loopAstTypes = @(
        'System.Management.Automation.Language.ForEachStatementAst',
        'System.Management.Automation.Language.ForStatementAst',
        'System.Management.Automation.Language.WhileStatementAst',
        'System.Management.Automation.Language.DoWhileStatementAst',
        'System.Management.Automation.Language.DoUntilStatementAst'
    )
    $conditionAstTypes = @(
        'System.Management.Automation.Language.IfStatementAst',
        'System.Management.Automation.Language.WhileStatementAst',
        'System.Management.Automation.Language.DoWhileStatementAst',
        'System.Management.Automation.Language.DoUntilStatementAst'
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors)

    foreach ($e in $parseErrors) {
        $line = $e.Extent.StartLineNumber
        $msg = ($e.Message -replace '\s+', ' ').Trim()
        if ($msg -match 'was not followed by a valid variable name') {
            Add-Finding -Sink $Findings -File $File -Severity 'Error' -Rule 'variable-colon' -Message 'Double-quoted string contains $var: - use ${var}: to delimit the variable name.' -Line $line
        }
        elseif ($msg -match 'No characters are allowed after a here-string header') {
            Add-Finding -Sink $Findings -File $File -Severity 'Error' -Rule 'herestring-header' -Message 'Invalid here-string header. Use @" or @'' on its own line, then the here-string content starts on next line.' -Line $line
        }
        else {
            Add-Finding -Sink $Findings -File $File -Severity 'Error' -Rule 'parse-error' -Message "PowerShell parser: $msg" -Line $line
        }
    }

    if ($null -eq $ast) {
        return
    }

    $assignments = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)
    foreach ($a in $assignments) {
        if ($a.Operator -eq 'PlusEquals' -and (Test-InLoopBody -Node $a -LoopTypes $loopAstTypes)) {
            Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'array-plus-equals' -Message 'Possible array growth with += inside a loop. Prefer a List[T] or assign the loop output directly.' -Line $a.Extent.StartLineNumber
        }

        if ($a.Operator -eq 'Equals' -and ($conditionAstTypes -contains $a.Parent.GetType().FullName)) {
            Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'assignment-in-condition' -Message 'Assignment (=) used directly as a condition. Did you mean -eq? Use = only if assigning on purpose.' -Line $a.Extent.StartLineNumber
        }
    }

    $comparisons = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] }, $true)
    foreach ($b in $comparisons) {
        if ((@('Ieq', 'Ine', 'Ceq', 'Cne') -contains [string]$b.Operator) -and
            $b.Right -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $b.Right.VariablePath.UserPath -eq 'null') {
            Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'null-comparison' -Message 'Comparison has $null on the right. Use "$null -eq $x" so a collection on the left cannot change the result.' -Line $b.Extent.StartLineNumber
        }
    }

    $commands = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($cmd in $commands) {
        if ($cmd.GetCommandName() -eq 'ConvertTo-Json') {
            $hasDepth = $false
            $splatted = $false
            foreach ($el in $cmd.CommandElements) {
                if ($el -is [System.Management.Automation.Language.CommandParameterAst] -and $el.ParameterName -match '^(?i)dep') {
                    $hasDepth = $true
                }
                if ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
                    $splatted = $true
                }
            }

            if (-not $hasDepth -and -not $splatted) {
                Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'convertto-json-depth' -Message 'ConvertTo-Json is used without -Depth (default depth truncates nested objects).' -Line $cmd.Extent.StartLineNumber
            }
        }
    }

    $pipelines = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.PipelineAst] }, $true)
    foreach ($pl in $pipelines) {
        $elems = $pl.PipelineElements
        for ($i = 1; $i -lt $elems.Count; $i++) {
            $el = $elems[$i]
            if ($el -is [System.Management.Automation.Language.CommandAst] -and $el.GetCommandName() -eq 'Out-Null') {
                $src = $elems[$i - 1]
                $srcName = if ($src -is [System.Management.Automation.Language.CommandAst]) { $src.GetCommandName() } else { $null }
                if ($srcName -and ($srcName -notmatch '^[A-Za-z]+-[A-Za-z]')) {
                    $ln = $el.Extent.StartLineNumber
                    $windowEnd = [Math]::Min($ln + 2, $Lines.Count)
                    $window = $Lines[($ln - 1)..($windowEnd - 1)] -join "`n"
                    if ($window -notmatch '\$LASTEXITCODE') {
                        Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'lastexitcode-check' -Message "Native command '$srcName' piped to Out-Null without a nearby `$LASTEXITCODE check." -Line $ln
                    }
                }
            }
        }
    }
}
