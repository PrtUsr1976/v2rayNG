param(
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',
    [switch]$SkipBuild,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot 'V2rayNG'
$GradleWrapper = Join-Path $AndroidRoot 'gradlew.bat'
$VariantName = $Configuration.ToLowerInvariant()
$BuildRoot = Join-Path $AndroidRoot 'app\build\outputs\apk'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot "replacement-apks\$VariantName"
}
$OutputRoot = [IO.Path]::GetFullPath($OutputPath)
if ($OutputRoot -eq [IO.Path]::GetFullPath($RepoRoot)) {
    throw 'The repository root cannot be used as the output directory.'
}
if (-not (Test-Path -LiteralPath $GradleWrapper -PathType Leaf)) {
    throw "Gradle wrapper not found: $GradleWrapper"
}

if (-not $SkipBuild) {
    if (Test-Path -LiteralPath $BuildRoot -PathType Container) {
        Get-ChildItem -LiteralPath $BuildRoot -Recurse -File -Filter '*.apk' |
            Remove-Item -Force
    }
    Set-Location -LiteralPath $AndroidRoot
    $Task = if ($Configuration -eq 'Release') { 'assembleRelease' } else { 'assembleDebug' }
    Write-Host "Building Android $Configuration APKs..."
    & $GradleWrapper $Task
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle $Task failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $BuildRoot -PathType Container)) {
    throw "APK output directory not found: $BuildRoot"
}
$Apks = @(Get-ChildItem -LiteralPath $BuildRoot -Recurse -File -Filter '*.apk' |
    Where-Object { $_.FullName -match "[\\/]$([regex]::Escape($VariantName))[\\/]" })
if ($Apks.Count -eq 0) {
    throw "No $Configuration APK files found under: $BuildRoot"
}

if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
[IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
foreach ($Apk in $Apks) {
    Copy-Item -LiteralPath $Apk.FullName -Destination (Join-Path $OutputRoot $Apk.Name)
    Write-Host "Copied $($Apk.Name)"
}
Write-Host "Replacement APK package is ready: $OutputRoot"