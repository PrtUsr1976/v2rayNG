$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot 'V2rayNG'
$GradleWrapper = Join-Path $AndroidRoot 'gradlew.bat'

Set-Location -LiteralPath $AndroidRoot
& $GradleWrapper ':app:testPlaystoreDebugUnitTest' `
    '--tests' 'com.v2ray.ang.SubscriptionVlessExporterTest'
if ($LASTEXITCODE -ne 0) {
    throw "VLESS export tests failed with exit code $LASTEXITCODE."
}
