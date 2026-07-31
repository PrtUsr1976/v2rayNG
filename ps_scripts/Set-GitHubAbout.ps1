param(
    [string]$Description = '',
    [string]$Homepage = 'https://github.com/PrtUsr1976/v2rayNG/releases'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Description)) {
    $EncodedDescription = 'djJSYXlORy1hbGV4IOKAlCBBbmRyb2lkLdC60LvQuNC10L3RgiBWMlJheS9YcmF5OiBhZ2VudF92LCDRjdC60YHQv9C+0YDRgiBWTEVTUywg0L/QvtC00L/QuNGB0LDQvdC90YvQtSBtdWx0aS1BQkkgQVBLINC4IFBvd2VyU2hlbGwt0YHQutGA0LjQv9GC0YsuIEFuZHJvaWQgVjJSYXkvWHJheSBjbGllbnQgd2l0aCBWTEVTUyBleHBvcnQu'
    $Description = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedDescription))
}

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    $Topics = @('android', 'v2ray', 'xray', 'vless', 'vpn', 'proxy', 'kotlin')
    $Arguments = @('repo', 'edit', '--description', $Description, '--homepage', $Homepage)
    foreach ($Topic in $Topics) { $Arguments += @('--add-topic', $Topic) }

    & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Updating GitHub About failed: $LASTEXITCODE" }
    & gh repo view --json nameWithOwner,description,homepageUrl,repositoryTopics,url
    if ($LASTEXITCODE -ne 0) { throw "Reading GitHub About failed: $LASTEXITCODE" }
}
finally {
    Pop-Location
}
