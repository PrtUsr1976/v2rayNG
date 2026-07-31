param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ApkPath = [IO.Path]::GetFullPath($ApkPath)
$SigningRoot = Join-Path $RepoRoot '.local-signing'
$KeyStore = Join-Path $SigningRoot 'alex-release.jks'
$PasswordFile = Join-Path $SigningRoot 'password.txt'
$StorePasswordFile = Join-Path $SigningRoot 'store-password.txt'
$KeyPasswordFile = Join-Path $SigningRoot 'key-password.txt'
$Alias = 'alex-release'
$ApkSigner = Join-Path $SdkRoot 'build-tools\37.0.0\apksigner.bat'

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw "APK not found: $ApkPath"
}
if (-not (Test-Path -LiteralPath $ApkSigner -PathType Leaf)) {
    throw "apksigner not found: $ApkSigner"
}

[IO.Directory]::CreateDirectory($SigningRoot) | Out-Null
if (-not (Test-Path -LiteralPath $PasswordFile -PathType Leaf)) {
    $RandomBytes = [byte[]]::new(32)
    $RandomGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $RandomGenerator.GetBytes($RandomBytes) } finally { $RandomGenerator.Dispose() }
    $Password = [Convert]::ToBase64String($RandomBytes)
    [IO.File]::WriteAllText($PasswordFile, $Password, [Text.UTF8Encoding]::new($false))
}
$Password = [IO.File]::ReadAllText($PasswordFile).Trim()
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($StorePasswordFile, "$Password`n", $Utf8NoBom)
[IO.File]::WriteAllText($KeyPasswordFile, "$Password`n", $Utf8NoBom)

if (-not (Test-Path -LiteralPath $KeyStore -PathType Leaf)) {
    $KeyTool = (Get-Command keytool.exe -ErrorAction Stop).Source
    & $KeyTool -genkeypair -v `
        -keystore $KeyStore -storepass $Password -keypass $Password `
        -alias $Alias -keyalg RSA -keysize 4096 -validity 10000 `
        -dname 'CN=Alex Android, OU=Local Build, O=Alex, L=Moscow, C=RU'
    if ($LASTEXITCODE -ne 0) { throw "Creating signing key failed: $LASTEXITCODE" }
}

& $ApkSigner sign --ks $KeyStore --ks-key-alias $Alias `
    --ks-pass "file:$StorePasswordFile" --key-pass "file:$KeyPasswordFile" `
    --v4-signing-enabled false $ApkPath
if ($LASTEXITCODE -ne 0) { throw "Signing APK failed: $LASTEXITCODE" }

& $ApkSigner verify --verbose --print-certs $ApkPath
if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed: $LASTEXITCODE" }
Write-Host "Signed APK: $ApkPath"
