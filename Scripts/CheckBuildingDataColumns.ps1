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
    numeric column - count, missing cells, exact zeros, minimum, median, maximum - which is what separates written
    measurements from placeholder zeros.

    One page is a sample. -All pages through the whole county instead, seeking on the Reference of the last row read, so
    a gap that sits outside the first page cannot hide. Combined with -Column the request is narrowed server-side to the
    matching columns, which is what makes reading a whole county cheap.

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

.PARAMETER All
    Reads every row of the county rather than one page, seeking on the Reference of the last row of the previous page.
    Requires -CountyId. With -Column the request is narrowed server-side to the matching columns; without it every
    column of every row is transferred, which is a great deal of payload. Because a narrowed page carries no data for
    the other columns, the fill counts of the -Group table are suppressed rather than reported as a collapse.

.PARAMETER Json
    Emit the result as JSON instead of formatted text.

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -Group

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -CountyId 104106 -Group

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -CountyId 8948 -Group -Distribution -Column "Radial*"

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/CheckBuildingDataColumns.ps1" -CountyId 8948 -Distribution -Column "Radial*" -All

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
    [switch] $All,
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

# --- Fill rates: one page, or the whole county with -All, counted per column ---------------------
$fill = @{}
$distributions = @()
$rowCount = 0
$pageCount = 0
$narrowed = $false

if ($All -and $CountyId -le 0) {
    Write-Warning '-All needs -CountyId: there is no county to page through.'
}

if ($CountyId -gt 0) {
    $uri_Page = "$HostUri/gis/buildingdata/tablebybuildingdatabypagingparameter"

    # Narrowed only when the whole county is read. One page of every column costs nothing, and
    # narrowing it would leave the -Group fill counts describing eight columns out of 172.
    $columnUniqueIds = $null
    if ($All -and -not [string]::IsNullOrWhiteSpace($Column)) {
        $columnUniqueIds = @($columns | Where-Object { $_.Name -like $Column } | ForEach-Object { $_.UniqueId })
        if ($columnUniqueIds.Count -eq 0) {
            Write-Warning "No catalogue column matches '$Column'. Reading every column instead."
            $columnUniqueIds = $null
        }
    }

    $narrowed = $null -ne $columnUniqueIds
    if ($All -and -not $narrowed) {
        Write-Warning 'Reading every column of every row. Pass -Column to narrow the request server-side.'
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $names_Page = @()
    $cursor = $null

    while ($true) {
        $parameter = [ordered]@{
            '_type'    = 'DiGi.GIS.WebAPI.Classes.BuildingDataByPagingParameter,DiGi.GIS.WebAPI'
            'CountyId' = $CountyId
            'PageSize' = $PageSize
        }

        if ($narrowed) { $parameter['ColumnUniqueIds'] = $columnUniqueIds }
        if ($null -ne $cursor) { $parameter['Cursor'] = $cursor }

        Write-Verbose "POST $uri_Page (CountyId $CountyId, PageSize $PageSize, page $($pageCount + 1))"
        $table = Invoke-RestMethod -Uri $uri_Page -Method Post -Body ($parameter | ConvertTo-Json -Compress) -ContentType 'application/json' -TimeoutSec 600

        if ($pageCount -eq 0) { $names_Page = @($table.Columns | ForEach-Object { $_.Name }) }

        $rows_Page = @($table.Rows)
        foreach ($row in $rows_Page) { $rows.Add($row) }
        $pageCount++

        # Keyset paging: the cursor is the Reference of the last row read, so a short page is the end
        # of the county and there is no count to compare against.
        if (-not $All -or $rows_Page.Count -lt $PageSize) { break }

        $index_Reference = [array]::IndexOf($names_Page, 'Reference')
        if ($index_Reference -lt 0) {
            Write-Warning 'The page carries no Reference column, so it cannot be paged. Reporting the first page only.'
            break
        }

        $cursor = [string] $rows_Page[$rows_Page.Count - 1][$index_Reference]
        if ([string]::IsNullOrWhiteSpace($cursor)) {
            Write-Warning 'The last row read carries no Reference, so paging cannot continue. Reporting what was read.'
            break
        }
    }

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
                Column  = $name
                Count   = $numbers.Count
                # An unmeasured radial ratio is an absent column on that row rather than a zero:
                # Update_RadialRatios adds no column at all when the neighbour set is empty.
                Missing = $rowCount - $numbers.Count
                Zeros   = @($numbers | Where-Object { $_ -eq 0 }).Count
                Min     = $sorted[0]
                Median  = $sorted[[int]($sorted.Count / 2)]
                Max     = $sorted[$sorted.Count - 1]
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
    PageCount       = $pageCount
    Narrowed        = $narrowed
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

        # A narrowed page holds no data for the other columns, so a fill count taken from it would
        # read as a collapse from 172 to the handful asked for.
        $filledFully = $null
        if ($CountyId -gt 0 -and $rowCount -gt 0 -and -not $narrowed) {
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
        if ($CountyId -gt 0) {
            $scope = if ($All) { "read over $rowCount rows in $pageCount pages" } else { "sampled over $rowCount rows" }
            Write-Host "  county $CountyId $scope"
            if ($narrowed) { Write-Host "  narrowed to columns matching '$Column' - fill counts are not reported" -ForegroundColor DarkGray }
        }
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
        if ($CountyId -gt 0) {
            $scope = if ($All) { "read over $rowCount rows in $pageCount pages" } else { "sampled over $rowCount rows" }
            Write-Host "county $CountyId $scope"
        }
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
            $scope = if ($All) { "every one of $rowCount rows, $pageCount pages" } else { "$rowCount sampled rows" }
            Write-Host "value distribution - county $CountyId over $scope" -ForegroundColor Cyan
            Write-Host ''
            foreach ($row in $distributions) {
                $colour = if ($row.Zeros -eq 0 -and $row.Missing -eq 0) { 'Green' } else { 'Yellow' }
                Write-Host ('  {0,-42} n={1,7}  missing={2,7}  zeros={3,7}  min={4,12:G6}  median={5,12:G6}  max={6,12:G6}' -f $row.Column, $row.Count, $row.Missing, $row.Zeros, $row.Min, $row.Median, $row.Max) -ForegroundColor $colour
            }
            Write-Host ''
        }
    }
}

if ($Json) { $result | ConvertTo-Json -Depth 5 }
