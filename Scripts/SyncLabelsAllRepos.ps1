<#
.SYNOPSIS
    Synchronizes the standardized label taxonomy across all DiGi repositories on GitHub.

.DESCRIPTION
    Ensures every DiGi repository has the standard 16 labels across Type, Priority, and Status.
    Renames legacy labels ('bug', 'enhancement', 'documentation') to preserve issue history,
    creates missing standard labels, updates colors/descriptions, and removes obsolete default labels.

.PARAMETER Repo
    Optional single repository name to target (e.g. 'DiGi.Maintenance' or 'DiGi.Core').
    If omitted, all 'DiGi.*' directories in the workspace are processed.

.PARAMETER DryRun
    If specified, displays planned changes without making modifications on GitHub.

.PARAMETER KeepObsolete
    If specified, obsolete default labels (wontfix, invalid, duplicate, etc.) are kept instead of deleted.
#>
param (
    [string]$Repo,
    [switch]$DryRun,
    [switch]$KeepObsolete
)

$ErrorActionPreference = "Stop"

$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path

# Determine GitHub owner from origin URL or fallback
$owner = "ZiolkowskiJakub"
$currentRepoRemote = git config --get remote.origin.url
if ($currentRepoRemote -match 'github\.com[:/]([^/]+)/') {
    $owner = $Matches[1]
}

# Standard 16 labels definition
$standardLabels = @(
    @{ Name = "type: bug";             Color = "d73a4a"; Description = "Confirmed defect or regression in logic, data handling, or output" },
    @{ Name = "type: feature";         Color = "0e8a16"; Description = "Substantial new functionality or public API capability" },
    @{ Name = "type: enhancement";     Color = "a2eeef"; Description = "Improvement, optimization, or refinement of an existing capability" },
    @{ Name = "type: performance";     Color = "1d76db"; Description = "Execution speedup, memory allocation reduction, or query tuning" },
    @{ Name = "type: refactor";        Color = "6f42c1"; Description = "Architectural or structural code cleanup with no behavioral change" },
    @{ Name = "type: breaking-change"; Color = "b60205"; Description = "Breaking API change requiring major/minor version increments" },
    @{ Name = "type: documentation";   Color = "0075ca"; Description = "XML documentation, AI guidelines, or GitHub wiki updates" },
    @{ Name = "type: test";            Color = "fbca04"; Description = "Test facts in DiGi.Test, benchmarks, or test fixtures" },
    @{ Name = "type: maintenance";     Color = "d4c5f9"; Description = "CI/CD, project dependencies, .editorconfig, or build script updates" },
    @{ Name = "priority: critical";    Color = "b60205"; Description = "Blocks deployment, corrupts data, or causes service outage" },
    @{ Name = "priority: high";        Color = "d93f0b"; Description = "Severe bug or major blocker for current release milestone" },
    @{ Name = "priority: medium";      Color = "fb8c00"; Description = "Normal priority; addressed in standard development cycle" },
    @{ Name = "priority: low";         Color = "e0e0e0"; Description = "Minor inconvenience, cosmetic, or low-impact task" },
    @{ Name = "status: in-progress";   Color = "0e8a16"; Description = "Active work is underway" },
    @{ Name = "status: blocked";       Color = "b60205"; Description = "Blocked by upstream dependency or external issue" },
    @{ Name = "status: needs-review";  Color = "fb8c00"; Description = "Implementation ready for verification or code review" }
)

# Renaming map for legacy default labels to preserve existing issue tagging
$legacyRenames = @{
    "bug"           = "type: bug"
    "enhancement"   = "type: enhancement"
    "documentation" = "type: documentation"
}

# Standard obsolete labels to delete
$obsoleteLabels = @("duplicate", "good first issue", "help wanted", "invalid", "question", "wontfix")

# Determine target repositories
$targetDirectories = @()
if ($Repo) {
    $targetPath = Join-Path $baseDir $Repo
    if (-not (Test-Path $targetPath)) {
        Write-Error "Repository path not found: $targetPath"
        exit 1
    }
    $targetDirectories = @(Get-Item -Path $targetPath)
} else {
    $targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*" | Sort-Object Name
}

