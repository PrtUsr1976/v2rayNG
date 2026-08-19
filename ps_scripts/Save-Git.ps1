param(
    [Parameter(Mandatory = $true)][string]$CommitMessage,
    [Parameter(Mandatory = $true)][string[]]$Path
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $repoRoot
try {
    $indexLock = Join-Path $repoRoot '.git\index.lock'
    if ([IO.File]::Exists($indexLock)) { throw 'Git index.lock exists; commit stopped.' }
    $alreadyStaged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged files.' }
    if ($alreadyStaged.Count -gt 0) {
        throw "Unrelated files are already staged: $($alreadyStaged -join ', ')"
    }
    foreach ($relativePath in $Path) {
        $fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
        if (-not $fullPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Path escapes repository: $relativePath"
        }
    }
    & git add -- $Path
    if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged changes contain whitespace errors.' }
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { throw 'There are no staged changes to commit.' }
    & git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
    & git status -sb
}
finally {
    Pop-Location
}
