# PullBranchesAllRepos.ps1
# Automates synchronization of all DiGi repositories to their highest SemVer branch.

$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

$syncResults = @()

foreach ($dir in $targetDirectories) {
    $dirPath = $dir.FullName
    $dirName = $dir.Name
    
    if (-not (Test-Path (Join-Path $dirPath ".git"))) {
        continue
    }
    
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
    Write-Host "Processing $dirName..." -ForegroundColor Cyan
    Push-Location $dirPath
    
    # 1. Fetch Remote State
    Write-Host "Fetching remote state (git fetch --all --prune)..." -ForegroundColor Gray
    git fetch --all --prune
    
    # 2. Get all branches (local and remote)
    $branches = git branch -a
    $semverBranches = @()
    
    foreach ($b in $branches) {
        $cleanB = $b.Trim() -replace '^\*\s*', ''
        $cleanB = $cleanB -replace '^remotes/origin/', ''
        $cleanB = $cleanB -replace '^origin/', ''
        
        if ($cleanB -match '^\d+\.\d+\.\d+$') {
            if ($semverBranches -notcontains $cleanB) {
                $semverBranches += $cleanB
            }
        }
    }
    
    # 3. Evaluate Highest Version
    $highestBranch = $null
    if ($semverBranches.Count -gt 0) {
        $sortedBranches = @($semverBranches | Sort-Object {
            $parts = $_.Split('.')
            [int]$parts[0] * 1000000 + [int]$parts[1] * 1000 + [int]$parts[2]
        } -Descending)
        $highestBranch = $sortedBranches[0]
    }
    
    $initialBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    $status = "Success"
    $targetBranch = ""
    $actionTaken = ""
    
    try {
        if ($null -ne $highestBranch) {
            $targetBranch = $highestBranch
            Write-Host "Highest SemVer branch identified: $targetBranch" -ForegroundColor Green
            
            # Checkout target branch
            if ($initialBranch -ne $targetBranch) {
                Write-Host "Checking out branch $targetBranch..." -ForegroundColor Gray
                git checkout $targetBranch
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to checkout branch $targetBranch"
                }
                $actionTaken += "Checked out $targetBranch (was $initialBranch). "
            } else {
                $actionTaken += "Already on $targetBranch. "
            }
            
            # Pull remote changes
            Write-Host "Pulling changes for $targetBranch..." -ForegroundColor Gray
            git pull origin $targetBranch
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull changes for $targetBranch"
            }
            $actionTaken += "Pulled changes from origin."
        } else {
            # No SemVer branch found (e.g. DiGi.Maintenance)
            $targetBranch = $initialBranch
            Write-Host "No SemVer branch found. Syncing active branch '$targetBranch'..." -ForegroundColor Yellow
            
            git pull
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull changes for active branch $targetBranch"
            }
            $actionTaken = "No SemVer branches. Pulled active branch $targetBranch."
        }
    } catch {
        $status = "Failed: $_"
        Write-Error "Error processing $dirName : $_"
    } finally {
        Pop-Location
    }
    
    $syncResults += [PSCustomObject]@{
        Repository   = $dirName
        FromBranch   = $initialBranch
        ToBranch     = $targetBranch
        Status       = $status
        Action       = $actionTaken
    }
}

Write-Host "==================================================" -ForegroundColor Gray
Write-Host "Synchronization Summary:" -ForegroundColor Green
$syncResults | Format-Table -AutoSize
