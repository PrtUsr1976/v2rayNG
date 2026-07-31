param(
    [Parameter(Mandatory = $true)]
    [long]$RunId,
    [int]$IntervalSeconds = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location $RepoRoot
try {
    & gh run watch $RunId --exit-status --interval $IntervalSeconds
    $WatchExitCode = $LASTEXITCODE
    & gh run view $RunId --json databaseId,url,status,conclusion,headBranch,createdAt,updatedAt,jobs
    if ($WatchExitCode -ne 0) { throw "GitHub workflow failed: $RunId" }
}
finally {
    Pop-Location
}
