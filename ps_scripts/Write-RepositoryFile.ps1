param(
 [Parameter(Mandatory=$true)][string]$Path,
 [Parameter(Mandatory=$true)][string]$ContentBase64
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$full=[IO.Path]::GetFullPath((Join-Path $root $Path))
if (-not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes repository' }
$parent=Split-Path -Parent $full
if (-not [IO.Directory]::Exists($parent)) { [IO.Directory]::CreateDirectory($parent)|Out-Null }
$content=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ContentBase64))
[IO.File]::WriteAllText($full,$content,[Text.UTF8Encoding]::new($false))
Write-Output "Written: $Path"
