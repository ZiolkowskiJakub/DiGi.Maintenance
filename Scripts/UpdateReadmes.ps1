<#
.SYNOPSIS
    Synchronizes the shared "Coding Guidelines for Developers & AI Agents" block in the README.md of every DiGi repository.

.DESCRIPTION
    1. Reads the canonical guidelines block from 'files/README - Coding Guidelines.md'.
    2. For each 'DiGi.*' repository under the workspace root, replaces everything from the block marker heading
       to the end of README.md with the canonical block, preserving the repository-specific content above it.
    3. If a README.md does not contain the marker, the block is appended.
    4. Commits the change in every repository that has a .git directory, unless -NoCommit is specified.

    The block is written as UTF-8 without BOM using CRLF line endings, matching the existing README files.

.PARAMETER NoCommit
    If specified, files are updated but no git commit is created.

.PARAMETER Message
    Commit message used when committing updated README files.
#>
param (
    [switch]$NoCommit,

    [string]$Message = "Sync README coding guidelines with latest AI Guidelines"
)

$ErrorActionPreference = "Stop"

# Workspace root, resolved relative to this script
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
Write-Host "Base directory resolved to: $baseDir" -ForegroundColor Cyan

$templatePath = Join-Path $PSScriptRoot "..\files\README - Coding Guidelines.md"
if (-not (Test-Path $templatePath)) {
    Write-Error "Guidelines template was not found at: '$templatePath'"
    exit 1
}

# Marker heading that starts the generated block; everything from here to the end of the file is replaced
$marker = "## " + [char]0xD83D + [char]0xDCBB + " Coding Guidelines for Developers & AI Agents"

$templateText = [System.IO.File]::ReadAllText($templatePath)
# Strip every CR (a CRLF -> LF step would leave a stray '\r' from '\r\r\n' behind).
$templateText = $templateText -replace "`r", ""
$templateText = $templateText.TrimEnd("`n")

if (-not $templateText.StartsWith($marker)) {
    Write-Error "Guidelines template does not start with the expected marker heading: '$marker'"
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$updatedCount = 0

$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

foreach ($dir in $targetDirectories) {
    $dirName = $dir.Name
    $readmePath = Join-Path $dir.FullName "README.md"

    if (-not (Test-Path $readmePath)) {
        Write-Host "Skipping (no README.md): $dirName" -ForegroundColor DarkGray
        continue
    }

    $readmeText = [System.IO.File]::ReadAllText($readmePath)
    $normalizedText = $readmeText -replace "`r", ""

    $index = $normalizedText.IndexOf($marker)
    if ($index -ge 0) {
        $headText = $normalizedText.Substring(0, $index).TrimEnd("`n")
    } else {
        Write-Host "    Marker not found, appending block: $dirName" -ForegroundColor Yellow
        $headText = $normalizedText.TrimEnd("`n")
    }

    $newText = $headText + "`n`n" + $templateText + "`n"
    $newText = $newText -replace "`n", "`r`n"

    if ($newText -eq $readmeText) {
        Write-Host "No changes in README.md for: $dirName" -ForegroundColor Gray
        continue
    }

    [System.IO.File]::WriteAllText($readmePath, $newText, $utf8NoBom)
    $updatedCount++
    Write-Host "Updated README.md in: $dirName" -ForegroundColor Cyan

    if ($NoCommit) {
        continue
    }

    $gitDir = Join-Path $dir.FullName ".git"
    if (-not (Test-Path $gitDir)) {
        continue
    }

    Push-Location $dir.FullName
    $status = git status --porcelain README.md
    if ($status) {
        Write-Host "    Committing updated README.md in: $dirName" -ForegroundColor Cyan
        # '-c core.autocrlf=false' keeps the CRLF bytes in the committed blob (repo convention)
        # and avoids a whole-file line-ending diff when the machine has core.autocrlf=true.
        git -c core.autocrlf=false add README.md
        git commit -m $Message | Out-Null
    }
    Pop-Location
}

Write-Host "`nREADME synchronization complete. Updated repositories: $updatedCount" -ForegroundColor Green
