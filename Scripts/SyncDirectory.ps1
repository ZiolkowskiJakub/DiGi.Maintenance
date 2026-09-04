<#
.SYNOPSIS
    Synchronizes two folders by clearing the destination and copying source content.

.DESCRIPTION
    1. Validates if the source path exists.
    2. Recursively removes all files and folders from the destination path.
    3. Recursively copies all content from source to destination.

.PARAMETER Source
    Path to the source folder.

.PARAMETER Destination
    Path to the destination folder.

.PARAMETER ExcludeDirectory
    Top-level directory names in the source that are not copied. Run artifacts live inside a build
    output without being part of the deployment - a runner's 'scratch' folder of exported imagery
    reached 14 GB and was copied to every host - and excluding them here avoids copying what the
    caller would only delete again afterwards.
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$Source,

    [Parameter(Mandatory=$true)]
    [string]$Destination,

    [string[]]$ExcludeDirectory = @()
)

# Check if source directory exists
if (-not (Test-Path -Path $Source)) {
    Write-Error "Source folder '$Source' does not exist! Aborting operation."
    exit
}

# Ensure destination directory exists and clear its content
if (Test-Path -Path $Destination) {
    Write-Host "Cleaning destination folder: $Destination..." -ForegroundColor Cyan
    try {
        # Remove all items inside destination without removing the root folder itself.
        # Top-level *.conf files are preserved: they hold machine-specific settings and secrets
        # (e.g. WebAPI_Diagnostics.conf) that belong to the target machine, not to the build output.
        # A conf the source also carries is still overwritten by the copy below, so this only
        # protects configuration that exists ONLY on the target - previously wiped every deployment.
        Get-ChildItem -Path $Destination -Exclude "*.conf" | Remove-Item -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not completely clean destination folder. Some files may be locked or in use. Error: $_"
    }
} else {
    Write-Host "Destination does not exist. Creating directory: $Destination" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Perform recursive copy from source to destination
Write-Host "Copying files from $Source to $Destination..." -ForegroundColor Green
try {
    # The source's top-level entries rather than the folder itself, so the content lands directly in
    # the destination. -Force lists hidden entries too, matching what "$Source\*" used to copy.
    $sourceItems = Get-ChildItem -Path $Source -Force | Where-Object { -not ($_.PSIsContainer -and $ExcludeDirectory -contains $_.Name) }

    if (-not $sourceItems) {
        Write-Host "Success: Synchronization complete (nothing to copy)." -ForegroundColor Yellow
        return
    }

    $copiedItems = $sourceItems | Copy-Item -Destination $Destination -Recurse -Force -PassThru -ErrorAction Stop
    if ($copiedItems) {
        $files = $copiedItems | Where-Object { -not $_.PSIsContainer }
        if ($files) {
            Write-Host "Success: Synchronization complete. Copied $($files.Count) file(s)." -ForegroundColor Green
        } else {
            Write-Host "Success: Synchronization complete (no files found to copy)." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Success: Synchronization complete (no items copied)." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to copy files. Error: $_"
}