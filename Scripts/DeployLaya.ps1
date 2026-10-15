<#
.SYNOPSIS
    Deploys the Laya runtime package and released Laya checkpoints to <SoftwareDirectory>\DiGi.Laya.

.DESCRIPTION
    Called by Deploy.ps1 when INCLUDE_LAYA_MODELS is set in 'user files/Directories.conf', and reusable by the
    deploy scripts of DiGi.Laya consumers (bodyplan).

    1. Copies requirements.txt and InstallPythonEnvironment.ps1 into <SoftwareDirectory>\DiGi.Laya\. The Python
       environment itself is created on each host by InstallPythonEnvironment.ps1, outside the synced software tree,
       and is never part of a deploy.
    2. Deploys every released checkpoint <ModelsDirectory>\<name>\ to <SoftwareDirectory>\DiGi.Laya\models\<name>\,
       from an ALLOWLIST of the checkpoint layout: model.safetensors and *.json at the root, encoder\*.json, and
       tokenizer\*.json / *.model / *.txt. Every other file and folder - checkpoint_latest (a full duplicate of the
       checkpoint left by laya's own trainer), scratch, logs - is listed on the "not deployed" line.
    3. Copies <ModelsDirectory>\<name>.calibration.json, when present, to models\<name>.calibration.json.
    4. Writes models\<name>.manifest.json BESIDE the checkpoint, never inside it: DiGi.Laya identifies a checkpoint by
       DiGi.Python's Query.DirectorySHA256 over its whole folder, so a file added inside would change every SHA the
       host reports. The manifest's directorySHA256 is computed over the deployed files exactly like DirectorySHA256
       and is checked again on the copy.

    A model whose manifest is unchanged, and whose deployed files are all present with their recorded sizes, is
    skipped - a 1.3 GB checkpoint is not copied again. A changed model is copied to models\<name>.staging and swapped
    in, and its manifest is written last, so an interrupted deploy is recopied by the next one. One model never
    clears another, and a deployed model is removed only when named in -Remove: a host may depend on it.

.PARAMETER SoftwareDirectory
    The software directory the package is deployed to (SOFTWARE_DIRECTORY in Directories.conf).

.PARAMETER ModelsDirectory
    The released checkpoints on this machine (LAYA_MODELS_DIRECTORY): one subfolder per model, each with an optional
    <name>.calibration.json beside it.

.PARAMETER ModelNames
    The models to deploy. Default: every subfolder of -ModelsDirectory.

.PARAMETER RequirementsPath
    The requirements.txt the host environment is installed from. Default: DiGi.Laya\files\Laya\requirements.txt in
    the workspace.

.PARAMETER Remove
    Deployed models to remove: the folder, its manifest and its calibration file.

.PARAMETER MaxMB
    Size per model above which a warning lists the largest files. The model is deployed regardless.

.PARAMETER MaxFileCount
    File count per model above which the same warning is printed.
#>
param (
    [Parameter(Mandatory = $true)][string]$SoftwareDirectory,
    [Parameter(Mandatory = $true)][string]$ModelsDirectory,
    [string[]]$ModelNames = @(),
    [string]$RequirementsPath = "",
    [string[]]$Remove = @(),
    [int]$MaxMB = 4096,
    [int]$MaxFileCount = 50
)

if ([string]::IsNullOrWhiteSpace($RequirementsPath)) {
    $RequirementsPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path "DiGi.Laya\files\Laya\requirements.txt"
}

$packageDir = Join-Path $SoftwareDirectory "DiGi.Laya"
$modelsDir_Destination = Join-Path $packageDir "models"
$failed = $false

# Relative paths of the checkpoint layout, '/'-separated. A file is deployed only when one of these matches it.
# laya writes only model.safetensors as weights; *.json covers rl_agent_config.json, questions.json and
# train_report.json at the root, config.json in encoder\ and the tokenizer files.
$allowedPatterns = @("model.safetensors", "*.json", "encoder/*.json", "tokenizer/*.json", "tokenizer/*.model", "tokenizer/*.txt")
$allowedDirectoryNames = @("encoder", "tokenizer")

function Test-AllowedPath([string]$RelativePath) {
    foreach ($pattern in $allowedPatterns) {
        # Each pattern names exactly one folder depth, so 'tokenizer/sub/x.json' matches none of them.
        if (($RelativePath.Split('/').Count -eq $pattern.Split('/').Count) -and ($RelativePath -like $pattern)) {
            return $true
        }
    }
    return $false
}

function Get-RelativePath([string]$Root, [string]$FullName) {
    return $FullName.Substring($Root.Length + 1).Replace('\', '/')
}

function Get-FileSHA256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Exactly DiGi.Python's Query.DirectorySHA256 (DiGi-Organization/DiGi.Python#1) over the given relative paths:
# '/'-separated paths sorted ORDINALLY - never Sort-Object, which is culture-aware and case-insensitive - a manifest
# of "path\nlowercase-sha256\n" per file, and the lowercase SHA-256 of its UTF-8 bytes (no BOM).
function Get-ManifestSHA256([string[]]$RelativePaths, [hashtable]$FileSHA256s) {
    $entries = [System.Collections.Generic.List[string]]::new()
    foreach ($relativePath in $RelativePaths) { $entries.Add($relativePath) }
    $entries.Sort([System.StringComparer]::Ordinal)

    $manifest = [System.Text.StringBuilder]::new()
    foreach ($relativePath in $entries) {
        [void]$manifest.Append($relativePath).Append("`n").Append($FileSHA256s[$relativePath]).Append("`n")
    }

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try { $bytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($manifest.ToString())) }
    finally { $sha256.Dispose() }
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

# DirectorySHA256 of a whole folder: every file, recursively.
function Get-DirectorySHA256([string]$Directory) {
    $root = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\', '/')
    $fileSHA256s = @{}
    foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse -Force) {
        $fileSHA256s[(Get-RelativePath $root $file.FullName)] = Get-FileSHA256 $file.FullName
    }
    return Get-ManifestSHA256 -RelativePaths @($fileSHA256s.Keys) -FileSHA256s $fileSHA256s
}

function Remove-PathIfPresent([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

function Write-Utf8File([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

Write-Host "Laya package: $packageDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $modelsDir_Destination -Force | Out-Null

# --- Runtime package ---
$installScriptPath = Join-Path $PSScriptRoot "InstallPythonEnvironment.ps1"
foreach ($path_Source in @($RequirementsPath, $installScriptPath)) {
    if (Test-Path -LiteralPath $path_Source) {
        Copy-Item -LiteralPath $path_Source -Destination $packageDir -Force
        Write-Host "Copied $(Split-Path $path_Source -Leaf)." -ForegroundColor Green
    } else {
        Write-Warning "'$path_Source' not found - a host could not install its Python environment from this package."
        $failed = $true
    }
}

# --- Removal (explicit only) ---
$removed = @()
foreach ($name in $Remove) {
    if ([string]::IsNullOrWhiteSpace($name) -or $name -ne (Split-Path $name -Leaf)) {
        Write-Warning "-Remove '$name' is not a model name - nothing removed."
        $failed = $true
        continue
    }

    try {
        foreach ($path in @((Join-Path $modelsDir_Destination $name), (Join-Path $modelsDir_Destination "$name.manifest.json"), (Join-Path $modelsDir_Destination "$name.calibration.json"))) {
            Remove-PathIfPresent $path
        }
        $removed += $name
        Write-Host "Removed model '$name'." -ForegroundColor Cyan
    } catch {
        Write-Warning "Could not remove model '$name': $_"
        $failed = $true
    }
}

# --- Models ---
if (-not (Test-Path -LiteralPath $ModelsDirectory)) {
    Write-Warning "Laya models directory '$ModelsDirectory' does not exist - no model deployed."
    exit 1
}

$modelsDir_Source = [System.IO.Path]::GetFullPath($ModelsDirectory).TrimEnd('\', '/')
if ($ModelNames.Count -eq 0) {
    $ModelNames = @(Get-ChildItem -LiteralPath $modelsDir_Source -Directory -Force | ForEach-Object { $_.Name })
}

$summaries = @()
foreach ($name in $ModelNames) {
    $modelDir_Source = Join-Path $modelsDir_Source $name
    $modelDir_Destination = Join-Path $modelsDir_Destination $name
    $manifestPath = Join-Path $modelsDir_Destination "$name.manifest.json"
    $calibrationPath_Source = Join-Path $modelsDir_Source "$name.calibration.json"
    $calibrationPath_Destination = Join-Path $modelsDir_Destination "$name.calibration.json"

    if (-not (Test-Path -LiteralPath $modelDir_Source -PathType Container)) {
        Write-Warning "Model '$name' not found in '$modelsDir_Source'."
        $summaries += [pscustomobject]@{ Model = $name; Status = "failed"; Files = 0; MB = 0 }
        $failed = $true
        continue
    }

    # Allowlist: files of the checkpoint layout are deployed, everything else is reported.
    $files_Deployable = @()
    $notDeployed = @()
    foreach ($directory in Get-ChildItem -LiteralPath $modelDir_Source -Directory -Force) {
        if (-not ($allowedDirectoryNames -contains $directory.Name)) {
            $notDeployed += "$($directory.Name)/"
        }
    }
    foreach ($directoryPath in @($modelDir_Source) + @($allowedDirectoryNames | ForEach-Object { Join-Path $modelDir_Source $_ } | Where-Object { Test-Path -LiteralPath $_ })) {
        foreach ($file in Get-ChildItem -LiteralPath $directoryPath -File -Force) {
            $relativePath = Get-RelativePath $modelDir_Source $file.FullName
            if (Test-AllowedPath $relativePath) {
                $files_Deployable += $file
            } else {
                $notDeployed += $relativePath
            }
        }
        if ($directoryPath -ne $modelDir_Source) {
            foreach ($directory in Get-ChildItem -LiteralPath $directoryPath -Directory -Force) {
                $notDeployed += "$(Get-RelativePath $modelDir_Source $directory.FullName)/"
            }
        }
    }

    $fileCount = $files_Deployable.Count
    $sizeMB = [math]::Round(($files_Deployable | Measure-Object -Property Length -Sum).Sum / 1MB)
    Write-Host "Laya model '$name': $fileCount file(s), $sizeMB MB. Not deployed: $(if ($notDeployed) { $notDeployed -join ', ' } else { '(none)' })" -ForegroundColor Cyan

    if (-not ($files_Deployable | Where-Object { $_.Name -eq "model.safetensors" -and $_.DirectoryName -eq $modelDir_Source })) {
        Write-Warning "Model '$name' has no model.safetensors - not deployed."
        $summaries += [pscustomobject]@{ Model = $name; Status = "failed"; Files = $fileCount; MB = $sizeMB }
        $failed = $true
        continue
    }

    if ($fileCount -gt $MaxFileCount -or $sizeMB -gt $MaxMB) {
        Write-Warning "Model '$name' is $fileCount file(s) / $sizeMB MB, above the expected $MaxFileCount file(s) / $MaxMB MB. Largest files:"
        $files_Deployable | Sort-Object Length -Descending | Select-Object -First 5 | ForEach-Object {
            [pscustomobject]@{ File = (Get-RelativePath $modelDir_Source $_.FullName); MB = [math]::Round($_.Length / 1MB, 1) }
        } | Format-Table -AutoSize | Out-Host
    }

    # Manifest of the deployed file set.
    $fileSHA256s = @{}
    $files = [ordered]@{}
    foreach ($file in $files_Deployable) {
        $fileSHA256s[(Get-RelativePath $modelDir_Source $file.FullName)] = Get-FileSHA256 $file.FullName
    }
    $relativePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($relativePath in $fileSHA256s.Keys) { $relativePaths.Add($relativePath) }
    $relativePaths.Sort([System.StringComparer]::Ordinal)
    foreach ($relativePath in $relativePaths) {
        $files[$relativePath] = [ordered]@{ sha256 = $fileSHA256s[$relativePath]; size = (Get-Item -LiteralPath (Join-Path $modelDir_Source $relativePath)).Length }
    }

    $directorySHA256 = Get-ManifestSHA256 -RelativePaths $relativePaths.ToArray() -FileSHA256s $fileSHA256s
    $calibrationSHA256 = $null
    if (Test-Path -LiteralPath $calibrationPath_Source -PathType Leaf) {
        $calibrationSHA256 = Get-FileSHA256 $calibrationPath_Source
    }

    # Unchanged when the deployed manifest names the same content and every deployed file is still in place.
    $isUnchanged = $false
    if (Test-Path -LiteralPath $manifestPath) {
        try {
            $manifest_Deployed = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $isUnchanged = ($manifest_Deployed.directorySHA256 -eq $directorySHA256) -and ($manifest_Deployed.calibrationSHA256 -eq $calibrationSHA256)
            if ($isUnchanged) {
                foreach ($relativePath in $relativePaths) {
                    $path_Deployed = Join-Path $modelDir_Destination $relativePath
                    if (-not (Test-Path -LiteralPath $path_Deployed -PathType Leaf) -or (Get-Item -LiteralPath $path_Deployed).Length -ne $files[$relativePath].size) {
                        $isUnchanged = $false
                        break
                    }
                }
            }
            if ($isUnchanged -and $null -ne $calibrationSHA256 -and -not (Test-Path -LiteralPath $calibrationPath_Destination -PathType Leaf)) {
                $isUnchanged = $false
            }
        } catch {
            Write-Warning "Deployed manifest '$manifestPath' could not be read - model '$name' is copied again: $_"
        }
    }

    if ($isUnchanged) {
        Write-Host "Laya model '$name': skipped (unchanged, $directorySHA256)." -ForegroundColor Green
        $summaries += [pscustomobject]@{ Model = $name; Status = "skipped"; Files = $fileCount; MB = $sizeMB }
        continue
    }

    # Replace: copy to staging, verify, swap, then calibration, then the manifest last.
    $stagingDir = Join-Path $modelsDir_Destination "$name.staging"
    $oldDir = Join-Path $modelsDir_Destination "$name.old"
    try {
        Remove-PathIfPresent $manifestPath
        Remove-PathIfPresent $stagingDir
        Remove-PathIfPresent $oldDir
        foreach ($relativePath in $relativePaths) {
            $path_Destination = Join-Path $stagingDir $relativePath
            New-Item -ItemType Directory -Path (Split-Path $path_Destination -Parent) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $modelDir_Source $relativePath) -Destination $path_Destination -Force -ErrorAction Stop
        }

        $directorySHA256_Copy = Get-DirectorySHA256 $stagingDir
        if ($directorySHA256_Copy -ne $directorySHA256) {
            throw "the copy hashes to $directorySHA256_Copy, the source to $directorySHA256"
        }

        if (Test-Path -LiteralPath $modelDir_Destination) {
            Rename-Item -LiteralPath $modelDir_Destination -NewName "$name.old" -ErrorAction Stop
        }
        Rename-Item -LiteralPath $stagingDir -NewName $name -ErrorAction Stop
        Remove-PathIfPresent $oldDir

        if ($null -ne $calibrationSHA256) {
            Copy-Item -LiteralPath $calibrationPath_Source -Destination $calibrationPath_Destination -Force -ErrorAction Stop
        } else {
            Remove-PathIfPresent $calibrationPath_Destination
        }

        $manifest = [ordered]@{
            name              = $name
            directorySHA256   = $directorySHA256
            calibrationSHA256 = $calibrationSHA256
            sourcePath        = $modelDir_Source
            deployedAt        = (Get-Date).ToString("o")
            files             = $files
        }
        Write-Utf8File $manifestPath ($manifest | ConvertTo-Json -Depth 5)

        Write-Host "Laya model '$name': copied ($directorySHA256$(if ($null -ne $calibrationSHA256) { ', calibrated' }))." -ForegroundColor Green
        $summaries += [pscustomobject]@{ Model = $name; Status = "copied"; Files = $fileCount; MB = $sizeMB }
    } catch {
        Write-Warning "Laya model '$name' was not deployed: $_"
        $summaries += [pscustomobject]@{ Model = $name; Status = "failed"; Files = $fileCount; MB = $sizeMB }
        $failed = $true
    }
}

# Deployed models the source no longer has stay, because a host may depend on them; say so.
$modelNames_Orphaned = @(Get-ChildItem -LiteralPath $modelsDir_Destination -Directory -Force | Where-Object { $_.Name -notlike "*.staging" -and $_.Name -notlike "*.old" -and -not (Test-Path -LiteralPath (Join-Path $modelsDir_Source $_.Name)) } | ForEach-Object { $_.Name })
if ($modelNames_Orphaned) {
    Write-Host "Deployed but not in '$modelsDir_Source' (kept; pass -Remove to delete): $($modelNames_Orphaned -join ', ')" -ForegroundColor Yellow
}

$summaries | Format-Table -AutoSize | Out-Host
if ($removed) {
    Write-Host "Removed: $($removed -join ', ')" -ForegroundColor Cyan
}

if ($failed) {
    exit 1
}
exit 0