Write-Host "Syncing labels across $($targetDirectories.Count) repository/repositories (Owner: $owner, DryRun: $DryRun)..." -ForegroundColor Cyan

foreach ($dir in $targetDirectories) {
    $repoName = $dir.Name
    $repoIdentifier = "$owner/$repoName"
    Write-Host "`n=== Repository: $repoIdentifier ===" -ForegroundColor Yellow

    # Fetch existing labels via gh CLI JSON output
    $existingLabelsJson = gh label list --repo $repoIdentifier --json name,color,description 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $existingLabelsJson) {
        Write-Warning "Failed to fetch labels for $repoIdentifier (repository may not exist remotely or authentication issue)."
        continue
    }

    $existingLabels = $existingLabelsJson | ConvertFrom-Json
    $existingByName = @{}
    foreach ($lbl in $existingLabels) {
        $existingByName[$lbl.name] = $lbl
    }

    # 1. Rename legacy labels if the target name does not already exist
    foreach ($legacyName in $legacyRenames.Keys) {
        $targetName = $legacyRenames[$legacyName]
        if ($existingByName.ContainsKey($legacyName)) {
            if (-not $existingByName.ContainsKey($targetName)) {
                $std = $standardLabels | Where-Object { $_.Name -eq $targetName }
                Write-Host "  [RENAME] '$legacyName' -> '$targetName' (Color: #$($std.Color))" -ForegroundColor Cyan
                if (-not $DryRun) {
                    gh label edit $legacyName --name $targetName --color $std.Color --description $std.Description --repo $repoIdentifier
                }
                # Update in-memory tracking
                $existingByName.Remove($legacyName)
                $existingByName[$targetName] = [PSCustomObject]@{ name = $targetName; color = $std.Color; description = $std.Description }
            } else {
                # Target already exists, delete legacy if not kept
                if (-not $KeepObsolete) {
                    Write-Host "  [DELETE LEGACY] '$legacyName' (target '$targetName' already exists)" -ForegroundColor DarkYellow
                    if (-not $DryRun) {
                        gh label delete $legacyName --yes --repo $repoIdentifier
                    }
                    $existingByName.Remove($legacyName)
                }
            }
        }
    }

    # 2. Create or update standard labels
    foreach ($std in $standardLabels) {
        if ($existingByName.ContainsKey($std.Name)) {
            $current = $existingByName[$std.Name]
            $normalizedCurrentColor = $current.color.TrimStart('#').ToLower()
            $normalizedStdColor = $std.Color.TrimStart('#').ToLower()
            $currentDesc = if ($current.description) { $current.description } else { "" }

            if ($normalizedCurrentColor -ne $normalizedStdColor -or $currentDesc -ne $std.Description) {
                Write-Host "  [UPDATE] '$($std.Name)' (Color: #$($std.Color), Desc: '$($std.Description)')" -ForegroundColor DarkCyan
                if (-not $DryRun) {
                    gh label edit $std.Name --color $std.Color --description $std.Description --repo $repoIdentifier
                }
            }
        } else {
            Write-Host "  [CREATE] '$($std.Name)' (Color: #$($std.Color), Desc: '$($std.Description)')" -ForegroundColor Green
            if (-not $DryRun) {
                gh label create $std.Name --color $std.Color --description $std.Description --repo $repoIdentifier
            }
        }
    }

    # 3. Delete obsolete labels
    if (-not $KeepObsolete) {
        foreach ($obs in $obsoleteLabels) {
            if ($existingByName.ContainsKey($obs)) {
                Write-Host "  [DELETE OBSOLETE] '$obs'" -ForegroundColor Red
                if (-not $DryRun) {
                    gh label delete $obs --yes --repo $repoIdentifier
                }
            }
        }
    }
}

Write-Host "`nLabel synchronization completed!" -ForegroundColor Green
