[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/Get-NextSkillVersion.ps1'
$testRepo = Join-Path ([IO.Path]::GetTempPath()) ('skill-version-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRepo
try {
    git -C $testRepo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize test repository.' }
    git -C $testRepo -c user.name=Test -c user.email=test@example.invalid commit --quiet --allow-empty -m 'initial'
    if ($LASTEXITCODE -ne 0) { throw 'Could not create initial commit.' }
    git -C $testRepo tag v1.0.0
    if ($LASTEXITCODE -ne 0) { throw 'Could not create test tag.' }
    Push-Location $testRepo
    try {
        $rejected = $false
        try { & $script } catch { $rejected = $true }
        if (-not $rejected) { throw 'A release without relevant commits must be rejected.' }
        foreach ($case in @(
            @{ Message = 'fix: repair'; Expected = 'v1.0.1' },
            @{ Message = 'feat(scope): add'; Expected = 'v1.1.0' },
            @{ Message = 'feat!: change'; Expected = 'v2.0.0' }
        )) {
            git -c user.name=Test -c user.email=test@example.invalid commit --quiet --allow-empty -m $case.Message
            if ($LASTEXITCODE -ne 0) { throw 'Could not create test commit.' }
            $actual = & $script
            if ($actual -cne $case.Expected) { throw "Expected $($case.Expected), got $actual" }
        }
        git tag v2.0.0
        if ($LASTEXITCODE -ne 0) { throw 'Could not create test tag.' }
        git -c user.name=Test -c user.email=test@example.invalid commit --quiet --allow-empty -m 'fix: change' -m 'BREAKING CHANGE: changed contract'
        if ($LASTEXITCODE -ne 0) { throw 'Could not create breaking-change commit.' }
        if ((& $script) -cne 'v3.0.0') { throw 'Breaking-change footer did not increment major version.' }
    } finally { Pop-Location }
    Write-Output 'Skill version tests passed.'
} finally {
    if ((Split-Path $testRepo -Parent) -ne [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Unexpected test directory.' }
    Remove-Item -LiteralPath $testRepo -Recurse -Force
}
