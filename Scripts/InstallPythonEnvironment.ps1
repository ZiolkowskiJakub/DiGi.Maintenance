<#
.SYNOPSIS
    Creates or updates the Python virtual environment DiGi.Laya runs in. Run ON THE HOST, never by Deploy.ps1.

.DESCRIPTION
    DeployLaya.ps1 carries this script and requirements.txt to <SOFTWARE_DIRECTORY>\DiGi.Laya\. On each host:

    1. Creates the virtual environment at -Destination when it does not exist yet.
    2. Upgrades pip, installs torch from the PyTorch CPU or CUDA wheel index (-Torch), then installs
       requirements.txt. requirements.txt sets a floor for torch, not a pin, so the variant is chosen here.
    3. Writes <Destination>\environment.json: the Python version, pip freeze, the SHA-256 of requirements.txt, the
       torch variant, the installed torch version, whether CUDA is available, and a timestamp.
    4. Prints the python.exe path to set as PythonPath in the consumer's conf.

    Re-running with the same requirements.txt and torch variant is a no-op.

    Keep -Destination OUTSIDE the synced software directory: the environment is several GB (the CUDA torch wheels
    alone are about 3 GB), specific to the host's Python, and a file-sync service would carry it to every other
    machine. The Python installation and the environment must be readable and executable by the account of the
    service that runs the consumer (DiGi.WebAPI.WindowsService on the database server).

    pip downloads packages; the Laya processes themselves never download (HF_HUB_OFFLINE / TRANSFORMERS_OFFLINE are
    set by DiGi.Laya).

.PARAMETER PythonPath
    The CPython interpreter (3.10 or newer) the environment is created from.

.PARAMETER RequirementsPath
    requirements.txt, normally <SOFTWARE_DIRECTORY>\DiGi.Laya\requirements.txt as deployed.

.PARAMETER Destination
    The virtual environment directory, outside the synced software directory.

.PARAMETER Torch
    cpu or cuda: the PyTorch wheel index torch is installed from.

.PARAMETER CudaIndexUrl
    The PyTorch CUDA wheel index. Default cu128, which Blackwell GPUs (RTX 50xx) need.
#>
param (
    [Parameter(Mandatory = $true)][string]$PythonPath,
    [Parameter(Mandatory = $true)][string]$RequirementsPath,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][ValidateSet("cpu", "cuda")][string]$Torch,
    [string]$CudaIndexUrl = "https://download.pytorch.org/whl/cu128"
)

$cpuIndexUrl = "https://download.pytorch.org/whl/cpu"

function Invoke-Native([string]$FilePath, [string[]]$Arguments) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host "'$FilePath $($Arguments -join ' ')' failed with exit code $LASTEXITCODE." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
    Write-Host "Python interpreter '$PythonPath' not found." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $RequirementsPath -PathType Leaf)) {
    Write-Host "Requirements file '$RequirementsPath' not found." -ForegroundColor Red
    exit 1
}

$pythonVersion = (& $PythonPath -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($pythonVersion)) {
    Write-Host "'$PythonPath' did not report its version." -ForegroundColor Red
    exit 1
}
if ([version]$pythonVersion -lt [version]"3.10") {
    Write-Host "Python $pythonVersion at '$PythonPath' is older than 3.10." -ForegroundColor Red
    exit 1
}

$Destination = [System.IO.Path]::GetFullPath($Destination)
$venvPythonPath = Join-Path $Destination "Scripts\python.exe"
$environmentPath = Join-Path $Destination "environment.json"
$requirementsSHA256 = (Get-FileHash -LiteralPath $RequirementsPath -Algorithm SHA256).Hash.ToLowerInvariant()

if ((Test-Path -LiteralPath $venvPythonPath) -and (Test-Path -LiteralPath $environmentPath)) {
    try {
        $environment_Existing = Get-Content -LiteralPath $environmentPath -Raw | ConvertFrom-Json
        if ($environment_Existing.requirementsSHA256 -eq $requirementsSHA256 -and $environment_Existing.torch -eq $Torch) {
            Write-Host "Environment '$Destination' is up to date (requirements $requirementsSHA256, torch $Torch) - nothing to do." -ForegroundColor Green
            Write-Host "PythonPath: $venvPythonPath" -ForegroundColor Cyan
            exit 0
        }
    } catch {
        Write-Warning "'$environmentPath' could not be read - the environment is installed again: $_"
    }
}

if (-not (Test-Path -LiteralPath $venvPythonPath)) {
    Write-Host "Creating virtual environment '$Destination' from Python $pythonVersion..." -ForegroundColor Cyan
    Invoke-Native $PythonPath @("-m", "venv", $Destination)
}

# The environment.json of an earlier install no longer describes the environment once pip starts changing it.
if (Test-Path -LiteralPath $environmentPath) {
    Remove-Item -LiteralPath $environmentPath -Force
}

Write-Host "Upgrading pip..." -ForegroundColor Cyan
Invoke-Native $venvPythonPath @("-m", "pip", "install", "--upgrade", "pip")

$torchIndexUrl = if ($Torch -eq "cuda") { $CudaIndexUrl } else { $cpuIndexUrl }
Write-Host "Installing torch ($Torch) from $torchIndexUrl..." -ForegroundColor Cyan
Invoke-Native $venvPythonPath @("-m", "pip", "install", "torch", "--index-url", $torchIndexUrl)

Write-Host "Installing $RequirementsPath..." -ForegroundColor Cyan
Invoke-Native $venvPythonPath @("-m", "pip", "install", "-r", $RequirementsPath)

$freeze = @(& $venvPythonPath -m pip freeze)
$torchInfo = (& $venvPythonPath -c "import torch; print(torch.__version__ + '|' + str(torch.cuda.is_available()))" | Out-String).Trim().Split('|')
$torchVersion = $torchInfo[0]
$cudaAvailable = ($torchInfo.Count -gt 1) -and ($torchInfo[1] -eq "True")

if ($Torch -eq "cuda" -and -not $cudaAvailable) {
    Write-Warning "torch $torchVersion was installed from the CUDA index but reports no usable GPU on this machine."
}

$environment = [ordered]@{
    pythonPath         = $venvPythonPath
    pythonVersion      = $pythonVersion
    requirementsPath   = [System.IO.Path]::GetFullPath($RequirementsPath)
    requirementsSHA256 = $requirementsSHA256
    torch              = $Torch
    torchIndexUrl      = $torchIndexUrl
    torchVersion       = $torchVersion
    cudaAvailable      = $cudaAvailable
    installedAt        = (Get-Date).ToString("o")
    packages           = $freeze
}
[System.IO.File]::WriteAllText($environmentPath, ($environment | ConvertTo-Json -Depth 3), (New-Object System.Text.UTF8Encoding $false))

Write-Host "Environment ready: Python $pythonVersion, torch $torchVersion ($Torch, CUDA available: $cudaAvailable)." -ForegroundColor Green
Write-Host "PythonPath: $venvPythonPath" -ForegroundColor Cyan
exit 0
