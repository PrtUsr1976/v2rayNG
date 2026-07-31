param(
    [Parameter(Mandatory = $true)]
    [string]$CommitMessage,
    [string]$BaseBranch = 'master',
    [switch]$OpenPullRequest,
    [switch]$RepairPrivateEmail
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    & git rev-parse --is-inside-work-tree | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Not a Git repository.' }

    $Branch = (& git branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($Branch)) { throw 'Detached HEAD is not supported.' }

    if ($RepairPrivateEmail) {
        $GitHubUser = & gh api user | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Unable to read the authenticated GitHub account.' }
        $NoReplyEmail = "$($GitHubUser.id)+$($GitHubUser.login)@users.noreply.github.com"
        & git config user.email $NoReplyEmail
        if ($LASTEXITCODE -ne 0) { throw 'Unable to configure the GitHub noreply email.' }
    }

    & git add -- .gitignore README.md V2rayNG compile-hevtun.sh ps_scripts
    if ($LASTEXITCODE -ne 0) { throw "git add failed: $LASTEXITCODE" }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged changes contain whitespace errors.' }

    if (-not $RepairPrivateEmail) { & git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { throw 'There are no staged changes to commit.' } }
    if ($RepairPrivateEmail) { & git commit --amend --no-edit --reset-author } else { & git commit -m $CommitMessage }
    if ($LASTEXITCODE -ne 0) { throw "git commit failed: $LASTEXITCODE" }

    if ($RepairPrivateEmail) {
        & git push --force-with-lease -u origin $Branch
    } else {
        & git push -u origin $Branch
    }
    if ($LASTEXITCODE -ne 0) { throw "git push failed: $LASTEXITCODE" }

    if ($OpenPullRequest) {
        $ExistingPrJson = (& gh pr list --head $Branch --json url --limit 1) -join ""
        if ($ExistingPrJson -eq '[]') {
            $Body = @"
## Что изменено

- добавлены переключатели agent_v и экспорта VLESS с сохранением выбранных путей;
- VLESS-ссылки экспортируются в текстовые файлы по именам подписок;
- приложение переименовано в v2RayNG-alex;
- добавлены Windows PowerShell-скрипты для SDK, сборки, тестов, подписи и Git-операций.

## Проверка

- Release APK успешно собран;
- APK для Samsung Galaxy A15 подписан и проверен схемами v2/v3;
- целевые тесты экспорта VLESS проходят.
"@
            & gh pr create --draft --base $BaseBranch --head $Branch --title $CommitMessage --body $Body
            if ($LASTEXITCODE -ne 0) { throw "Creating pull request failed: $LASTEXITCODE" }
        }
    }

    & git status -sb
}
finally {
    Pop-Location
}
