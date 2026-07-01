# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\PushAllRepos.ps1

$baseDir = "c:\Users\jakub\GitHub\DigiProject"
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    
    if (Test-Path (Join-Path $dirPath ".git")) {
        Push-Location $dirPath
        
        # Attempt to push to the remote branch
        Write-Host "Pushing changes in: $dirName" -ForegroundColor Cyan
        git push
        
        Pop-Location
    }
}

Write-Host "All pushes completed!" -ForegroundColor Green
