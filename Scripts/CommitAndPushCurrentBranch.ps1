# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\CommitAndPushCurrentBranch.ps1

$baseDir = "c:\Users\jakub\GitHub\DigiProject"
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    
    if (-not (Test-Path (Join-Path $dirPath ".git"))) {
        continue
    }
    
    Push-Location $dirPath
    
    $activeBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    
    # 1. Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Host "Committing changes in: $dirName (Branch: $activeBranch)" -ForegroundColor Cyan
        git add .
        git commit -m "Markdown documentation added"
    } else {
        Write-Host "No new uncommitted changes in: $dirName (Branch: $activeBranch)" -ForegroundColor Yellow
    }
    
    # 2. Push current branch to remote
    Write-Host "Pushing current branch '$activeBranch' in $dirName..." -ForegroundColor Cyan
    git push origin HEAD
    
    Pop-Location
}

Write-Host "All commits and pushes completed!" -ForegroundColor Green
