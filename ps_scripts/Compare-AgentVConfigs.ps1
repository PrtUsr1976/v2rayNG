param(
    [Parameter(Mandatory = $true)]
    [string]$ActualPath,
    [string]$ReferencePath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReferencePath)) {
    $ReferencePath = Join-Path $RepoRoot 'agent_v_example\agent_v'
}

function Read-AgentVConfig {
    param([Parameter(Mandatory = $true)][string]$Path)

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $Values = [ordered]@{}
    $LineNumber = 0
    foreach ($Line in [IO.File]::ReadAllLines($ResolvedPath)) {
        $LineNumber++
        $Trimmed = $Line.Trim()
        if ($Trimmed.Length -eq 0 -or $Trimmed.StartsWith('#') -or $Trimmed.StartsWith(';')) {
            continue
        }
        $Separator = $Trimmed.IndexOf('=')
        if ($Separator -le 0) {
            throw "Invalid agent_v line $LineNumber in ${ResolvedPath}: expected key=value"
        }
        $Key = $Trimmed.Substring(0, $Separator).Trim()
        $Value = $Trimmed.Substring($Separator + 1).Trim()
        if ($Values.Contains($Key)) {
            throw "Duplicate agent_v key '$Key' in $ResolvedPath"
        }
        $Values[$Key] = $Value
    }
    return $Values
}

$Reference = Read-AgentVConfig $ReferencePath
$Actual = Read-AgentVConfig $ActualPath
$Keys = @($Reference.Keys + $Actual.Keys | Sort-Object -Unique)
$Differences = @()
foreach ($Key in $Keys) {
    $ReferenceValue = if ($Reference.Contains($Key)) { $Reference[$Key] } else { $null }
    $ActualValue = if ($Actual.Contains($Key)) { $Actual[$Key] } else { $null }
    if ($ReferenceValue -cne $ActualValue) {
        $Differences += [pscustomobject]@{
            Key = $Key
            Reference = $ReferenceValue
            Actual = $ActualValue
        }
    }
}

if ($Differences.Count -gt 0) {
    $Differences | Format-Table -AutoSize
    throw "agent_v configurations differ in $($Differences.Count) key(s)."
}
Write-Host "agent_v configurations match ($($Keys.Count) keys)."