# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\CommitAllRepos.ps1

$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    
    if (Test-Path (Join-Path $dirPath ".git")) {
        Push-Location $dirPath
        
        $status = git status --porcelain
        if ($status) {
            Write-Host "Committing changes in: $dirName" -ForegroundColor Cyan
            git add .
            git commit -m "Markdown documentation added"
        } else {
            Write-Host "No changes to commit in: $dirName" -ForegroundColor Yellow
        }
        
        Pop-Location
    }
}

Write-Host "All commits completed!" -ForegroundColor Green
