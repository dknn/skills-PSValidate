[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$SourceRoot = $PSScriptRoot,

    [string]$TargetRoot = (Join-Path $HOME ".agents"),

    [switch]$RemoveExtraFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ResolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop).Path
$SourceSkillFile = Join-Path $ResolvedSourceRoot "SKILL.md"
$SourceFolders = @(
    "scripts"
    "references"
    "assets"
    "agents"
)

if (-not (Test-Path -LiteralPath $SourceSkillFile -PathType Leaf)) {
    throw "Skill entrypoint not found: $SourceSkillFile"
}

$SkillContent = Get-Content -LiteralPath $SourceSkillFile -Raw
$SkillNameMatch = [regex]::Match(
    $SkillContent,
    '(?m)^name:\s*(?<Name>[A-Za-z0-9][A-Za-z0-9._-]*)\s*$'
)

if (-not $SkillNameMatch.Success) {
    throw "A valid skill name was not found in: $SourceSkillFile"
}

$SkillName = $SkillNameMatch.Groups["Name"].Value
$TargetSkillRoot = Join-Path (Join-Path $TargetRoot "skills") $SkillName
$SourceFiles = @(
    Get-Item -LiteralPath $SourceSkillFile

    foreach ($Folder in $SourceFolders) {
        $Source = Join-Path $ResolvedSourceRoot $Folder

        if (Test-Path -LiteralPath $Source -PathType Container) {
            Get-ChildItem -LiteralPath $Source -Recurse -File
        }
    }
)
$SourceRelativePaths = @{}
$ManagedFiles = [ordered]@{}

Write-Host "Copying ${SkillName} to:"
Write-Host "  $TargetSkillRoot"

foreach ($SourceFile in $SourceFiles) {
    $RelativePath = [System.IO.Path]::GetRelativePath(
        $ResolvedSourceRoot,
        $SourceFile.FullName
    )
    $SourceRelativePaths[$RelativePath] = $true
    $TargetFile = Join-Path $TargetSkillRoot $RelativePath
    $TargetDirectory = Split-Path $TargetFile -Parent

    New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
    Copy-Item -LiteralPath $SourceFile.FullName -Destination $TargetFile -Force
    $NormalizedRelativePath = $RelativePath.Replace('\', '/')
    $ManagedFiles[$NormalizedRelativePath] = (Get-FileHash -LiteralPath $TargetFile -Algorithm SHA256).Hash
}

$BaselineTag = "v1.0.0"
$BaselineCommit = "6f580ef2d4b805c3931ea8d649c127103b8f55c5"
$ReceiptName = ".skills-utils-install.json"
$SourceRelativePaths[$ReceiptName] = $true
$ReceiptPath = Join-Path $TargetSkillRoot $ReceiptName
$Receipt = [ordered]@{
    Version    = 2
    Repository = "dknn/skills-PSValidate"
    Commit     = $BaselineCommit
    Selection  = "Stable"
    Tag        = $BaselineTag
    SeenTags   = @{ $BaselineTag = $BaselineCommit }
    Files      = $ManagedFiles
}
$Receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReceiptPath -Encoding utf8NoBOM

if ($RemoveExtraFiles) {
    Get-ChildItem -LiteralPath $TargetSkillRoot -Recurse -File -Force | ForEach-Object {
        $RelativePath = [System.IO.Path]::GetRelativePath(
            $TargetSkillRoot,
            $_.FullName
        )

        if (-not $SourceRelativePaths.ContainsKey($RelativePath)) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

Write-Host "Installed ${SkillName}: $TargetSkillRoot"
