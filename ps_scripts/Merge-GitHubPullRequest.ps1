param(
    [int]$PullRequest = 3,
    [string]$BaseBranch = 'master'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    $Pr = & gh pr view $PullRequest --json isDraft,state,url | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "Unable to read PR #$PullRequest." }
    if ($Pr.state -ne 'OPEN') { throw "PR #$PullRequest is not open: $($Pr.state)" }

    if ($Pr.isDraft) {
        & gh pr ready $PullRequest
        if ($LASTEXITCODE -ne 0) { throw "Unable to mark PR #$PullRequest ready." }
    }

    & gh pr merge $PullRequest --squash
    if ($LASTEXITCODE -ne 0) { throw "Unable to merge PR #$PullRequest." }

    & git fetch origin
    if ($LASTEXITCODE -ne 0) { throw 'git fetch failed.' }
    & git switch $BaseBranch
    if ($LASTEXITCODE -ne 0) { throw "Unable to switch to $BaseBranch." }
    & git pull --ff-only origin $BaseBranch
    if ($LASTEXITCODE -ne 0) { throw "Unable to update local $BaseBranch." }

    & gh pr view $PullRequest --json state,mergedAt,mergeCommit,url
    & git status -sb
}
finally {
    Pop-Location
}
