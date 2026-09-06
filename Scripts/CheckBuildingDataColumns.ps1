<#
.SYNOPSIS
    Reports which building_data columns exist on a deployed DiGi GIS WebAPI host, and how full they are for a county.

.DESCRIPTION
    Answers two questions that 'buildingdata/coveragebycountyid' cannot: which columns exist at all, and which of them
    actually carry values. Coverage returns row counts only - Building2DCount, BuildingDataCount, MissingReferenceCount,
    OrphanReferenceCount, UnassignedSubdivisionCount - and says nothing about columns.

    Existence comes from GET gis/buildingdata/columns, which returns the whole catalogue: every column present anywhere
    in the table. A column group missing from it exists nowhere, for any county.

    Fill rates come from one POST gis/buildingdata/tablebybuildingdatabypagingparameter page, counted per column.

    A fill rate is not the same question as whether the values are usable. -Distribution summarizes that same page per
    numeric column - count, exact zeros, minimum, median, maximum - which is what separates written measurements from
    placeholder zeros.

    Written for the Year Built prediction retrain gate, where 108 of the 172 allow-list columns existed nowhere and a
    training table assembled anyway would have been 63 percent silently defaulted values. The -Group switch reports the
    allow-list groups; without it every catalogue column is listed.

.PARAMETER HostUri
    The base URI of the WebAPI host (default: 'https://api.digiproject.uk').

.PARAMETER CountyId
    Optional county identifier. When given, a page of rows is read and per-column fill rates are reported alongside
    existence. A county identifier, never a four character county code.

.PARAMETER PageSize
    Rows to sample for the fill-rate pass (default: 250). Ignored without -CountyId.

.PARAMETER Group
    Summarize by Year Built prediction allow-list group (base, grid cell coverage, detection, population, radial ratio)
    instead of listing every column.

.PARAMETER Years
    Year range for the detection and population groups (default: 2008..2025). Two integers, first and last.

.PARAMETER Distribution
    Reports the value distribution of each numeric column - count, exact zeros, minimum, median and maximum - alongside
    existence and fill. A fill rate cannot tell a written value from a placeholder: county 8948 read as 'radial ratio
    8 / 8 fully filled' while 84 to 100 percent of the filled cells held exactly 0.0. Computed from the page already
    fetched for -CountyId, so it costs no additional request, and reported only with -CountyId. The median is the upper
    median when the sampled row count is even.

.PARAMETER Column
    Optional wildcard filter for the distribution pass, matched against the column name (for example 'Radial*'). Without
    it every numeric column of the sampled page is reported. Ignored without -Distribution.

.PARAMETER Json
    Emit the result as JSON instead of formatted text.

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -Group

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -CountyId 104106 -Group

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -CountyId 8948 -Group -Distribution -Column "Radial*"

.NOTES
    Call this sequentially, never concurrently against several counties at once - concurrent calls exhaust the
    connection pool and the host answers 500 on every terrain endpoint until the service restarts.
