<#
.SYNOPSIS
    Builds every solution, then batch synchronizes output binary directories across web services and the configured software directory.

.DESCRIPTION
    0. Builds every solution with BuildAll.ps1, unless -SkipBuild is set. A failed build stops the script before any
       directory is synchronized.
    1. Synchronizes local WebAPI bin directories into DiGi.WebAPI.WindowsService extensions.
    2. Synchronizes UI and WindowsService bin directories to the target SOFTWARE_DIRECTORY configured in 'user files/Directories.conf'.
    3. Optionally removes 'logs' directories and log files from all directories copied to the software directory.

    The Year Built prediction runner is opt-in. Set INCLUDE_YEAR_BUILT_PREDICTION_EXTENSION=true in
    'user files/Directories.conf' on a machine that deploys to an ML-capable host, and DiGi.GIS.YOLO.UI's
    output is assembled into DiGi.GIS.PostgreSQL.UI\bin\extensions\DiGi.GIS.YOLO.UI.ConsoleApp before the
    software sync carries it there - the same way the WebAPI extensions reach DiGi.WebAPI.WindowsService.
    Only the runner, its runtimes and satellite folders, and the detector YOLO\models\model.pt are assembled;
    scratch, logs, reports and training inputs stay behind (training data belongs outside the workspace).
    Left unset, that folder is removed and no host receives the models the runner needs.

.PARAMETER Configuration
    Build configuration passed to BuildAll.ps1.

.PARAMETER VsMsbuildPath
    MSBuild.exe passed to BuildAll.ps1. Detected with vswhere when empty.

.PARAMETER SkipBuild
    Deploys the bin folders as last built.

.PARAMETER RemoveLogs
    If true (default), removes 'logs' directories and *.log files from directories copied to the software directory after synchronization.
#>
param (
    [string]$Configuration = "Release",
    [string]$VsMsbuildPath = "",
    [switch]$SkipBuild,                      # Deploy the bin folders as last built
    $RemoveLogs = $true
)

if ($RemoveLogs -is [string]) {
    $RemoveLogs = [System.Convert]::ToBoolean($RemoveLogs)
} else {
    $RemoveLogs = [bool]$RemoveLogs
}

# Get the dynamic base directory relative to this script
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path

# --- Build ---
# CheckDependencies is not passed on purpose: BuildAll.ps1 would audit the host before the WebAPI extensions are
# synchronized into its bin\extensions folders below, i.e. a stale probing set.
if (-not $SkipBuild) {
    $buildScript = Join-Path $PSScriptRoot "BuildAll.ps1"
    if (-not (Test-Path $buildScript)) {
        Write-Host "'$buildScript' not found." -ForegroundColor Red
        exit 1
    }

    & $buildScript -Root $baseDir -Configuration $Configuration -VsMsbuildPath $VsMsbuildPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Synchronization skipped." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# Read and parse SOFTWARE_DIRECTORY from config file if available
$confPath = Join-Path $PSScriptRoot "..\user files\Directories.conf"
$softwareDir = ""
$includeYearBuiltPredictionExtension = $false

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
            if ($key -eq "INCLUDE_YEAR_BUILT_PREDICTION_EXTENSION") {
                # Anything but an explicit true leaves the runner out. A value nobody can read must not mean
                # "ship the models to a database host that will never score anything".
                $includeYearBuiltPredictionExtension = ($val -match '^(?i:true|1|yes)$')
            }
        }
    }
} else {
    Write-Warning "Configuration file was not found at: '$confPath'"
    Write-Warning "To enable Software sync, copy 'Directories.conf' to that location and set SOFTWARE_DIRECTORY."
}

