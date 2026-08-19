param(
    [Parameter(Mandatory = $true)][string]$FirstPath,
    [Parameter(Mandatory = $true)][string]$SecondPath,
    [string]$LocalCopyName = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$first = [IO.Path]::GetFullPath($FirstPath)
$second = [IO.Path]::GetFullPath($SecondPath)
if (-not [IO.File]::Exists($first)) { throw "File not found: $first" }
if (-not [IO.File]::Exists($second)) { throw "File not found: $second" }
if ($LocalCopyName) {
    $destinationRoot = Join-Path $repoRoot '.local-handoff'
    [IO.Directory]::CreateDirectory($destinationRoot) | Out-Null
    $destination = Join-Path $destinationRoot $LocalCopyName
    Copy-Item -LiteralPath $first -Destination $destination -Force
    $first = $destination
}
$firstInfo = Get-Item -LiteralPath $first
$secondInfo = Get-Item -LiteralPath $second
$firstHash = (Get-FileHash -LiteralPath $first -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $second -Algorithm SHA256).Hash
$equal = $firstInfo.Length -eq $secondInfo.Length -and $firstHash -eq $secondHash
Write-Output "First: $first"
Write-Output "First size: $($firstInfo.Length)"
Write-Output "First SHA-256: $firstHash"
Write-Output "Second: $second"
Write-Output "Second size: $($secondInfo.Length)"
Write-Output "Second SHA-256: $secondHash"
Write-Output "Byte-identical: $equal"
if (-not $equal) { exit 2 }
