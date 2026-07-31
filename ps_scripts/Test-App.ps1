param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot 'V2rayNG'
$GradleWrapper = Join-Path $AndroidRoot 'gradlew.bat'
if (-not (Test-Path -LiteralPath $GradleWrapper -PathType Leaf)) {
    throw "Gradle wrapper not found: $GradleWrapper"
}

Set-Location -LiteralPath $AndroidRoot
$Task = if ($Configuration -eq 'Release') {
    ':app:testPlaystoreReleaseUnitTest'
} else {
    ':app:testPlaystoreDebugUnitTest'
}
& $GradleWrapper $Task
if ($LASTEXITCODE -ne 0) {
    throw "Gradle $Task failed with exit code $LASTEXITCODE."
}