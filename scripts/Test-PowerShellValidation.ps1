[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$Recurse,

    [ValidateSet('Any', 'Present', 'Absent')]
    [string]$ExpectedBom = 'Any',

    [switch]$WarnOnDanishLetters,

    [ValidateSet('Error', 'Warning', 'None')]
    [string]$FailOn = 'Error'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'Checks/SharedFunctions.ps1')
. (Join-Path $scriptRoot 'Checks/EncodingChecks.ps1')
. (Join-Path $scriptRoot 'Checks/HeuristicChecks.ps1')
. (Join-Path $scriptRoot 'Checks/ParserChecks.ps1')

# Shared regex and character patterns used by checks.
$smartQuoteChars = @(
    [char]0x2018
    [char]0x2019
    [char]0x201C
    [char]0x201D
    [char]0x00AB
    [char]0x00BB
)
$unicodePunctuationChars = @(
    [char]0x2013
    [char]0x2014
    [char]0x2026
)
$danishChars = @(
    [char]0x00E6
    [char]0x00F8
    [char]0x00E5
    [char]0x00C6
    [char]0x00D8
    [char]0x00C5
)
$danishMojibakeFragments = @(
    ([string][char]0x00C3 + [char]0x00A6)
    ([string][char]0x00C3 + [char]0x00B8)
    ([string][char]0x00C3 + [char]0x00A5)
    ([string][char]0x00C3 + [char]0x2020)
    ([string][char]0x00C3 + [char]0x02DC)
    ([string][char]0x00C3 + [char]0x2026)
)
$smartQuotePattern = [regex]::new('[' + ([regex]::Escape((-join $smartQuoteChars))) + ']')
$nbspPattern = [regex]::new([string][char]0x00A0)
$unicodePunctuationPattern = [regex]::new('[' + ([regex]::Escape((-join $unicodePunctuationChars))) + ']')
$danishPattern = [regex]::new('[' + ([regex]::Escape((-join $danishChars))) + ']')
$danishMojibakePattern = [regex]::new((($danishMojibakeFragments | ForEach-Object { [regex]::Escape($_) }) -join '|'))

function Test-File {
    param(
        [System.IO.FileInfo]$File
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $lines = $text -split "`r`n|`n|`r"

    Invoke-EncodingChecks -Findings $findings -File $File.FullName -Lines $lines -Bytes $bytes -Text $text -ExpectedBom $ExpectedBom -WarnOnDanishLetters $WarnOnDanishLetters
    Invoke-HeuristicChecks -Findings $findings -File $File.FullName -Lines $lines
    Invoke-ParserChecks -Findings $findings -File $File.FullName -Text $text -Lines $lines

    return $findings
}

$files = Get-TargetFiles -TargetPath $Path -Recursive $Recurse.IsPresent
$allFindings = [System.Collections.Generic.List[object]]::new()

foreach ($file in $files) {
    foreach ($finding in Test-File -File $file) {
        $allFindings.Add($finding)
    }
}

if ($allFindings.Count -eq 0) {
    Write-Host 'No validation findings.' -ForegroundColor Green
    exit 0
}

$sorted = $allFindings | Sort-Object File, Line, Severity, Rule
foreach ($finding in $sorted) {
    $prefix = if ($finding.Line -gt 0) {
        '{0}:{1}' -f $finding.File, $finding.Line
    }
    else {
        $finding.File
    }

    $color = switch ($finding.Severity) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        default { 'Gray' }
    }

    Write-Host ("[{0}] {1} {2} - {3}" -f $finding.Severity.ToUpperInvariant(), $prefix, $finding.Rule, $finding.Message) -ForegroundColor $color
}

$hasError = @($sorted | Where-Object { $_.Severity -eq 'Error' }).Count -gt 0
$hasWarning = @($sorted | Where-Object { $_.Severity -eq 'Warning' }).Count -gt 0

switch ($FailOn) {
    'None' { exit 0 }
    'Warning' { exit ([int]($hasError -or $hasWarning)) }
    default { exit ([int]$hasError) }
}
