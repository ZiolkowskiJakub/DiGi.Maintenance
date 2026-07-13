# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\UpdateAgents.ps1

# Force UTF-8 output encoding for any child process and output files
$OutputEncoding = [System.Text.Encoding]::UTF8

# Get base directory
$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
Write-Host "Base directory resolved to: $baseDir" -ForegroundColor Cyan

# 1. Compile latest guidelines
Write-Host "Compiling guidelines..." -ForegroundColor Yellow
$compileScript = Join-Path $baseDir "update_wikis_and_readmes.ps1"
if (Test-Path $compileScript) {
    pwsh -NoProfile -ExecutionPolicy Bypass -File $compileScript -CompileOnly
} else {
    Write-Error "Could not find compile script: $compileScript"
    exit 1
}

# 2. Re-compile global AGENTS.md
$globalAgentsPath = "C:\Users\jakub\.gemini\config\AGENTS.md"
if (Test-Path $globalAgentsPath) {
    Write-Host "Updating global AGENTS.md..." -ForegroundColor Yellow
    $lines = Get-Content $globalAgentsPath
    $headerLines = @()
    foreach ($line in $lines) {
        $headerLines += $line
        if ($line -match '## Summary of Core Coding & Testing Guidelines') {
            break
        }
    }
    $header = $headerLines -join "`r`n"
    $compiledGuidelinesPath = Join-Path $baseDir "compiled_guidelines.md"
    if (Test-Path $compiledGuidelinesPath) {
        $compiledText = Get-Content $compiledGuidelinesPath -Raw
        $newGlobalAgentsContent = $header + "`r`n`r`n" + $compiledText
        $newGlobalAgentsContent | Out-File $globalAgentsPath -Encoding utf8 -Force
        Write-Host "Global AGENTS.md updated successfully." -ForegroundColor Green
    } else {
        Write-Warning "compiled_guidelines.md not found. Skipping global AGENTS.md update."
    }
} else {
    Write-Warning "Global AGENTS.md not found at: $globalAgentsPath"
}

# Define descriptions mapping for each skill
$descriptions = @{
    "coding-api-documentation"      = "Use when looking up a type's public API - consult the generated documentation/API/ markdown before opening .cs source to check signatures, namespaces, or <summary> descriptions."
    "coding-automatic-tests"        = "Use when writing or adding xUnit tests for C# classes, structs, or extension methods - Facts partial class structure, naming, shared test-data fixtures, and serialization, tolerance-boundary, and performance test patterns."
    "coding-general"                = "Use whenever writing or editing C# code in this workspace - naming/typing rules, the DiGi.Core Query/Modify/Create/Convert architecture, files vs user files assets, and the SerializableObject serialization pattern."
    "coding-templates"              = "Use when creating a new project/solution from a template, or adding/modifying templates in the workspace's default templates/ folder."
    "coding-webapi-gltf"            = "Use when building or extending an ASP.NET Core Web API on the DiGi.GLTF 3D framework - the decoupled pipeline, onboarding a new consuming project, adding a 3D object type via IGLTFNodeConverter, and batching/streaming performance rules."
    "github-branch-pull"            = "Use when scanning local DiGi repositories, identifying SemVer branches, selecting the highest version, and pulling/syncing the local machine with the latest remote state."
    "github-branch-synchronization" = "Use when running the version-branch to main merge and patch-bump release workflow - syncing a bare SemVer branch into main, bumping the patch version, and pushing both branches."
    "github-wiki-benchmark"         = "Use when creating or updating a repo's Benchmark GitHub wiki page - required page structure, reproducible-numbers conventions, and the checklist for adding a new benchmark entry."
    "github-wiki-general"           = "Use when editing any GitHub wiki page - repo layout, local clones under DigiProject/wiki/, hand-authored vs auto-generated pages, and CI sync mechanics."
    "github-wiki-home"              = "Use when creating or editing a repository's Wiki Home page - template structure, parsing/preservation rules for the sync script, and the standard DiGi ecosystem footer."
    "xml-documentation-audit"       = "Use when auditing or synchronizing existing XML docs against current signatures - a superset of xml-documentation-create that also rewrites stale summaries and fixes mismatched param/returns tags."
    "xml-documentation-create"      = "Use when adding missing XML <summary> docs to public members without touching existing docs or code logic."
}

# 3. Get all repositories
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

$guidelinesDir = Join-Path $baseDir "DiGi.Maintenance\documentation\AI Guidelines"
$referenceAgentsFile = Join-Path $baseDir "DiGi.Maintenance\.agents\AGENTS.md"

if (-not (Test-Path $guidelinesDir)) {
    Write-Error "AI Guidelines directory not found: $guidelinesDir"
    exit 1
}

# Get list of guideline files (skipping README.md)
$guidelineFiles = Get-ChildItem -Path $guidelinesDir -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }

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
    
    # Re-create/clean skills folder
    if (Test-Path $skillsDir) {
        Remove-Item $skillsDir -Recurse -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
    
    # Copy AGENTS.md from reference
    $targetAgentsFile = Join-Path $agentsDir "AGENTS.md"
    if (Test-Path $referenceAgentsFile) {
        Copy-Item -Path $referenceAgentsFile -Destination $targetAgentsFile -Force
    } else {
        Write-Warning "Reference AGENTS.md not found at: $referenceAgentsFile"
    }
    
    # Generate each skill
    foreach ($guidelineFile in $guidelineFiles) {
        # Determine skill folder name
        $nameWithoutExt = $guidelineFile.BaseName
        $skillName = ($nameWithoutExt -replace '\s+-\s+', '-' -replace '\s+', '-').ToLower()
        
        $desc = $descriptions[$skillName]
        if (-not $desc) {
            $desc = "Use for tasks related to $skillName."
        }
        
        $skillFolder = Join-Path $skillsDir $skillName
        New-Item -ItemType Directory -Path $skillFolder -Force | Out-Null
        
        # Read guideline file content
        $content = Get-Content $guidelineFile.FullName -Raw
        
        # Generate skill content with frontmatter
        $skillContent = @"
---
name: $skillName
description: $desc
---

$content
"@
        
        $targetSkillFile = Join-Path $skillFolder "SKILL.md"
        $skillContent | Out-File $targetSkillFile -Encoding utf8 -Force
    }
    
    # Commit changes if repo has .git and status is dirty
    $gitDir = Join-Path $dirPath ".git"
    if (Test-Path $gitDir) {
        Push-Location $dirPath
        $status = git status --porcelain .agents
        if ($status) {
            Write-Host "    Committing updated rules and skills in: $dirName" -ForegroundColor Cyan
            git add .agents
            git commit -m "Sync rules and skills (.agents) with latest AI Guidelines" | Out-Null
        } else {
            Write-Host "    No changes in .agents for: $dirName" -ForegroundColor Gray
        }
        Pop-Location
    }
}

Write-Host "`nSynchronization complete!" -ForegroundColor Green
