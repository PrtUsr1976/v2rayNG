param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    & git diff --check
    if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }

    $trackedPrivate = & git ls-files -- 'hwid' 'agent_v' '.local-handoff/*'
    if ($trackedPrivate) {
        Write-Output 'Tracked matching paths:'
        $trackedPrivate | ForEach-Object { Write-Output $_ }
        throw 'Private header or handoff files are tracked by Git.'
    }

    foreach ($privatePath in @('.local-handoff/hwid', '.local-handoff/handoff.zip')) {
        & git check-ignore --quiet -- $privatePath
        if ($LASTEXITCODE -ne 0) { throw "Private path is not ignored: $privatePath" }
    }

    $paths = @(
        '.gitignore',
        'V2rayNG/app/build.gradle.kts',
        'V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt',
        'V2rayNG/app/src/main/java/com/v2ray/ang/util/AgentVConfig.kt',
        'V2rayNG/app/src/main/java/com/v2ray/ang/util/HttpUtil.kt',
        'V2rayNG/app/src/main/java/com/v2ray/ang/util/SubscriptionVlessExporter.kt',
        'V2rayNG/app/src/main/res/values/strings.xml',
        'V2rayNG/app/src/main/res/values-ru/strings.xml',
        'V2rayNG/app/src/test/java/com/v2ray/ang/AgentVConfigTest.kt',
        'V2rayNG/app/src/test/java/com/v2ray/ang/AgentVHttpHeadersTest.kt',
        'V2rayNG/app/src/test/java/com/v2ray/ang/SubscriptionVlessExporterTest.kt'
    )
    foreach ($path in $paths) {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot $path))
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        if ($text -match '(?<!\r)\n') { throw "Non-CRLF line ending: $path" }
    }
    Write-Output 'Task checks passed: diff, CRLF, private file tracking and ignore rules.'
}
finally {
    Pop-Location
}
