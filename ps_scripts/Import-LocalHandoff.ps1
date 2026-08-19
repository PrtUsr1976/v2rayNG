param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [Parameter(Mandatory = $true)]
    [string]$HeaderFilePath,
    [string]$AgentsPath = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $repoRoot '.local-handoff'
$sources = @($ArchivePath, $HeaderFilePath)
if (-not [string]::IsNullOrWhiteSpace($AgentsPath)) { $sources += $AgentsPath }
foreach ($source in $sources) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Source file not found: $source" }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath $ArchivePath -Destination (Join-Path $destination 'handoff.zip') -Force
Copy-Item -LiteralPath $HeaderFilePath -Destination (Join-Path $destination 'hwid') -Force
if (-not [string]::IsNullOrWhiteSpace($AgentsPath)) {
    Copy-Item -LiteralPath $AgentsPath -Destination (Join-Path $destination 'AGENTS.md') -Force
}
Write-Output "Private handoff files copied to: $destination"
Write-Output 'The destination is excluded by the repository .gitignore.'
