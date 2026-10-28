[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 6.2.0 -ErrorAction Stop
$root = Split-Path $PSScriptRoot -Parent
$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'Coverage.Tests.ps1'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @(
    (Join-Path $root 'scripts/*.ps1')
    (Join-Path $root 'scripts/Checks/*.ps1')
    (Join-Path $root 'tools/*.ps1')
    (Join-Path $root 'Copy-AgentsToUserProfile.ps1')
)
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = Join-Path $root 'coverage/coverage.xml'
$config.CodeCoverage.CoveragePercentTarget = 98.01
$null = New-Item -ItemType Directory -Force -Path (Join-Path $root 'coverage')
$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0) { throw 'Pester tests failed.' }
$coverage = $result.CodeCoverage
if ($coverage.CoveragePercent -le 98) { throw "Coverage must exceed 98%; actual: $($coverage.CoveragePercent)%." }