# Define local synchronizations (always run, independent of Software output directory)
$SyncList = @(
    @{ Source = "$baseDir\DiGi.User.WebAPI\bin";                     Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\user";          IsSoftware = $false },
    @{ Source = "$baseDir\DiGi.GIS.WebAPI\bin";                      Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\gis";           IsSoftware = $false },
    @{ Source = "$baseDir\DiGi.GLTF.WebAPI\bin";                     Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\gltf";          IsSoftware = $false },
    @{ Source = "$baseDir\DiGi.Communication.WebAPI\bin";            Destination = "$baseDir\DiGi.WebAPI.WindowsService\bin\extensions\communication"; IsSoftware = $false }
)

# The Year Built prediction runner, opt-in per machine.
#
# A LOCAL synchronization on purpose, so the extension is assembled inside DiGi.GIS.PostgreSQL.UI's own
# bin BEFORE the software block below copies that bin to the host - the extension then travels as part of
# the tray application rather than as a destination of its own. Making it a software destination instead
# would put it underneath one: SyncDirectory.ps1 clears each destination's top level, so the tray
# application's own sync would delete the extensions folder, and the ordering of $SyncList would silently
# become load-bearing.
#
# The runner's bin is assembled from an ALLOWLIST, because it is also where run and training artifacts land:
# the exported imagery in 'scratch' reached 14 GB, and once 'scratch' was excluded by name a labelling run's
# 'scratch_train9' (235 042 files, 3.4 GB) went to the host instead. A top-level directory is copied only when
# it is 'runtimes' or a satellite resource folder, so the next scratch folder is left behind whatever it is
# called. Of 'YOLO' only the detector the runner predicts with is copied - earlier detectors, ONNX exports and
# the pretrained base weights are training inputs, kept outside the workspace (D:\YOLO on the training
# machine). Training inputs that CopyUserFiles flattens into the output root are excluded by name.
$yearBuiltPredictionSourceDir = "$baseDir\DiGi.GIS.YOLO.UI\bin"
$yearBuiltPredictionExtensionDir = "$baseDir\DiGi.GIS.PostgreSQL.UI\bin\extensions\DiGi.GIS.YOLO.UI.ConsoleApp"
$yearBuiltPredictionModelPath = "YOLO\models\model.pt"
$yearBuiltPredictionExcludeFile = @("Data_*.tsv", "YOLOTraining*Options*.json", "*.hold", "*.log")

# The extension is about 250 MB in some 200 files. Anything well past that is a run or training artifact the
# allowlist did not anticipate - for instance a runtime package that ships native libraries nobody loads.
$yearBuiltPredictionMaxFileCount = 1000
$yearBuiltPredictionMaxMB = 1024

function Test-DeployableDirectory([System.IO.DirectoryInfo]$Directory) {
    if ($Directory.Name -eq "runtimes") {
        return $true
    }

    # A satellite resource folder (cs, de, pt-BR, zh-Hans, ...): no subfolders, nothing but *.resources.dll.
    # Checked one level deep only, so a scratch folder of 200 000 files costs one listing, not a full walk.
    if (Get-ChildItem -Path $Directory.FullName -Directory -Force | Select-Object -First 1) {
        return $false
    }

    $files = @(Get-ChildItem -Path $Directory.FullName -File -Force)
    return ($files.Count -gt 0) -and -not ($files | Where-Object { $_.Name -notlike "*.resources.dll" })
}

if ($includeYearBuiltPredictionExtension -and (Test-Path $yearBuiltPredictionSourceDir)) {
    $directories_Deployable = @()
    $directories_Skipped = @()
    foreach ($directory in Get-ChildItem -Path $yearBuiltPredictionSourceDir -Directory -Force) {
        if (Test-DeployableDirectory $directory) {
            $directories_Deployable += $directory
        } else {
            $directories_Skipped += $directory.Name
        }
    }

    $files_Deployable = @(Get-ChildItem -Path $yearBuiltPredictionSourceDir -File -Force | Where-Object { $name = $_.Name; -not ($yearBuiltPredictionExcludeFile | Where-Object { $name -like $_ }) })
    foreach ($directory in $directories_Deployable) {
        $files_Deployable += @(Get-ChildItem -Path $directory.FullName -File -Recurse -Force)
    }

    $path_Model = Join-Path $yearBuiltPredictionSourceDir $yearBuiltPredictionModelPath
    if (Test-Path $path_Model) {
        $files_Deployable += Get-Item $path_Model
    } else {
        Write-Warning "'$path_Model' not found - the host would receive a runner with no detector. Put the shipped weights in DiGi.GIS.YOLO.UI\user files\$yearBuiltPredictionModelPath and rebuild."
    }

    $fileCount = $files_Deployable.Count
    $sizeMB = [math]::Round(($files_Deployable | Measure-Object -Property Length -Sum).Sum / 1MB)
    Write-Host "Year Built prediction extension: $fileCount file(s), $sizeMB MB. Not deployed: $(if ($directories_Skipped) { $directories_Skipped -join ', ' } else { '(none)' })" -ForegroundColor Cyan

    if ($fileCount -gt $yearBuiltPredictionMaxFileCount -or $sizeMB -gt $yearBuiltPredictionMaxMB) {
        Write-Warning "The Year Built prediction extension is $fileCount file(s) / $sizeMB MB, above the expected $yearBuiltPredictionMaxFileCount file(s) / $yearBuiltPredictionMaxMB MB. Largest directories:"
        $directories_Deployable | ForEach-Object {
            $files = @(Get-ChildItem -Path $_.FullName -File -Recurse -Force)
            [pscustomobject]@{ Directory = $_.Name; Files = $files.Count; MB = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB) }
        } | Sort-Object MB -Descending | Select-Object -First 5 | Format-Table -AutoSize | Out-Host
    }

    $SyncList += @(
        @{ Source = $yearBuiltPredictionSourceDir; Destination = $yearBuiltPredictionExtensionDir; IsSoftware = $false; ExcludeDirectory = @($directories_Skipped); ExcludeFile = $yearBuiltPredictionExcludeFile; IncludePath = @($yearBuiltPredictionModelPath) }
    )
} elseif ($includeYearBuiltPredictionExtension) {
    Write-Warning "INCLUDE_YEAR_BUILT_PREDICTION_EXTENSION is set but '$yearBuiltPredictionSourceDir' does not exist - the extension is not assembled."
} elseif (Test-Path $yearBuiltPredictionExtensionDir) {
    # Left behind by an earlier run with the flag on. Without this it keeps riding along inside the tray
    # application's bin, and turning the flag off would deploy exactly what it was turned off to avoid.
    Write-Host "INCLUDE_YEAR_BUILT_PREDICTION_EXTENSION is not set - removing $yearBuiltPredictionExtensionDir..." -ForegroundColor Cyan
    try {
        Remove-Item -Path $yearBuiltPredictionExtensionDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Warning "Could not remove '$yearBuiltPredictionExtensionDir': $_"
    }
}

# Append Software synchronizations if Software directory was successfully parsed
if (-not [string]::IsNullOrWhiteSpace($softwareDir)) {
    $SyncList += @(
        @{ Source = "$baseDir\DiGi.GIS.PostgreSQL.UI\bin";           Destination = "$softwareDir\DiGi.GIS.PostgreSQL.UI";   IsSoftware = $true },
        @{ Source = "$baseDir\DiGi.GIS.UI\bin";                      Destination = "$softwareDir\DiGi.GIS.UI";              IsSoftware = $true },
        @{ Source = "$baseDir\DiGi.GIS.WebAPI.UI\bin";               Destination = "$softwareDir\DiGi.GIS.WebAPI.UI";       IsSoftware = $true },
        @{ Source = "$baseDir\DiGi.WebAPI.WindowsService\bin";       Destination = "$softwareDir\DiGi.WebAPI.WindowsService"; IsSoftware = $true }
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
    $excludeDirectory = if ($Pair.ContainsKey("ExcludeDirectory")) { $Pair.ExcludeDirectory } else { @() }
    $excludeFile = if ($Pair.ContainsKey("ExcludeFile")) { $Pair.ExcludeFile } else { @() }
    & $HelperScript -Source $Pair.Source -Destination $Pair.Destination -ExcludeDirectory $excludeDirectory -ExcludeFile $excludeFile

    # Single files copied from inside a directory the sync excluded, at the same relative path.
    if ($Pair.ContainsKey("IncludePath")) {
        foreach ($includePath in $Pair.IncludePath) {
            $path_Source = Join-Path $Pair.Source $includePath
            if (-not (Test-Path $path_Source)) {
                Write-Warning "'$path_Source' not found - not copied."
                continue
            }

            $path_Destination = Join-Path $Pair.Destination $includePath
            New-Item -ItemType Directory -Path (Split-Path $path_Destination -Parent) -Force | Out-Null
            Copy-Item -Path $path_Source -Destination $path_Destination -Force
            Write-Host "Copied $includePath." -ForegroundColor Green
        }
    }

    if ($RemoveLogs -and $Pair.IsSoftware) {
        if (Test-Path $Pair.Destination) {
            $logsDir = Join-Path $Pair.Destination "logs"
            if (Test-Path $logsDir) {
                Write-Host "Removing logs directory: $logsDir..." -ForegroundColor Cyan
                try {
                    Remove-Item -Path $logsDir -Recurse -Force -ErrorAction Stop
                    Write-Host "Successfully removed logs directory." -ForegroundColor Green
                } catch {
                    Write-Warning "Could not remove logs directory '$logsDir': $_"
                }
            }

            $logFiles = Get-ChildItem -Path $Pair.Destination -Filter "*.log" -File -ErrorAction SilentlyContinue
            if ($logFiles) {
                foreach ($logFile in $logFiles) {
                    Write-Host "Removing log file: $($logFile.FullName)..." -ForegroundColor Cyan
                    try {
                        Remove-Item -Path $logFile.FullName -Force -ErrorAction Stop
                    } catch {
                        Write-Warning "Could not remove log file '$($logFile.FullName)': $_"
                    }
                }
            }
        }
    }
    
    Write-Host "-------------------------------------------"
}

Write-Host "All tasks completed." -ForegroundColor Yellow