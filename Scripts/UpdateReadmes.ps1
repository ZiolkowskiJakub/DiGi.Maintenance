<#
.SYNOPSIS
    Synchronizes the shared "Coding Guidelines for Developers & AI Agents" block in the README.md of every DiGi repository.

.DESCRIPTION
    1. Reads the canonical guidelines block from 'files/README - Coding Guidelines.md'.
    2. For each 'DiGi.*' repository under the workspace root, replaces everything from the block marker heading
       to the end of README.md with the canonical block, preserving the repository-specific content above it.
    3. If a README.md does not contain the marker, the block is appended.
    4. Commits the change in every repository that has a .git directory, unless -NoCommit is specified.

    The block is written as UTF-8 without BOM, preserving each repository's stored line-ending
    convention (LF in every DiGi repository). The convention is read from the committed blob, so a
    fresh clone under core.autocrlf=true cannot flip a stored-LF README to CRLF.

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

# Returns 'CRLF' if the repository stores <RelativePath> with CRLF in its committed blob, else 'LF'.
# Defaults to 'LF' (the DiGi repository convention) when the file is untracked or the repo has no HEAD.
# The committed blob is authoritative for the stored convention: under core.autocrlf=true a fresh
# checkout materialises an LF blob as a CRLF working tree, so the working tree alone cannot reveal
# what the repository actually stores.
function Get-RepoLineEnding {
    param (
        [string]$RepoPath,
        [string]$RelativePath
    )

    if (-not (Test-Path (Join-Path $RepoPath ".git"))) { return "LF" }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.WorkingDirectory = $RepoPath
    $psi.FileName = "git"
    $psi.Arguments = "cat-file -p HEAD:$RelativePath"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        if (-not $process.Start()) { return "LF" }

        $memoryStream = New-Object System.IO.MemoryStream
        $buffer = New-Object byte[] 16384
        $stdoutStream = $process.StandardOutput.BaseStream
        $read = 0
        while (($read = $stdoutStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            [void]$memoryStream.Write($buffer, 0, $read)
        }
        [void]$process.StandardError.ReadToEnd()
        [void]$process.WaitForExit()

        if ($process.ExitCode -ne 0) { return "LF" }

        $bytes = $memoryStream.ToArray()
        for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
            if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) { return "CRLF" }
        }
        return "LF"
    }
    catch {
        # A git/IO failure (missing git, corrupt .git) must not abort a 66-repo run; fall back to the
        # safe LF convention and surface it so a real problem is visible rather than silent.
        Write-Host "    WARNING: could not detect the stored line ending for '$(Split-Path $RepoPath -Leaf)' - defaulting to LF" -ForegroundColor Yellow
        return "LF"
    }
    finally {
        $process.Dispose()
    }
}

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
    # Emit in the convention the repository actually stores (detected from the committed blob above);
    # LF in every DiGi repository. Previously this was hard-coded to CRLF, which forced a CRLF blob
    # over a stored-LF README and rewrote every line on each run (see issue #11).
    $lineEnding = Get-RepoLineEnding -RepoPath $dir.FullName -RelativePath "README.md"
    if ($lineEnding -eq "CRLF") {
        $newText = $newText -replace "`n", "`r`n"
    }

    # Guard: never emit a line ending that differs from the committed blob we are replacing. This is
    # the tripwire that would have caught the whole-repo CRLF flip before it produced 66 bad commits.
    if ($newText.Contains("`r`n") -ne ($lineEnding -eq "CRLF")) {
        Write-Host "    WARNING: generated line ending does not match the stored blob ($lineEnding) - skipping to avoid a whole-file rewrite: $dirName" -ForegroundColor Red
        continue
    }

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
        # '-c core.autocrlf=false' commits the working-tree bytes verbatim, so the LF we wrote (the
        # stored convention) reaches the blob instead of a machine with core.autocrlf=true converting it.
        git -c core.autocrlf=false add README.md
        git commit -m $Message | Out-Null
    }
    Pop-Location
}

Write-Host "`nREADME synchronization complete. Updated repositories: $updatedCount" -ForegroundColor Green
