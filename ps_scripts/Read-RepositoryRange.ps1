param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$StartLine = 1,
    [int]$LineCount = 200
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
if (-not $fullPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Path escapes repository root.'
}
if (-not [IO.File]::Exists($fullPath)) { throw "File not found: $Path" }
$lines = [IO.File]::ReadAllLines($fullPath, [Text.Encoding]::UTF8)
$start = [Math]::Max(0, $StartLine - 1)
$end = [Math]::Min($lines.Length, $start + [Math]::Max(0, $LineCount))
for ($index = $start; $index -lt $end; $index++) {
    '{0,6}: {1}' -f ($index + 1), $lines[$index]
}
