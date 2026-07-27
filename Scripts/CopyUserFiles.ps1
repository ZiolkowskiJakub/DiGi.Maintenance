<#
.SYNOPSIS
    Finds "user files" directories in all DiGi solutions/repositories and copies them to the target destination data directory.

.DESCRIPTION
    1. Reads target directory from parameter or 'user files/Copy_User_Files.conf' (defaulting to 'D:\Nextcloud\Work\DigiProject\DiGi\Data').
    2. Searches for "user files" folders across all DiGi repositories under the workspace root.
    3. Copies each "user files" directory to destination maintaining repository structure:
       e.g. '<Workspace>\DiGi.GIS.PostgreSQL\user files' -> '<Destination>\DiGi.GIS.PostgreSQL\user files'.

.PARAMETER Destination
    Target root directory where user files folders will be copied.
#>
param (
    [string]$Destination = ""
)

# Dynamic base directory relative to this script (workspace root)
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path

# Read and parse TARGET_DIRECTORY from config file if available
$confPath = Join-Path $PSScriptRoot "..\user files\Copy_User_Files.conf"
$targetDir = ""

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
            if ($key -eq "TARGET_DIRECTORY" -or $key -eq "DATA_DIRECTORY") {
                $targetDir = $val
            }
        }
    }
}

# Parameter takes precedence over config file; fallback to default if neither is set
if (-not [string]::IsNullOrWhiteSpace($Destination)) {
    $targetDir = $Destination
} elseif ([string]::IsNullOrWhiteSpace($targetDir)) {
    $targetDir = "D:\Nextcloud\Work\DigiProject\DiGi\Data"
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Copying 'user files' directories across DiGi solutions" -ForegroundColor Cyan
Write-Host "Target Directory: $targetDir" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan

if (-not (Test-Path $targetDir)) {
    Write-Host "Destination directory does not exist. Creating: $targetDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Find all "user files" directories in DiGi repos/solutions
$userFilesDirs = Get-ChildItem -Path $baseDir -Directory -Filter "user files" -Recurse | Where-Object {
    # Exclude target directory itself if inside baseDir to avoid infinite loop
    -not $_.FullName.StartsWith($targetDir, [System.StringComparison]::OrdinalIgnoreCase)
}

if ($null -eq $userFilesDirs -or $userFilesDirs.Count -eq 0) {
    Write-Host "No 'user files' directories found." -ForegroundColor Yellow
    exit
}

$copiedCount = 0

foreach ($userDir in $userFilesDirs) {
    $srcPath = $userDir.FullName
    if ($srcPath.StartsWith($baseDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relPath = $srcPath.Substring($baseDir.Length).TrimStart('\', '/')
    } else {
        $relPath = Split-Path -Path $srcPath -Leaf
    }
    $destPath = Join-Path $targetDir $relPath
    
    Write-Host "Processing: $srcPath" -ForegroundColor White
    Write-Host "        --> $destPath" -ForegroundColor Gray

    try {
        if (-not (Test-Path $destPath)) {
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        }

        $items = Get-ChildItem -Path $srcPath
        if ($items.Count -gt 0) {
            Copy-Item -Path "$srcPath\*" -Destination $destPath -Recurse -Force -ErrorAction Stop
            Write-Host "[SUCCESS] Copied $($items.Count) item(s) to $destPath" -ForegroundColor Green
        } else {
            Write-Host "[SUCCESS] Target directory created (source 'user files' is empty)" -ForegroundColor Yellow
        }
        $copiedCount++
    } catch {
        Write-Error "Failed to copy '$srcPath' to '$destPath': $_"
    }
    
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
}

Write-Host "Completed! Successfully processed $copiedCount 'user files' directory/directories." -ForegroundColor Green
