# Get the dynamic base directory relative to this script
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path

# Read and parse SOFTWARE_DIRECTORY from config file if available
$confPath = Join-Path $PSScriptRoot "..\user files\Directories.conf"
$softwareDir = ""

if (Test-Path $confPath) {
    foreach ($line in Get-Content $confPath) {
        $line = $line.Trim()
        if ($line.StartsWith("#") -or $line -eq "") { continue }
        $index = $line.IndexOf("=")
        if ($index -ge 0) {
            $key = $line.Substring(0, $index).Trim()
            $val = $line.Substring($index + 1).Trim()
            if ($val.StartsWith('"') -and $val.EndsWith('"')) {
                $val = $val.Substring(1, $val.Length - 2)
            }
            if ($key -eq "SOFTWARE_DIRECTORY") {
                $softwareDir = $val
            }
        }
    }
} else {
    Write-Warning "Configuration file was not found at: '$confPath'"
    Write-Warning "To enable Software sync, copy 'Directories.conf' to that location and set SOFTWARE_DIRECTORY."
}

# Define local synchronizations (always run, independent of Software output directory)
$SyncList = @(
    @{ Source = "$baseDir\DiGi.User.WebAPI\bin";                     Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\user" },
    @{ Source = "$baseDir\DiGi.GIS.WebAPI\bin";                      Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\gis" },
    @{ Source = "$baseDir\DiGi.GLTF.WebAPI\bin";                     Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\gltf" },
    @{ Source = "$baseDir\DiGi.Communication.WebAPI\bin";            Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\communication" }
)

# Append Software synchronizations if Software directory was successfully parsed
if (-not [string]::IsNullOrWhiteSpace($softwareDir)) {
    $SyncList += @(
        @{ Source = "$baseDir\DiGi.GIS.PostgreSQL.UI\bin";           Destination = "$softwareDir\DiGi.GIS.PostgreSQL.UI" },
        @{ Source = "$baseDir\DiGi.GIS.UI\bin";                      Destination = "$softwareDir\DiGi.GIS.UI" },
        @{ Source = "$baseDir\DiGi.GIS.WebAPI.UI\bin";               Destination = "$softwareDir\DiGi.GIS.WebAPI.UI" },
        @{ Source = "$baseDir\DiGi.WebAPI.WindowsService\bin";       Destination = "$softwareDir\DiGi.WebAPI.WindowsService" }
    )
} else {
    Write-Warning "SOFTWARE_DIRECTORY is not set. Software synchronization will be skipped."
}

Write-Host "Starting batch synchronization process..." -ForegroundColor Cyan
Write-Host "==========================================="

# Get the absolute path to the helper script in the same directory
$HelperScript = Join-Path -Path $PSScriptRoot -ChildPath "SyncDirectory.ps1"

# Check if the helper script actually exists before starting the loop
if (-not (Test-Path $HelperScript)) {
    Write-Error "Critical Error: '$HelperScript' not found! Make sure both scripts are in the same folder."
    exit
}

foreach ($Pair in $SyncList) {
    Write-Host "Processing: $($Pair.Source) -> $($Pair.Destination)" -ForegroundColor White
    
    # Execute the sync script using the call operator (&) and the full path
    & $HelperScript -Source $Pair.Source -Destination $Pair.Destination
    
    Write-Host "-------------------------------------------"
}

Write-Host "All tasks completed." -ForegroundColor Yellow