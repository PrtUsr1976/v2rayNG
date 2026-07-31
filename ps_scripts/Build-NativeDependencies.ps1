param(
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$NdkVersion = '29.0.14206865'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppLibs = Join-Path $RepoRoot 'V2rayNG\app\libs'
$NdkRoot = Join-Path $SdkRoot "ndk\$NdkVersion"
$Bash = 'C:\Program Files\Git\bin\bash.exe'
$SubmoduleRoots = @(
    'hev-socks5-tunnel',
    'hev-socks5-tunnel\src\core',
    'hev-socks5-tunnel\third-part\hev-task-system',
    'hev-socks5-tunnel\third-part\lwip',
    'hev-socks5-tunnel\third-part\yaml'
)

Set-Location -LiteralPath $RepoRoot

if (-not (Test-Path -LiteralPath $NdkRoot -PathType Container)) {
    throw "Android NDK $NdkVersion not found: $NdkRoot"
}
if (-not (Test-Path -LiteralPath $Bash -PathType Leaf)) {
    throw "Git Bash not found: $Bash"
}

git submodule update --init --recursive
if ($LASTEXITCODE -ne 0) {
    throw "git submodule update failed with exit code $LASTEXITCODE."
}

$Tag = git -C AndroidLibXrayLite describe --tags --abbrev=0
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Tag)) {
    throw 'Unable to determine the AndroidLibXrayLite release tag.'
}

[IO.Directory]::CreateDirectory($AppLibs) | Out-Null
$AarPath = Join-Path $AppLibs 'libv2ray.aar'
if (-not (Test-Path -LiteralPath $AarPath -PathType Leaf)) {
    gh release download $Tag.Trim() --repo 2dust/AndroidLibXrayLite `
        --pattern libv2ray.aar --dir $AppLibs
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to download libv2ray.aar for $Tag."
    }
}

$MaterializedLinks = [Collections.Generic.List[object]]::new()
try {
    foreach ($RelativeRoot in $SubmoduleRoots) {
        $Root = Join-Path $RepoRoot $RelativeRoot
        $LinkEntries = @(git -C $Root ls-files -s |
            Where-Object { $_ -match '^120000 [0-9a-f]+ 0\s+(.+)$' })
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to enumerate symlinks in $RelativeRoot."
        }

        foreach ($Entry in $LinkEntries) {
            $null = $Entry -match '^120000 [0-9a-f]+ 0\s+(.+)$'
            $RelativeLink = $Matches[1]
            $LinkPath = Join-Path $Root $RelativeLink
            $TargetText = [IO.File]::ReadAllText($LinkPath)
            $TargetPath = [IO.Path]::GetFullPath(
                (Join-Path (Split-Path -Parent $LinkPath) $TargetText)
            )
            if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
                throw "Symlink target not found: $LinkPath -> $TargetText"
            }
            $MaterializedLinks.Add([pscustomobject]@{
                Path = $LinkPath
                TargetText = $TargetText
            })
            [IO.File]::WriteAllBytes($LinkPath, [IO.File]::ReadAllBytes($TargetPath))
        }
    }

    $env:NDK_HOME = $NdkRoot.Replace('\', '/')
    & $Bash (Join-Path $RepoRoot 'compile-hevtun.sh')
    if ($LASTEXITCODE -ne 0) {
        throw "compile-hevtun.sh failed with exit code $LASTEXITCODE."
    }
}
finally {
    $Utf8NoBom = [Text.UTF8Encoding]::new($false)
    foreach ($Link in $MaterializedLinks) {
        [IO.File]::WriteAllText($Link.Path, $Link.TargetText, $Utf8NoBom)
    }
}

$GeneratedLibs = Join-Path $RepoRoot 'libs'
Get-ChildItem -LiteralPath $GeneratedLibs -Recurse -File |
    Where-Object { $_.Extension -ne '.so' } |
    Remove-Item -Force

Copy-Item -LiteralPath (Join-Path $RepoRoot 'libs') `
    -Destination (Join-Path $RepoRoot 'V2rayNG\app') -Recurse -Force

$NativeFiles = @(Get-ChildItem -LiteralPath $AppLibs -Recurse -File |
    Where-Object { $_.Extension -in '.aar', '.so' })
if ($NativeFiles.Count -eq 0) {
    throw 'No native Android dependencies were produced.'
}

foreach ($File in $NativeFiles) {
    git check-ignore --quiet -- $File.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Generated dependency is not ignored by Git: $($File.FullName)"
    }
}

Write-Host "Native Android dependencies are ready ($($NativeFiles.Count) files)."
