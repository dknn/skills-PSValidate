[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tags = @(git tag --merged HEAD --list 'v*' --sort=-version:refname)
if ($LASTEXITCODE -ne 0) { throw 'Could not list reachable tags.' }
$tag = @($tags | Where-Object { $_ -cmatch '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' } | Select-Object -First 1)
if ($tag.Count -ne 1) { throw 'No reachable stable SemVer tag found.' }
$version = [version]$tag[0].Substring(1)
$messages = git log "$($tag[0])..HEAD" --format=%B
if ($LASTEXITCODE -ne 0) { throw 'Could not read commits since the last release.' }
$text = $messages -join "`n"
if ($text -cmatch '(?m)^BREAKING[ -]CHANGE:' -or $text -cmatch '(?m)^[a-z]+(?:\([^\r\n)]*\))?!:') {
    $next = 'v{0}.0.0' -f ($version.Major + 1)
} elseif ($text -cmatch '(?m)^feat(?:\([^\r\n)]*\))?:') {
    $next = 'v{0}.{1}.0' -f $version.Major, ($version.Minor + 1)
} elseif ($text -cmatch '(?m)^fix(?:\([^\r\n)]*\))?:') {
    $next = 'v{0}.{1}.{2}' -f $version.Major, $version.Minor, ($version.Build + 1)
} else {
    throw 'No feat, fix or breaking change found since the last stable release.'
}
Write-Output $next
