[CmdletBinding()]
param(
    [string]$RepositoryRoot,

    [string]$HomePath = $HOME,

    [string]$VSCodePromptsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StartMarker = "<!-- powershell-validate:start -->"
$EndMarker = "<!-- powershell-validate:end -->"

function Set-ManagedMarkdownSection {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Block,

        [string]$Frontmatter = ""
    )

    $Directory = Split-Path $Path -Parent
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null

    $ManagedSection = "$StartMarker`n$Block`n$EndMarker"
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $Existing = (Get-Content -LiteralPath $Path -Raw).TrimEnd()
        $Pattern = "(?s)$([regex]::Escape($StartMarker)).*?$([regex]::Escape($EndMarker))"
        if ($Existing -match $Pattern) {
            $Updated = [regex]::Replace($Existing, $Pattern, $ManagedSection)
        } else {
            $Updated = "$Existing`n`n$ManagedSection"
        }
    } else {
        $Updated = if ($Frontmatter) { "$Frontmatter`n`n$ManagedSection" } else { $ManagedSection }
    }

    Set-Content -LiteralPath $Path -Value ($Updated + "`n") -Encoding utf8NoBOM -NoNewline
    Write-Host "Updated Copilot instructions: $Path"
}

if ($RepositoryRoot) {
    $ResolvedRepo = (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path
    $GithubRoot = Join-Path $ResolvedRepo ".github"
    $SkillHint = ".github/skills/powershell-validate/SKILL.md or .agents/skills/powershell-validate/SKILL.md (or ~/.agents/skills/powershell-validate/SKILL.md)"
    $CopilotPath = Join-Path $GithubRoot "copilot-instructions.md"
    $FileInstructionsPath = Join-Path (Join-Path $GithubRoot "instructions") "powershell.instructions.md"
} else {
    $ResolvedHome = (Resolve-Path -LiteralPath $HomePath -ErrorAction Stop).Path
    $SkillHint = "~/.agents/skills/powershell-validate/SKILL.md"
    $CopilotPath = Join-Path (Join-Path $ResolvedHome ".copilot") "copilot-instructions.md"
    $PromptsDir = if ($VSCodePromptsPath) { $VSCodePromptsPath } else { Join-Path $ResolvedHome "AppData/Roaming/Code/User/prompts" }
    $FileInstructionsPath = Join-Path $PromptsDir "powershell.instructions.md"
}

$GeneralBlock = @(
    '## PowerShell Validation (powershell-validate)'
    ''
    'When a task involves PowerShell commands, scripts, or modules (`.ps1`, `.psm1`, `.psd1`):'
    "1. Read and follow the ``powershell-validate`` skill at ``$SkillHint`` before generating or editing code."
    '2. Enforce UTF-8 without BOM for PowerShell 7+, ASCII quotes/punctuation, `Set-StrictMode -Version Latest`, and `$ErrorActionPreference = ''Stop''`.'
    '3. Run `scripts/Test-PowerShellValidation.ps1` from the skill against created or modified PowerShell files and fix all errors and warnings before finishing.'
) -join "`n"

$FileBlock = @(
    '# PowerShell instructions'
    ''
    'For every PowerShell task (`.ps1`, `.psm1`, `.psd1`):'
    "1. Load and follow the ``powershell-validate`` agent skill at ``$SkillHint``."
    '2. Guard against PowerShell pitfalls: use `${var}:` before colons in strings, place `$null` on the left of `-eq`/`-ne`, pass `-Depth` to `ConvertTo-Json`, avoid `+=` in loops, use `.PSBase.Keys`/`.PSBase.Values` on hashtables, wrap command output in `@(...)` before `.Count`, and check `$LASTEXITCODE` after native commands piped to `Out-Null`.'
    '3. Validate the result with `scripts/Test-PowerShellValidation.ps1` from the skill before presenting code or committing.'
) -join "`n"

$Frontmatter = @(
    '---'
    'applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"'
    '---'
) -join "`n"

Set-ManagedMarkdownSection -Path $CopilotPath -Block $GeneralBlock
Set-ManagedMarkdownSection -Path $FileInstructionsPath -Block $FileBlock -Frontmatter $Frontmatter
