<#
.SYNOPSIS
    Finds "user files" directories in all DiGi solutions/repositories and copies them to/from the target backup data directory.

.DESCRIPTION
    1. Reads target backup directory from parameter or 'user files/Directories.conf'.
    2. By default, searches for "user files" folders across all DiGi repositories under the workspace root and copies them to the backup directory.
    3. If -Reverse (or -Restore) is specified, copies "user files" from the backup directory back into matching workspace repositories.

.PARAMETER Destination
    Target root directory where user files folders will be copied or restored from.

.PARAMETER Reverse
    If specified, restores "user files" from the backup directory back to matching repositories in the workspace.
#>
param (
    [string]$Destination = "",

    [Alias("Restore")]
    [switch]$Reverse
)

# Dynamic base directory relative to this script (workspace root)
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path

# Read and parse USER_FILES_BACKUP_DIRECTORY from config file if available
$confPath = Join-Path $PSScriptRoot "..\user files\Directories.conf"
$targetDir = ""

if (-not (Test-Path $confPath)) {
    Write-Error "Configuration file was not found at: '$confPath'"
    Write-Error "To enable user files copy, copy 'Directories.conf' from 'files' directory to 'user files' directory and set USER_FILES_BACKUP_DIRECTORY."
    exit 1
}

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
        if ($key -eq "USER_FILES_BACKUP_DIRECTORY") {
            $targetDir = $val
        }
    }
}

# Parameter takes precedence over config file
if (-not [string]::IsNullOrWhiteSpace($Destination)) {
    $targetDir = $Destination
}

if ([string]::IsNullOrWhiteSpace($targetDir)) {
    Write-Error "USER_FILES_BACKUP_DIRECTORY is not set or empty in '$confPath' and no -Destination parameter was provided."
    exit 1
}

if ($Reverse) {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "Restoring 'user files' directories from backup to workspace" -ForegroundColor Cyan
    Write-Host "Backup Directory: $targetDir" -ForegroundColor Yellow
    Write-Host "Workspace Root:   $baseDir" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Cyan

    if (-not (Test-Path $targetDir)) {
        Write-Error "Backup directory does not exist: '$targetDir'"
        exit 1
    }

    $userFilesDirs = Get-ChildItem -Path $targetDir -Directory -Filter "user files" -Recurse

    if ($null -eq $userFilesDirs -or $userFilesDirs.Count -eq 0) {
        Write-Host "No 'user files' directories found in backup directory." -ForegroundColor Yellow
        exit
    }

    $copiedCount = 0

    foreach ($userDir in $userFilesDirs) {
        $srcPath = $userDir.FullName
        $relPath = $srcPath.Substring($targetDir.Length).TrimStart('\', '/')
        $destPath = Join-Path $baseDir $relPath

        Write-Host "Restoring: $srcPath" -ForegroundColor White
        Write-Host "       --> $destPath" -ForegroundColor Gray

        try {
            if (-not (Test-Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath -Force | Out-Null
            }

            $items = Get-ChildItem -Path $srcPath
            if ($items.Count -gt 0) {
                Copy-Item -Path "$srcPath\*" -Destination $destPath -Recurse -Force -ErrorAction Stop
                Write-Host "[SUCCESS] Restored $($items.Count) item(s) to $destPath" -ForegroundColor Green
            } else {
                Write-Host "[SUCCESS] Destination directory created (backup 'user files' is empty)" -ForegroundColor Yellow
            }
            $copiedCount++
        } catch {
            Write-Error "Failed to restore '$srcPath' to '$destPath': $_"
        }

        Write-Host "--------------------------------------------------" -ForegroundColor Gray
    }

    Write-Host "Completed! Successfully restored $copiedCount 'user files' directory/directories." -ForegroundColor Green
} else {
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
}
