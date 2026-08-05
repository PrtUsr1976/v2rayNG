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

    & git add -- .gitignore .github README.md V2rayNG compile-hevtun.sh ps_scripts
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
            $EncodedBodyTemplate = 'IyMg0JjQt9C80LXQvdC10L3QuNGPIC8gQ2hhbmdlcwoKLSB7MH0KCiMjINCf0YDQvtCy0LXRgNC60LAgLyBWYWxpZGF0aW9uCgotINCY0LfQvNC10L3QtdC90LjRjyDRgdC+0YXRgNCw0L3QtdC90Ysg0LIgR2l0INC4INC+0YLQv9GA0LDQstC70LXQvdGLINCyINCy0LXRgtC60YMgYHsxfWAuCi0g0J/QtdGA0LXQtCDQvtCx0YrQtdC00LjQvdC10L3QuNC10Lwg0L/RgNC+0LLQtdGA0YzRgtC1INGA0LXQt9GD0LvRjNGC0LDRgtGLINGC0LXRgdGC0L7QsiDQuCDRgdCx0L7RgNC60LguCi0gQ2hhbmdlcyB3ZXJlIGNvbW1pdHRlZCBhbmQgcHVzaGVkIHRvIGJyYW5jaCBgezF9YC4KLSBSZXZpZXcgdGVzdCBhbmQgYnVpbGQgcmVzdWx0cyBiZWZvcmUgbWVyZ2luZy4='
            $BodyTemplate = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedBodyTemplate))
            $Body = $BodyTemplate -f $CommitMessage, $Branch
            & gh pr create --draft --base $BaseBranch --head $Branch --title $CommitMessage --body $Body
            if ($LASTEXITCODE -ne 0) { throw "Creating pull request failed: $LASTEXITCODE" }
        }
    }

    & git status -sb
}
finally {
    Pop-Location
}
