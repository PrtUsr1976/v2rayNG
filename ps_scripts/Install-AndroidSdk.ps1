param(
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$CommandLineToolsVersion = '15859902',
    [string]$CommandLineToolsSha256 = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a',
    [string]$NdkVersion = '29.0.14206865'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot 'V2rayNG'
$SdkRoot = [IO.Path]::GetFullPath($SdkRoot)
$SdkManager = Join-Path $SdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'

if (-not (Test-Path -LiteralPath $SdkManager -PathType Leaf)) {
    $ZipPath = Join-Path ([IO.Path]::GetTempPath()) "commandlinetools-win-$CommandLineToolsVersion.zip"
    $DownloadUrl = "https://dl.google.com/android/repository/commandlinetools-win-${CommandLineToolsVersion}_latest.zip"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
    $ActualHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualHash -ne $CommandLineToolsSha256) {
        throw "Command-line tools checksum mismatch: $ActualHash"
    }

    $Stage = Join-Path ([IO.Path]::GetTempPath()) ("android-cli-" + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($Stage) | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $Stage
    $Latest = Join-Path $SdkRoot 'cmdline-tools\latest'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Latest)) | Out-Null
    Move-Item -LiteralPath (Join-Path $Stage 'cmdline-tools') -Destination $Latest
}

1..200 | ForEach-Object { 'y' } | & $SdkManager --sdk_root=$SdkRoot --licenses | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Accepting Android SDK licenses failed: $LASTEXITCODE" }

& $SdkManager --sdk_root=$SdkRoot --channel=0 `
    'platform-tools' 'platforms;android-37.0' 'build-tools;37.0.0' "ndk;$NdkVersion"
if ($LASTEXITCODE -ne 0) { throw "Installing Android SDK packages failed: $LASTEXITCODE" }

$LocalProperties = Join-Path $AndroidRoot 'local.properties'
$EscapedSdkRoot = $SdkRoot.Replace('\', '\\').Replace(':', '\:')
[IO.File]::WriteAllText($LocalProperties, "sdk.dir=$EscapedSdkRoot`n", [Text.UTF8Encoding]::new($false))
Write-Host "Android SDK is ready: $SdkRoot"
