function Get-TargetFiles {
    param(
        [string]$TargetPath,
        [bool]$Recursive
    )

    if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
        return ,(Get-Item -LiteralPath $TargetPath)
    }

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
        throw "Path not found: $TargetPath"
    }

    $childParams = @{
        LiteralPath = $TargetPath
        File        = $true
    }
    if ($Recursive) {
        $childParams.Recurse = $true
    }

    return Get-ChildItem @childParams | Where-Object {
        $_.Extension -in '.ps1', '.psm1', '.psd1'
    }
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Sink,
        [string]$File,
        [string]$Severity,
        [string]$Rule,
        [string]$Message,
        [int]$Line = 0
    )

    $Sink.Add([pscustomobject]@{
        File     = $File
        Severity = $Severity
        Rule     = $Rule
        Line     = $Line
        Message  = $Message
    })
}

function Get-LineNumbers {
    param(
        [string[]]$Lines,
        [regex]$Pattern
    )

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Pattern.IsMatch($Lines[$i])) {
            $i + 1
        }
    }
}

function Test-InLoopBody {
    # True only when $Node sits inside the *body* of an enclosing loop, so the
    # increment in a "for" header (for example "$i += 1") is correctly not
    # treated as array growth.
    param(
        $Node,
        [string[]]$LoopTypes
    )

    $p = $Node.Parent
    while ($p) {
        if ($LoopTypes -contains $p.GetType().FullName) {
            $body = $p.Body
            if ($body -and
                $Node.Extent.StartOffset -ge $body.Extent.StartOffset -and
                $Node.Extent.EndOffset -le $body.Extent.EndOffset) {
                return $true
            }
        }
        $p = $p.Parent
    }
    return $false
}

function Get-UnwrappedCommandCountFindings {
    param(
        [string[]]$Lines
    )

    $unwrappedAssignments = @{}
    $assignmentPattern = [regex]'^\s*\$(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<rhs>.+?)\s*$'

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        $assignmentMatch = $assignmentPattern.Match($line)
        if ($assignmentMatch.Success) {
            $name = $assignmentMatch.Groups['name'].Value
            $rhs = $assignmentMatch.Groups['rhs'].Value.Trim()

            if ($rhs -match '^@\(' -or
                $rhs -match '^@{' -or
                $rhs -match '^\[' -or
                $rhs -match '^\$' -or
                $rhs -match '^["'']' -or
                $rhs -match '^[0-9]' -or
                $rhs -match '^\(') {
                $unwrappedAssignments.Remove($name)
            }
            elseif ($rhs -match '^[A-Za-z][A-Za-z0-9_-]*\b' -or $rhs -match '\|') {
                $unwrappedAssignments[$name] = $i + 1
            }
            else {
                $unwrappedAssignments.Remove($name)
            }
        }

        foreach ($name in @($unwrappedAssignments.Keys)) {
            if ($line -match ('\$' + [regex]::Escape($name) + '\.Count\b')) {
                [pscustomobject]@{
                    Line           = $i + 1
                    AssignmentLine = $unwrappedAssignments[$name]
                    Variable       = $name
                }
            }
        }
    }
}
