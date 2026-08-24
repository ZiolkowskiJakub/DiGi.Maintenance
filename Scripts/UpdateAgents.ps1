<#
.SYNOPSIS
    Regenerates the '.agents' rules and skills of every DiGi repository from the canonical AI Guidelines.

.DESCRIPTION
    1. Copies 'DiGi.Maintenance/.agents/AGENTS.md' (the reference rules file) into every 'DiGi.*' repository.
    2. Turns every guideline in 'DiGi.Maintenance/documentation/AI Guidelines' (except README.md) into a
       '.agents/skills/<skill-name>/SKILL.md' with YAML frontmatter.
    3. Optionally refreshes an external, machine-global AGENTS.md whose path is configured as
       GLOBAL_AGENTS_FILE in 'user files/Directories.conf'. Everything up to and including the
       '## Summary of Core Coding & Testing Guidelines' heading is preserved; the compiled guidelines follow.
    4. Commits the change in every repository that has a .git directory, unless -NoCommit is specified.

    All generated files are written as UTF-8 without BOM using CRLF line endings.

.PARAMETER NoCommit
    If specified, files are updated but no git commit is created.

.PARAMETER Message
    Commit message used when committing updated '.agents' folders.
#>
param (
    [switch]$NoCommit,

    [string]$Message = "Sync rules and skills (.agents) with latest AI Guidelines"
)

$ErrorActionPreference = "Stop"

# Workspace root, resolved relative to this script
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
Write-Host "Base directory resolved to: $baseDir" -ForegroundColor Cyan

$guidelinesDir = Join-Path $baseDir "DiGi.Maintenance\documentation\AI Guidelines"
$referenceAgentsFile = Join-Path $baseDir "DiGi.Maintenance\.agents\AGENTS.md"

if (-not (Test-Path $guidelinesDir)) {
    Write-Error "AI Guidelines directory not found: $guidelinesDir"
    exit 1
}

