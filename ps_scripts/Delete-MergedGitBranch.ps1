param(
    [Parameter(Mandatory = $true)]
    [string]$Branch,
    [string]$BaseBranch = 'master'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    $CurrentBranch = (& git branch --show-current).Trim()
    if ($CurrentBranch -ne $BaseBranch) {
        throw "Switch to $BaseBranch before deleting a merged branch. Current: $CurrentBranch"
    }
    if ($Branch -eq $BaseBranch) { throw 'Refusing to delete the base branch.' }

    $PullRequests = @(& gh pr list --state merged --head $Branch --json number,state,mergedAt,url | ConvertFrom-Json)
    if ($PullRequests.Count -eq 0) { throw "No merged pull request found for branch: $Branch" }

    & git push origin --delete $Branch
    if ($LASTEXITCODE -ne 0) { throw "Unable to delete remote branch: $Branch" }

    if (& git branch --list $Branch) {
        & git branch -D $Branch
        if ($LASTEXITCODE -ne 0) { throw "Unable to delete local branch: $Branch" }
    }

    Write-Host "Deleted merged branch locally and on GitHub: $Branch"
    $PullRequests | Format-Table number,state,mergedAt,url
    & git status -sb
}
finally {
    Pop-Location
}
