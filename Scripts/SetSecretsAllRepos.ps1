# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\SetSecretsAllRepos.ps1
# Requires GitHub CLI (gh) installed and authenticated.
# Install: winget install --id GitHub.cli
# Authenticate: gh auth login

param(
    [Parameter(Mandatory=$true)]
    [string]$PatToken
)

$baseDir = "c:\Users\jakub\GitHub\DigiProject"
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

Write-Host "Setting secret WIKI_SYNC_PAT across all repositories..." -ForegroundColor Cyan

foreach ($dir in $targetDirectories) {
    $repoName = $dir.Name
    $repoIdentifier = "ZiolkowskiJakub/$repoName"
    
    Write-Host "Setting secret for $repoIdentifier..." -ForegroundColor Cyan
    gh secret set WIKI_SYNC_PAT --body $PatToken --repo $repoIdentifier
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Set secret for $repoName" -ForegroundColor Green
    } else {
        Write-Warning "Failed to set secret for $repoName. Make sure you are authenticated."
    }
}

Write-Host "All secret updates completed!" -ForegroundColor Green
