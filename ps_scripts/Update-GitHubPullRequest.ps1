param(
    [Parameter(Mandatory = $true)]
    [int]$PullRequest,
    [Parameter(Mandatory = $true)]
    [string]$BodyBase64,
    [string]$Title = '',
    [switch]$MarkReady
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    $Body = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($BodyBase64))
    $Arguments = @('pr', 'edit', $PullRequest, '--body', $Body)
    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        $Arguments += @('--title', $Title)
    }
    & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Updating PR #$PullRequest failed: $LASTEXITCODE" }

    if ($MarkReady) {
        $Pr = & gh pr view $PullRequest --json isDraft | ConvertFrom-Json
        if ($Pr.isDraft) {
            & gh pr ready $PullRequest
            if ($LASTEXITCODE -ne 0) { throw "Marking PR #$PullRequest ready failed." }
        }
    }

    & gh pr view $PullRequest --json number,title,state,isDraft,body,url
}
finally {
    Pop-Location
}
