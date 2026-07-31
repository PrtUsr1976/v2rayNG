$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot 'V2rayNG'
$GradleWrapper = Join-Path $AndroidRoot 'gradlew.bat'

Set-Location -LiteralPath $AndroidRoot
& $GradleWrapper --stop
if ($LASTEXITCODE -ne 0) {
    throw "Stopping Gradle daemons failed with exit code $LASTEXITCODE."
}
