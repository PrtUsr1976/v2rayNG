param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,
    [string[]]$Path = @('.'),
    [int]$MaxResults = 500
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$RepoPrefix = $RepoRoot + [IO.Path]::DirectorySeparatorChar
$ResolvedPaths = foreach ($RelativePath in $Path) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Only repository-relative paths are allowed: $RelativePath"
    }
    $FullPath = [IO.Path]::GetFullPath((Join-Path $RepoRoot $RelativePath))
    if ($FullPath -ne $RepoRoot -and -not $FullPath.StartsWith($RepoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes repository root: $RelativePath"
    }
    $FullPath
}

Push-Location $RepoRoot
try {
    $Arguments = @('-n', '--hidden', '-S', $Pattern, '--') + $ResolvedPaths
    & rg @Arguments | Select-Object -First $MaxResults
    if ($LASTEXITCODE -gt 1) { throw "rg failed: $LASTEXITCODE" }
}
finally {
    Pop-Location
}