#>
[CmdletBinding()]
param(
    [string] $HostUri = 'https://api.digiproject.uk',
    [int] $CountyId = 0,
    [int] $PageSize = 250,
    [switch] $Group,
    [int[]] $Years = @(2008, 2025),
    [switch] $Distribution,
    [string] $Column,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$HostUri = $HostUri.TrimEnd('/')

function Get-ExpectedGroups {
    param([int] $YearFirst, [int] $YearLast)

    $base = @(
        'Floor area', 'Total area', 'Storeys', 'Azimuth', 'Cardinal direction',
        'Internal Point X', 'Internal Point Y', 'BoundingBox X', 'BoundingBox Y',
        'BoundingBox width', 'BoundingBox height', 'Isoperimetric ratio',
        'Rectangular thinnes ratio', 'Square thinness ratio', 'Thinness ratio',
        'Convex hull thinness ratio', 'Calculated Building Shape',
        'Building general function', 'Building specific functions', 'Building Phase',
        'Is residential', 'Is occupied', 'Voivodeship name', 'County name', 'County Id',
        'Municipality name', 'Subdivision name', 'Subdivision Id', 'Settlement type',
        'Subdivision occupancy', 'Calculated occupancy')

    $grid = @()
    foreach ($i in 0..4) { foreach ($j in 0..4) { $grid += "Grid cell coverage [$i,$j]" } }

    $detection = @()
    $population = @()
    foreach ($year in $YearFirst..$YearLast) {
        foreach ($prefix in 'Prediction Confidence', 'Prediction BoundingBox X', 'Prediction BoundingBox Y',
                            'Prediction BoundingBox Width', 'Prediction BoundingBox Height') {
            $detection += "$prefix $year"
        }
        $population += "Municipality population $year"
    }

    $radial = @()
    foreach ($radius in 200, 400, 600, 1000) {
        $radial += "Radial Building Coverage Ratio ${radius}m"
        $radial += "Radial Floor Area Ratio ${radius}m"
    }

    return [ordered]@{
        'base'                = $base
        'grid cell coverage'  = $grid
        'detection'           = $detection
        'population'          = $population
        'radial ratio'        = $radial
    }
}

# --- Existence: the whole catalogue -------------------------------------------------------------
$uri_Columns = "$HostUri/gis/buildingdata/columns"
Write-Verbose "GET $uri_Columns"
$columns = Invoke-RestMethod -Uri $uri_Columns -Method Get -TimeoutSec 300
$names_Catalogue = @($columns | ForEach-Object { $_.Name })

# --- Fill rates: one page, counted per column ---------------------------------------------------
$fill = @{}
$distributions = @()
$rowCount = 0
if ($CountyId -gt 0) {
    $body = @{
        '_type'    = 'DiGi.GIS.WebAPI.Classes.BuildingDataByPagingParameter,DiGi.GIS.WebAPI'
        'CountyId' = $CountyId
        'PageSize' = $PageSize
    } | ConvertTo-Json -Compress

    $uri_Page = "$HostUri/gis/buildingdata/tablebybuildingdatabypagingparameter"
    Write-Verbose "POST $uri_Page (CountyId $CountyId, PageSize $PageSize)"
    $table = Invoke-RestMethod -Uri $uri_Page -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 600

    $names_Page = @($table.Columns | ForEach-Object { $_.Name })
    $rows = @($table.Rows)
    $rowCount = $rows.Count

    for ($i = 0; $i -lt $names_Page.Count; $i++) {
        $filled = 0
        foreach ($row in $rows) {
            $value = $row[$i]
            if ($null -ne $value -and "$value" -ne '') { $filled++ }
        }
        $fill[$names_Page[$i]] = $filled
    }

    # --- Distribution: the same page, summarized per numeric column -----------------------------
    # No second request. A fill rate only says a cell is not empty, and 84 to 100 percent of the
    # cells that made twelve counties read as filled held exactly 0.0.
    if ($Distribution) {
        $names_Candidate = $names_Page
        if ($Group) {
            $groups_Allowed = Get-ExpectedGroups -YearFirst $Years[0] -YearLast $Years[-1]
            $names_Allowed = @()
            foreach ($key in $groups_Allowed.Keys) { $names_Allowed += $groups_Allowed[$key] }
            $names_Candidate = @($names_Candidate | Where-Object { $names_Allowed -contains $_ })
        }

        if (-not [string]::IsNullOrWhiteSpace($Column)) {
            $names_Candidate = @($names_Candidate | Where-Object { $_ -like $Column })
        }

        foreach ($name in $names_Candidate) {
            $index = [array]::IndexOf($names_Page, $name)
            if ($index -lt 0) { continue }

            $numbers = [System.Collections.Generic.List[double]]::new()
            foreach ($row in $rows) {
                $value = $row[$index]
                if ($null -eq $value -or "$value" -eq '') { continue }

                if ($value -is [double] -or $value -is [single] -or $value -is [decimal] -or $value -is [int] -or $value -is [long]) {
                    $numbers.Add([double] $value)
                    continue
                }

                # Parsed invariantly on purpose: a decimal comma from the current culture would drop
                # every value and report the column as text.
                $number = 0.0
                $text = [System.Convert]::ToString($value, [System.Globalization.CultureInfo]::InvariantCulture)
                if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $number)) {
                    $numbers.Add($number)
                }
            }

            # Nothing numeric means a text column, not an empty measurement - leave it out entirely.
            if ($numbers.Count -eq 0) { continue }

            $sorted = @($numbers | Sort-Object)

            $distributions += [pscustomobject]@{
                Column = $name
                Count  = $numbers.Count
                Zeros  = @($numbers | Where-Object { $_ -eq 0 }).Count
                Min    = $sorted[0]
                Median = $sorted[[int]($sorted.Count / 2)]
                Max    = $sorted[$sorted.Count - 1]
            }
        }
    }
}