if (-not (Test-Path $referenceAgentsFile)) {
    Write-Error "Reference AGENTS.md not found at: $referenceAgentsFile"
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-TextFile {
    param (
        [string]$Path,
        [string]$Text
    )

    $normalizedText = ($Text -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    $normalizedText = $normalizedText -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $normalizedText, (New-Object System.Text.UTF8Encoding($false)))
}

# Description shown in the SKILL.md frontmatter, keyed by generated skill name
$descriptions = @{
    "coding-api-documentation"       = "Use when looking up a type's public API - consult the generated documentation/API/ markdown before opening .cs source to check signatures, namespaces, or <summary> descriptions."
    "coding-automatic-tests"         = "Use when writing or adding xUnit tests for C# classes, structs, or extension methods - Facts partial class structure, naming, shared test-data fixtures in DiGi.Test/files/, test reports and diagnostic dumps written to DiGi.Test/user files/reports/, and serialization, tolerance-boundary, and performance test patterns."
    "coding-deployed-webapi"         = "Use when verifying a client or server change against the live WebAPI at api.digiproject.uk - swagger as the source of truth, the county to reference to building GET test recipe, access rules and gotchas. Manual curl checks only, never added to DiGi.Test."
    "coding-editor-config"           = "Use when configuring, auditing, or enforcing .editorconfig code styles, explicit typing (no var), block-scoped namespaces, collection expressions, target-typed new(), and Visual Studio 2026 / C# 13/14 formatting rules across DiGi repositories."
    "coding-general"                 = "Use whenever writing or editing C# code in this workspace - naming/typing rules, CancellationToken ordering, member-access simplification, the DiGi.Core Query/Modify/Create/Convert architecture, cheap constructors with validation and normalisation moved into a Create factory, the one-member-per-file layout for Query/Modify/Create and nested types, files vs user files assets, the SerializableObject serialization pattern, and the host PackageReference rules for NuGet dependencies that HintPath references drop (a runtime FileNotFoundException that shows up as a partial result, not an error)."
    "coding-gis-administrative-data" = "Use when touching administrative_areal_2d, building_2d, or anything keyed by a county code or id - why a county code is not a key (BDOT10k stores one row per polygon part, so 406 county rows cover 380 codes), why those rows must never be deduplicated, the key-resolution matrix and the mandatory ORDER BY on any LIMIT/FirstOrDefault, plus the AdministrativeArealType wire gotchas."
    "coding-postgresql"              = "Use when designing database schemas or executing queries with Npgsql / PostgreSQL in DiGi solutions - Classes/Converter/ architecture, NULLS NOT DISTINCT composite unique indexes for nullable columns, query batching (batchSize = 1000, ANY(@array)), commandTimeout parameter standard, and connection asset isolation in user files/."
    "coding-references"              = "Use when comparing, matching, keying or de-duplicating an IReference/IUniqueReference - why == between two interface-typed references is a silent bug, what to use instead, and how to detect and fix existing occurrences."
    "coding-templates"               = "Use when creating a new project/solution from a template, or adding/modifying templates in the workspace's default templates/ folder."
    "coding-webapi-contracts"        = "Use when changing a WebAPI controller's route, parameter names or validation, or when writing or maintaining an HTTP client of one - why a renamed query parameter breaks clients with no compile error and no runtime error (ASP.NET silently ignores an unknown parameter and returns the unfiltered result), the binding traps where an omitted parameter keeps default(T) and an enum sentinel that is not 0 makes the obvious guard dead code, sending enum values as integers, the client base-URI constant and /Query plumbing pattern, and gating an endpoint that is not deployed yet."
    "coding-webapi-gltf"             = "Use when building or extending an ASP.NET Core Web API on the DiGi.GLTF 3D framework - the decoupled pipeline, onboarding a new consuming project, adding a 3D object type via IGLTFNodeConverter, and batching/streaming performance rules."
    "github-branch-pull"             = "Use when scanning local DiGi repositories, identifying SemVer branches, selecting the highest version, and pulling/syncing the local machine with the latest remote state."
    "github-branch-synchronization"  = "Use when running the version-branch to main merge and patch-bump release workflow - syncing a bare SemVer branch into main, bumping the patch version, and pushing both branches."
    "github-issues"                  = "Use when creating, managing, commenting on, or closing GitHub issues/PRs - mandatory Type and Priority labels on all new issues, and mandatory --body-file usage to avoid PowerShell escape mangling."
    "github-labels"                  = "Use when standardizing, applying, or syncing GitHub issue and PR labels across repositories - Type, Priority, and Status taxonomy, requiring Type and Priority on every new issue."
    "github-wiki-benchmark"          = "Use when creating or updating a repo's Benchmark GitHub wiki page - required page structure, reproducible-numbers conventions, and the checklist for adding a new benchmark entry."
    "github-wiki-general"            = "Use when editing any GitHub wiki page - repo layout, local clones under DigiProject/wiki/, hand-authored vs auto-generated pages, and CI sync mechanics."
    "github-wiki-home"               = "Use when creating or editing a repository's Wiki Home page - template structure, parsing/preservation rules for the sync script, and the standard DiGi ecosystem footer."
    "xml-documentation-audit"        = "Use when auditing or synchronizing existing XML docs against current signatures - a superset of xml-documentation-create that also rewrites stale summaries and fixes mismatched param/returns tags."
    "xml-documentation-create"       = "Use when adding missing XML <summary> docs to public members without touching existing docs or code logic."
}

# Guideline files, in a stable order (README.md is an index, not a guideline)
$guidelineFiles = Get-ChildItem -Path $guidelinesDir -Filter "*.md" | Where-Object { $_.Name -ne "README.md" } | Sort-Object Name

# Refresh the external machine-global AGENTS.md, if one is configured
$confPath = Join-Path $PSScriptRoot "..\user files\Directories.conf"
$globalAgentsPath = ""

if (Test-Path $confPath) {
    foreach ($line in Get-Content $confPath) {
        $line = $line.Trim()
        if ($line.StartsWith("#") -or $line -eq "") { continue }
        $index = $line.IndexOf("=")
        if ($index -lt 0) { continue }
        $key = $line.Substring(0, $index).Trim()
        if ($key -ne "GLOBAL_AGENTS_FILE") { continue }
        $globalAgentsPath = $line.Substring($index + 1).Trim().Trim('"')
    }
}

if ($globalAgentsPath -eq "") {
    Write-Host "GLOBAL_AGENTS_FILE is not configured in 'user files/Directories.conf' - skipping global AGENTS.md." -ForegroundColor DarkGray
} elseif (-not (Test-Path $globalAgentsPath)) {
    Write-Warning "Global AGENTS.md not found at: $globalAgentsPath"
} else {
    Write-Host "Updating global AGENTS.md: $globalAgentsPath" -ForegroundColor Yellow

    $headerLines = @()
    foreach ($line in Get-Content $globalAgentsPath) {
        $headerLines += $line
        if ($line -match '## Summary of Core Coding & Testing Guidelines') {
            break
        }
    }

    $compiledSections = @()
    foreach ($guidelineFile in $guidelineFiles) {
        $compiledSections += "<!-- Source: $($guidelineFile.Name) -->`n`n" + ([System.IO.File]::ReadAllText($guidelineFile.FullName)).TrimEnd()
    }

    Write-TextFile -Path $globalAgentsPath -Text (($headerLines -join "`n") + "`n`n" + ($compiledSections -join "`n`n---`n`n"))
    Write-Host "Global AGENTS.md updated successfully." -ForegroundColor Green
}

$referenceAgentsText = [System.IO.File]::ReadAllText($referenceAgentsFile)

$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    $agentsDir = Join-Path $dirPath ".agents"
    $skillsDir = Join-Path $agentsDir "skills"

    Write-Host "Processing repository: $dirName" -ForegroundColor Cyan

    if (-not (Test-Path $agentsDir)) {
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    }

    # Clean up legacy folders directly under .agents that are not 'skills'
    Get-ChildItem -Path $agentsDir -Directory | Where-Object { $_.Name -ne "skills" } | ForEach-Object {
        Write-Host "    Cleaning up legacy folder: $($_.Name)" -ForegroundColor DarkGray
        Remove-Item $_.FullName -Recurse -Force
    }

    # Re-create/clean skills folder so removed guidelines do not leave stale skills behind
    if (Test-Path $skillsDir) {
        Remove-Item $skillsDir -Recurse -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

    Write-TextFile -Path (Join-Path $agentsDir "AGENTS.md") -Text $referenceAgentsText

    foreach ($guidelineFile in $guidelineFiles) {
        # 'Coding - Deployed WebAPI.md' -> 'coding-deployed-webapi'
        $skillName = ($guidelineFile.BaseName -replace '\s+-\s+', '-' -replace '\s+', '-').ToLower()

        $description = $descriptions[$skillName]
        if (-not $description) {
            Write-Warning "No description registered for skill '$skillName' - using a generic one."
            $description = "Use for tasks related to $skillName."
        }

        $skillFolder = Join-Path $skillsDir $skillName
        New-Item -ItemType Directory -Path $skillFolder -Force | Out-Null

        $skillText = "---`nname: $skillName`ndescription: $description`n---`n`n" + [System.IO.File]::ReadAllText($guidelineFile.FullName)
        Write-TextFile -Path (Join-Path $skillFolder "SKILL.md") -Text $skillText
    }

    if ($NoCommit) {
        continue
    }

    $gitDir = Join-Path $dirPath ".git"
    if (-not (Test-Path $gitDir)) {
        continue
    }

    Push-Location $dirPath
    $status = git status --porcelain .agents
    if ($status) {
        Write-Host "    Committing updated rules and skills in: $dirName" -ForegroundColor Cyan
        git add .agents
        git commit -m $Message | Out-Null
    } else {
        Write-Host "    No changes in .agents for: $dirName" -ForegroundColor Gray
    }
    Pop-Location
}

Write-Host "`nSynchronization complete!" -ForegroundColor Green
