param(
    [string]$Description = '',
    [string]$Homepage = 'https://github.com/PrtUsr1976/v2rayNG/releases'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Description)) {
    $EncodedDescription = 'djJSYXlORy1hbGV4IOKAlCBVc2VyLUFnZW50INC4IEhXSUQsINC40LzQv9C+0YDRgiDQv9C+0LTQv9C40YHQvtC6INC40Lcg0YTQsNC50LvQsCwg0Y3QutGB0L/QvtGA0YIg0LrQvtC90YTQuNCz0YPRgNCw0YbQuNC5INCyINGE0LDQudC7LiBVc2VyLUFnZW50ICYgSFdJRCwgc3Vic2NyaXB0aW9uIGltcG9ydCBhbmQgY29uZmlndXJhdGlvbiBleHBvcnQgdmlhIGZpbGVzLg=='
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
