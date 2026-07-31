param(
    [string]$Branch = '',
    [string]$Workflow = 'build.yml',
    [string]$ReleaseTag = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $Branch = (& git branch --show-current).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($Branch)) { throw 'A Git branch is required.' }

    $Arguments = @('workflow', 'run', $Workflow, '--ref', $Branch)
    if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
        $Arguments += @('-f', "release_tag=$ReleaseTag")
    }
    & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Starting GitHub workflow failed: $LASTEXITCODE" }

    Start-Sleep -Seconds 2
    $Run = & gh run list --workflow $Workflow --branch $Branch --event workflow_dispatch `
        --limit 1 --json databaseId,url,status,conclusion,headBranch,createdAt | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $null -eq $Run) { throw 'Unable to find the new workflow run.' }

    $Run | Format-List databaseId,url,status,conclusion,headBranch,createdAt
}
finally {
    Pop-Location
}
