param(
    [string]$SecretName = 'GPG_PRIVATE_KEY',
    [string]$KeyName = 'v2RayNG-alex Release',
    [string]$KeyEmail = 'v2rayng-alex@users.noreply.github.com'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$SigningRoot = Join-Path $RepoRoot '.local-signing\github-gpg'
$GpgHome = Join-Path $SigningRoot 'home'
$BatchFile = Join-Path $SigningRoot 'generate-key.txt'
$PrivateKeyFile = Join-Path $SigningRoot 'private-key.asc'
$PublicKeyFile = Join-Path $SigningRoot 'public-key.asc'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

$GpgCommand = Get-Command gpg.exe -ErrorAction SilentlyContinue
$Gpg = if ($null -ne $GpgCommand) { $GpgCommand.Source } else { 'C:\Program Files\Git\usr\bin\gpg.exe' }
if (-not (Test-Path -LiteralPath $Gpg -PathType Leaf)) { throw 'gpg.exe was not found.' }
$GpgHomeArg = '/' + $GpgHome.Substring(0, 1).ToLowerInvariant() + $GpgHome.Substring(2).Replace('\', '/')
$BatchFileArg = '/' + $BatchFile.Substring(0, 1).ToLowerInvariant() + $BatchFile.Substring(2).Replace('\', '/')
$Gh = (Get-Command gh.exe -ErrorAction Stop).Source
[IO.Directory]::CreateDirectory($GpgHome) | Out-Null

if (-not (Test-Path -LiteralPath $PrivateKeyFile -PathType Leaf)) {
    $Batch = @"
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $KeyName
Name-Email: $KeyEmail
Expire-Date: 0
%commit
"@
    [IO.File]::WriteAllText($BatchFile, $Batch, $Utf8NoBom)
    & $Gpg --homedir $GpgHomeArg --batch --generate-key $BatchFileArg
    if ($LASTEXITCODE -ne 0) { throw "GPG key generation failed: $LASTEXITCODE" }

    $Fingerprint = (& $Gpg --homedir $GpgHomeArg --batch --with-colons --list-secret-keys |
        Where-Object { $_ -like 'fpr:*' } | Select-Object -First 1).Split(':')[9]
    if ([string]::IsNullOrWhiteSpace($Fingerprint)) { throw 'GPG fingerprint was not found.' }

    $PrivateKey = (& $Gpg --homedir $GpgHomeArg --batch --armor --export-secret-keys $Fingerprint) -join "`n"
    $PublicKey = (& $Gpg --homedir $GpgHomeArg --batch --armor --export $Fingerprint) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not $PrivateKey.Contains('BEGIN PGP PRIVATE KEY BLOCK')) {
        throw 'Exporting the GPG private key failed.'
    }
    [IO.File]::WriteAllText($PrivateKeyFile, $PrivateKey + "`n", $Utf8NoBom)
    [IO.File]::WriteAllText($PublicKeyFile, $PublicKey + "`n", $Utf8NoBom)
}

$Fingerprint = (& $Gpg --homedir $GpgHomeArg --batch --with-colons --list-secret-keys |
    Where-Object { $_ -like 'fpr:*' } | Select-Object -First 1).Split(':')[9]
Get-Content -Raw -LiteralPath $PrivateKeyFile | & $Gh secret set $SecretName
if ($LASTEXITCODE -ne 0) { throw "Updating GitHub secret failed: $LASTEXITCODE" }

Write-Host "GitHub secret updated: $SecretName"
Write-Host "GPG fingerprint: $Fingerprint"
Write-Host "Local public key: $PublicKeyFile"
Write-Host 'The private key is stored only in the gitignored .local-signing directory.'
