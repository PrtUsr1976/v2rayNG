param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path,
    [string]$Pattern = '',
    [int]$StartLine = 1,
    [int]$LineCount = 0,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$RepoPrefix = $RepoRoot + [IO.Path]::DirectorySeparatorChar

function Resolve-RepositoryPath {
    param([string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Only repository-relative paths are allowed: $RelativePath"
    }
    $FullPath = [IO.Path]::GetFullPath((Join-Path $RepoRoot $RelativePath))
    if (-not $FullPath.StartsWith($RepoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes repository root: $RelativePath"
    }
    return $FullPath
}

foreach ($RelativePath in $Path) {
    $FullPath = Resolve-RepositoryPath $RelativePath
    if ($List) {
        Get-ChildItem -LiteralPath $FullPath -Force -Recurse | ForEach-Object {
            $_.FullName.Substring($RepoPrefix.Length)
        }
        continue
    }
    if (-not [IO.File]::Exists($FullPath)) { throw "File does not exist: $RelativePath" }
    $Lines = [IO.File]::ReadAllLines($FullPath)
    Write-Host "== $RelativePath =="
    for ($Index = [Math]::Max(0, $StartLine - 1); $Index -lt $Lines.Length; $Index++) {
        if ($LineCount -gt 0 -and $Index -ge ($StartLine - 1 + $LineCount)) { break }
        if ($Pattern -and $Lines[$Index] -notmatch $Pattern) { continue }
        '{0,6}: {1}' -f ($Index + 1), $Lines[$Index]
    }
}
