param(
    [Parameter(Mandatory = $true)][string]$FirstPath,
    [Parameter(Mandatory = $true)][string]$SecondPath
)
$ErrorActionPreference = 'Stop'
function Get-Lines([string]$Path) {
    return @([IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_.StartsWith('vless://', [StringComparison]::OrdinalIgnoreCase) })
}
function Parse-Link([string]$Link) {
    $hash = $Link.IndexOf('#')
    $withoutFragment = if ($hash -ge 0) { $Link.Substring(0, $hash) } else { $Link }
    $fragment = if ($hash -ge 0) { $Link.Substring($hash + 1) } else { '' }
    $question = $withoutFragment.IndexOf('?')
    $base = if ($question -ge 0) { $withoutFragment.Substring(0, $question) } else { $withoutFragment }
    $queryText = if ($question -ge 0) { $withoutFragment.Substring($question + 1) } else { '' }
    $query = @{}
    foreach ($part in $queryText.Split('&', [StringSplitOptions]::RemoveEmptyEntries)) {
        $equals = $part.IndexOf('=')
        $key = if ($equals -ge 0) { $part.Substring(0, $equals) } else { $part }
        $value = if ($equals -ge 0) { $part.Substring($equals + 1) } else { '' }
        $query[$key.ToLowerInvariant()] = $value
    }
    $normalizedQuery = @($query.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
    return [pscustomobject]@{
        Raw = $Link
        Base = $base.ToLowerInvariant()
        Fragment = $fragment
        Query = $query
        Normalized = "$($base.ToLowerInvariant())?$normalizedQuery#$fragment"
    }
}
$first = @(Get-Lines $FirstPath | ForEach-Object { Parse-Link $_ })
$second = @(Get-Lines $SecondPath | ForEach-Object { Parse-Link $_ })
$rawDiff = Compare-Object @($first.Raw) @($second.Raw)
$normalizedDiff = Compare-Object @($first.Normalized) @($second.Normalized)
$firstGroups = @($first | Group-Object Base)
$secondGroups = @($second | Group-Object Base)
$firstByBase = @{}; foreach ($group in $firstGroups) { $firstByBase[$group.Name] = @($group.Group) }
$secondByBase = @{}; foreach ($group in $secondGroups) { $secondByBase[$group.Name] = @($group.Group) }
$allBases = @($firstByBase.Keys + $secondByBase.Keys | Sort-Object -Unique)
$differingGroups = 0
$changedParameterCounts = @{}
$changedFragments = 0
foreach ($base in $allBases) {
    $a = @($firstByBase[$base])
    $b = @($secondByBase[$base])
    if ($a.Count -ne $b.Count -or (Compare-Object @($a.Normalized) @($b.Normalized))) {
        $differingGroups++
        $aFragments = @($a.Fragment | Sort-Object)
        $bFragments = @($b.Fragment | Sort-Object)
        if (Compare-Object $aFragments $bFragments) { $changedFragments++ }
        $keys = @($a.Query.Keys + $b.Query.Keys | Sort-Object -Unique)
        foreach ($key in $keys) {
            $aValues = @($a | ForEach-Object { if ($_.Query.ContainsKey($key)) { [string]$_.Query[$key] } } | Sort-Object)
            $bValues = @($b | ForEach-Object { if ($_.Query.ContainsKey($key)) { [string]$_.Query[$key] } } | Sort-Object)
            if (Compare-Object $aValues $bValues) {
                if (-not $changedParameterCounts.ContainsKey($key)) { $changedParameterCounts[$key] = 0 }
                $changedParameterCounts[$key]++
            }
        }
    }
}
Write-Output "First VLESS lines: $($first.Count)"
Write-Output "First unique links: $(@($first.Raw | Sort-Object -Unique).Count)"
Write-Output "Second VLESS lines: $($second.Count)"
Write-Output "Second unique links: $(@($second.Raw | Sort-Object -Unique).Count)"
Write-Output "Unique endpoint identities in first: $($firstGroups.Count)"
Write-Output "Unique endpoint identities in second: $($secondGroups.Count)"
Write-Output "Exact link set equal (line order ignored): $($null -eq $rawDiff)"
Write-Output "Equal after query-key ordering normalization: $($null -eq $normalizedDiff)"
Write-Output "Endpoint groups with differences: $differingGroups"
Write-Output "Endpoint groups with changed names/fragments: $changedFragments"
if ($changedParameterCounts.Count) {
    Write-Output 'Parameters whose value sets differ (key=endpoint-group-count):'
    $changedParameterCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Output "$($_.Name)=$($_.Value)"
    }
} else {
    Write-Output 'Parameters whose value sets differ: none'
}
