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
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$Source,

    [Parameter(Mandatory=$true)]
    [string]$Destination
)

# Check if source directory exists
if (-not (Test-Path -Path $Source)) {
    Write-Error "Source folder '$Source' does not exist! Aborting operation."
    exit
}

# Ensure destination directory exists and clear its content
if (Test-Path -Path $Destination) {
    Write-Host "Cleaning destination folder: $Destination..." -ForegroundColor Cyan
    # Remove all items inside destination without removing the root folder itself
    Get-ChildItem -Path $Destination | Remove-Item -Recurse -Force
} else {
    Write-Host "Destination does not exist. Creating directory: $Destination" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Perform recursive copy from source to destination
Write-Host "Copying files from $Source to $Destination..." -ForegroundColor Green
try {
    # Use \* to copy the content of the folder, not the folder itself
    Copy-Item -Path "$Source\*" -Destination $Destination -Recurse -Force -ErrorAction Stop
    Write-Host "Success: Synchronization complete." -ForegroundColor Green
}
catch {
    Write-Error "Failed to copy files. Error: $_"
}