# --- Report -------------------------------------------------------------------------------------
$result = [ordered]@{
    HostUri         = $HostUri
    CountyId        = if ($CountyId -gt 0) { $CountyId } else { $null }
    CatalogueCount  = $names_Catalogue.Count
    SampledRowCount = $rowCount
}

if ($Group) {
    $groups = Get-ExpectedGroups -YearFirst $Years[0] -YearLast $Years[-1]
    $rowsOut = @()
    $total = 0
    $present = 0

    foreach ($name in $groups.Keys) {
        $expected = $groups[$name]
        $exists = @($expected | Where-Object { $names_Catalogue -contains $_ })
        $total += $expected.Count
        $present += $exists.Count

        $filledFully = $null
        if ($CountyId -gt 0 -and $rowCount -gt 0) {
            $filledFully = @($exists | Where-Object { $fill.ContainsKey($_) -and $fill[$_] -eq $rowCount }).Count
        }

        $rowsOut += [pscustomobject]@{
            Group      = $name
            Expected   = $expected.Count
            Present    = $exists.Count
            FullyFille = $filledFully
        }
    }

    $result['Groups'] = $rowsOut
    $result['ExpectedTotal'] = $total
    $result['PresentTotal'] = $present

    if (-not $Json) {
        Write-Host ''
        Write-Host "building_data columns on $HostUri" -ForegroundColor Cyan
        Write-Host "  catalogue: $($names_Catalogue.Count) columns"
        if ($CountyId -gt 0) { Write-Host "  county $CountyId sampled over $rowCount rows" }
        Write-Host ''
        foreach ($row in $rowsOut) {
            $flag = if ($row.Present -eq $row.Expected) { '' } else { '   <-- MISSING' }
            $colour = if ($row.Present -eq $row.Expected) { 'Green' } else { 'Red' }
            $text = '  {0,-22} {1,3} / {2,3}' -f $row.Group, $row.Present, $row.Expected
            if ($null -ne $row.FullyFille) { $text += '   fully filled: {0,3}' -f $row.FullyFille }
            Write-Host ($text + $flag) -ForegroundColor $colour
        }
        Write-Host ('  {0,-22} {1,3} / {2,3}' -f 'TOTAL', $present, $total) -ForegroundColor Cyan
        Write-Host ''
    }
}
else {
    $rowsOut = @()
    foreach ($name in ($names_Catalogue | Sort-Object)) {
        $percent = $null
        if ($CountyId -gt 0 -and $rowCount -gt 0 -and $fill.ContainsKey($name)) {
            $percent = [int](($fill[$name] * 100) / $rowCount)
        }
        $rowsOut += [pscustomobject]@{ Column = $name; FilledPercent = $percent }
    }
    $result['Columns'] = $rowsOut

    if (-not $Json) {
        Write-Host ''
        Write-Host "building_data catalogue on $HostUri - $($names_Catalogue.Count) columns" -ForegroundColor Cyan
        if ($CountyId -gt 0) { Write-Host "county $CountyId sampled over $rowCount rows" }
        Write-Host ''
        foreach ($row in $rowsOut) {
            if ($null -ne $row.FilledPercent) {
                Write-Host ('  {0,3}%  {1}' -f $row.FilledPercent, $row.Column)
            }
            else {
                Write-Host ('        {0}' -f $row.Column)
            }
        }
        Write-Host ''
    }
}

if ($Distribution) {
    $result['Distribution'] = $distributions

    if (-not $Json) {
        if ($CountyId -le 0) {
            Write-Warning '-Distribution reports nothing without -CountyId: the values come from a sampled page of one county.'
        }
        elseif ($distributions.Count -eq 0) {
            Write-Warning 'No numeric column matched the distribution filter.'
        }
        else {
            Write-Host "value distribution - county $CountyId over $rowCount rows" -ForegroundColor Cyan
            Write-Host ''
            foreach ($row in $distributions) {
                $colour = if ($row.Zeros -eq 0) { 'Green' } else { 'Yellow' }
                Write-Host ('  {0,-42} n={1,4}  zeros={2,4}  min={3,12:G6}  median={4,12:G6}  max={5,12:G6}' -f $row.Column, $row.Count, $row.Zeros, $row.Min, $row.Median, $row.Max) -ForegroundColor $colour
            }
            Write-Host ''
        }
    }
}

if ($Json) { $result | ConvertTo-Json -Depth 5 }
