# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\SyncBranchesAllRepos.ps1

$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    
    if (-not (Test-Path (Join-Path $dirPath ".git"))) {
        continue
    }
    
    Push-Location $dirPath
    
    # 1. Get current active branch
    $activeBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    
    # Trigger Condition 1: Check if the branch is exactly X.Y.Z
    if ($activeBranch -notmatch '^\d+\.\d+\.\d+$') {
        Write-Host "Skipping $($dirName): active branch '$activeBranch' is not a semantic version (digits and periods only)." -ForegroundColor Yellow
        Pop-Location
        continue
    }
    
    Write-Host "Processing $($dirName): active version branch is '$activeBranch'" -ForegroundColor Cyan
    
    # Ensure local main exists and is updated
    git checkout main | Out-Null
    git pull origin main | Out-Null
    git checkout $activeBranch | Out-Null
    
    # Trigger Condition 2: Compare active branch with main
    # git diff --quiet returns exit code 0 if identical, 1 if differences exist
    git diff --quiet main
    $hasDiff = $LASTEXITCODE -ne 0
    
    if (-not $hasDiff) {
        Write-Host "Skipping $($dirName): active branch '$activeBranch' is identical to 'main'." -ForegroundColor Yellow
        Pop-Location
        continue
    }
    
    Write-Host "Synchronizing $($dirName)..." -ForegroundColor Green
    
    # Step 1: Merge active branch into main
    git checkout main
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to checkout main in $($dirName)"
        Pop-Location
        continue
    }
    
    git merge $activeBranch --no-edit
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to merge $activeBranch into main in $($dirName). Manual resolution needed."
        git merge --abort
        Pop-Location
        continue
    }
    
    # Push updated main to remote
    git push origin main
    
    # Step 2: Calculate Next Version (Patch Bump)
    $versionParts = $activeBranch.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
    $nextPatch = $patch + 1
    $nextVersion = "$major.$minor.$nextPatch"
    Write-Host "Next version calculated: $nextVersion" -ForegroundColor Cyan
    
    # Step 3: Create New Branch off main
    git checkout -b $nextVersion
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create branch $nextVersion in $($dirName)"
        Pop-Location
        continue
    }
    
    # Step 4: Update Version in Directory.Build.props if it exists
    $propsPath = Join-Path $dirPath "Directory.Build.props"
    if (Test-Path $propsPath) {
        Write-Host "Updating Directory.Build.props to version $nextVersion in $($dirName)" -ForegroundColor Cyan
        $propsContent = Get-Content -Path $propsPath -Raw
        
        # Replace <Major>...</Major>
        $propsContent = $propsContent -replace '<Major>\d+</Major>', "<Major>$major</Major>"
        # Replace <Minor>...</Minor>
        $propsContent = $propsContent -replace '<Minor>\d+</Minor>', "<Minor>$minor</Minor>"
        # Replace <Build>...</Build> (maps to the patch version)
        $propsContent = $propsContent -replace '<Build>\d+</Build>', "<Build>$nextPatch</Build>"
        
        Set-Content -Path $propsPath -Value $propsContent -Force
        
        # Commit the change
        git add Directory.Build.props
        git commit -m "chore: bump version to $nextVersion"
    }
    
    # Step 5: Publish the new branch to GitHub and set upstream
    git push -u origin $nextVersion
    
    Write-Host "Successfully synchronized and bumped $($dirName) to $nextVersion!" -ForegroundColor Green
    Pop-Location
}

Write-Host "All branch synchronizations completed!" -ForegroundColor Green
