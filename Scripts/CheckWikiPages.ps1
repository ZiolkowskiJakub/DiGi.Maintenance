# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\CheckWikiPages.ps1

$baseDir = "c:\Users\jakub\GitHub\DigiProject"
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

$hasWiki = [System.Collections.Generic.List[string]]::new()
$missingWiki = [System.Collections.Generic.List[string]]::new()

Write-Host "Checking GitHub Wiki setup for all repositories..." -ForegroundColor Cyan

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    
    if (-not (Test-Path (Join-Path $dirPath ".git"))) {
        continue
    }
    
    Push-Location $dirPath
    $remoteUrl = git config --get remote.origin.url
    Pop-Location
    
    if (-not $remoteUrl) {
        Write-Host "Skipping $($dirName): No remote URL found." -ForegroundColor Yellow
        continue
    }
    
    # Format the wiki URL
    $cleanUrl = $remoteUrl -replace '\.git$', ''
    $wikiUrl = $cleanUrl + ".wiki.git"
    
    # Run git ls-remote to check repository existence
    $null = git ls-remote $wikiUrl 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        $hasWiki.Add($dirName)
        Write-Host "[OK] $dirName has a Wiki setup." -ForegroundColor Green
    } else {
        $missingWiki.Add($dirName)
        Write-Host "[MISSING] $dirName does NOT have a Wiki setup." -ForegroundColor Red
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Repositories Checked: $($targetDirectories.Count)"
Write-Host "Wikis Set Up: $($hasWiki.Count)" -ForegroundColor Green
Write-Host "Wikis Missing: $($missingWiki.Count)" -ForegroundColor Red

if ($missingWiki.Count -gt 0) {
    Write-Host "`nRepositories with missing Wikis:" -ForegroundColor Red
    foreach ($repo in $missingWiki) {
        Write-Host "  - $repo (Wiki URL: https://github.com/ZiolkowskiJakub/$repo/wiki)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nAll checked repositories have active Wikis!" -ForegroundColor Green
}
