# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\SyncWiki.ps1
param(
    [Parameter(Mandatory=$false)]
    [string]$RepoPath = (Resolve-Path "$PSScriptRoot\..").Path
)

# Clean up path formatting
$RepoPath = (Resolve-Path $RepoPath).Path
$repoName = $RepoPath.Split('\')[-1]
Write-Host "Starting wiki sync for repository: $repoName ($RepoPath)" -ForegroundColor Cyan

# Validate Git repo
Push-Location $RepoPath
$remoteUrl = git config --get remote.origin.url
Pop-Location

if (-not $remoteUrl) {
    Write-Error "Could not detect remote Git URL for path $RepoPath. Ensure this directory is a valid git repository."
    exit 1
}

# Transform main repository URL to wiki URL (e.g., repo.git -> repo.wiki.git)
$wikiRepoUrl = $remoteUrl -replace '\.git$', '.wiki.git'
$tempWikiDir = "$env:TEMP\DiGi.WikiTemp_$repoName"

# Ensure local documentation exists
$localDocsDir = "$RepoPath\documentation\API"
if (-not (Test-Path $localDocsDir)) {
    Write-Error "Local API documentation directory not found at $localDocsDir. Please build the solution first."
    exit 1
}

# Clone the wiki repository to a temporary folder
if (Test-Path $tempWikiDir) { Remove-Item -Recurse -Force $tempWikiDir }
git clone $wikiRepoUrl $tempWikiDir

# Copy generated docs to the wiki folder root
Copy-Item -Path "$localDocsDir\*" -Destination $tempWikiDir -Recurse -Force

# Commit and push to GitHub Wiki
Push-Location $tempWikiDir
# Set Git credentials locally in case running in headless CI
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git add .
# Only commit and push if there are changes to avoid empty commits
$status = git status --porcelain
if ($status) {
    git commit -m "chore: auto-update API documentation"
    git push origin master
    Write-Host "GitHub Wiki synchronization complete for $repoName!" -ForegroundColor Green
} else {
    Write-Host "No documentation changes detected for $repoName. Skipping wiki push." -ForegroundColor Yellow
}
Pop-Location

# Clean up
Remove-Item -Recurse -Force $tempWikiDir
