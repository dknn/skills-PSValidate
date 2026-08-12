[CmdletBinding()]
param(
    [string]$TargetRoot = (Join-Path $HOME ".agents"),

    [switch]$RemoveExtraFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$UtilityScript = Join-Path $PSScriptRoot "tools/Copy-AgentSkillToUserProfile.ps1"

if (-not (Test-Path -LiteralPath $UtilityScript -PathType Leaf)) {
    throw "Bundled copy utility not found: $UtilityScript"
}

& $UtilityScript `
    -SourceRoot $PSScriptRoot `
    -TargetRoot $TargetRoot `
    -RemoveExtraFiles:$RemoveExtraFiles
