$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RequiredNativeFiles = @(
    'V2rayNG\app\libs\libv2ray.aar',
    'V2rayNG\app\libs\arm64-v8a\libhev-socks5-tunnel.so',
    'V2rayNG\app\libs\arm64-v8a\libhevsockstun.so'
)
if ($RequiredNativeFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RepoRoot $_) -PathType Leaf) }) {
    & (Join-Path $PSScriptRoot 'Build-NativeDependencies.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Building native dependencies failed.' }
}

& (Join-Path $PSScriptRoot 'Build-ReplacementApks.ps1') -Configuration Release
if ($LASTEXITCODE -ne 0) { throw 'Building Release APKs failed.' }

$ReleaseDirectory = Join-Path $RepoRoot 'replacement-apks\release'
$Candidates = @(Get-ChildItem -LiteralPath $ReleaseDirectory -File -Filter 'v2rayNG_*_arm64-v8a.apk' |
    Where-Object { $_.Name -notmatch '-fdroid_' } |
    Sort-Object LastWriteTime -Descending)
if ($Candidates.Count -ne 1) {
    throw "Expected one Samsung Galaxy A15 APK, found $($Candidates.Count) in $ReleaseDirectory."
}

$Source = $Candidates[0]
$OutputDirectory = Join-Path $RepoRoot '!binout'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$Destination = Join-Path $OutputDirectory $Source.Name
Copy-Item -LiteralPath $Source.FullName -Destination $Destination -Force
& (Join-Path $PSScriptRoot 'Sign-AndroidApk.ps1') -ApkPath $Destination
if ($LASTEXITCODE -ne 0) { throw 'Signing Samsung Galaxy A15 APK failed.' }
$Hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
Write-Host "Samsung Galaxy A15 APK: $Destination"
Write-Host "SHA-256: $Hash"