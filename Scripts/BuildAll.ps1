param(
    [string]$Root = "$PSScriptRoot\..\..",  # Default to one level above script folder
    [string]$Configuration = "Release",
    [string]$VsMsbuildPath = ""
)

# Resolve the Root path to full absolute path
$Root = Resolve-Path $Root

Write-Host "Using root path: $Root"

# --- MSBuild detection (same as before) ---
if ([string]::IsNullOrWhiteSpace($VsMsbuildPath)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-Not (Test-Path $vswhere)) {
        Write-Host "vswhere.exe not found at $vswhere. Please provide -VsMsbuildPath manually."
        exit 1
    }

    $vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if ([string]::IsNullOrWhiteSpace($vsPath)) {
        Write-Host "Could not find a Visual Studio installation with MSBuild."
        exit 1
    }

    $VsMsbuildPath = Join-Path $vsPath "MSBuild\Current\Bin\MSBuild.exe"
}

if (-Not (Test-Path $VsMsbuildPath)) {
    Write-Host "MSBuild not found at $VsMsbuildPath"
    exit 1
}

Write-Host "Using MSBuild at: $VsMsbuildPath"

# --- Define solution order ---
$solutionOrder = @(
    "DiGi.Core\DiGi.Core.sln",
    "DiGi.BDL\DiGi.BDL.sln",
    "DiGi.EPW\DiGi.EPW.sln",
    "DiGi.GML\DiGi.GML.sln",
    "DiGi.OSM\DiGi.OSM.sln",
    "DiGi.YOLO\DiGi.YOLO.sln",
    "DiGi.Math\DiGi.Math.sln",
    "DiGi.VoTT\DiGi.VoTT.sln",
    "DiGi.Typology\DiGi.Typology.sln",
    "DiGi.Log\DiGi.Log.sln",
    "DiGi.SQLite\DiGi.SQLite.sln",
    "DiGi.Scripting\DiGi.Scripting.sln",
    "DiGi.Scripting.Rhino\DiGi.Scripting.Rhino.sln",
    "DiGi.Translate\DiGi.Translate.sln",
    "DiGi.HttpQuery\DiGi.HttpQuery.sln",
    "DiGi.AssemblyResolver\DiGi.AssemblyResolver.sln",
    "DiGi.Geometry\DiGi.Geometry.sln",
    "DiGi.Geometry.Random\DiGi.Geometry.Random.sln",
    "DiGi.Geometry.Visual\DiGi.Geometry.Visual.sln",
    "DiGi.UI.WPF\DiGi.UI.WPF.sln",
    "DiGi.Emgu.CV\DiGi.Emgu.CV.sln",
    "DiGi.ComputeSharp\DiGi.ComputeSharp.sln",
    "DiGi.ComputeSharp.Rhino\DiGi.ComputeSharp.Rhino.sln",
    "DiGi.Solar\DiGi.Solar.sln",
    "DiGi.Solar.Rhino\DiGi.Solar.Rhino.sln",
    "DiGi.CityGML\DiGi.CityGML.sln",
    "DiGi.BDOT10k\DiGi.BDOT10k.sln",
    "DiGi.BDOT10k.UI\DiGi.BDOT10k.UI.sln",
    "DiGi.Analytical\DiGi.Analytical.sln",
    "DiGi.Analytical.Rhino\DiGi.Analytical.Rhino.sln",
    "DiGi.GIS\DiGi.GIS.sln",
    "DiGi.GIS.Analytical\DiGi.GIS.Analytical.sln",
    "DiGi.GIS.Emgu.CV\DiGi.GIS.Emgu.CV.sln",
    "DiGi.GIS.SQLite\DiGi.GIS.SQLite.sln",
    "DiGi.GIS.ML\DiGi.GIS.ML.sln",
    "DiGi.GIS.Rhino\DiGi.GIS.Rhino.sln",
    "DiGi.GIS.UI\DiGi.GIS.UI.sln",
    "DiGi.Rhino\DiGi.Rhino.sln",
    "DiGi.SAM\DiGi.SAM.sln",
    "DiGi.Tas\DiGi.Tas.sln"
    # add more in the order you need
)

$count = 0

foreach ($relativePath in $solutionOrder) {
    $sln = Join-Path $Root $relativePath

    if (-Not (Test-Path $sln)) {
        Write-Host "Solution not found (skipping): $sln" -ForegroundColor Yellow
        continue
    }

    Write-Host "Building solution: $sln"

    & $VsMsbuildPath $sln /p:Configuration=$Configuration /m:1 /p:VisualStudioVersion=17.0 /verbosity:minimal

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed for $sln" -ForegroundColor Red
        exit $LASTEXITCODE
    }
	
	Write-Host "Building succeeded`n"-ForegroundColor Green
	
	$count = $count + 1
}

$length = $solutionOrder.Count

if ($count -eq $length) {
    Write-Host "$count solutions from $length built successfully.`n" -ForegroundColor Green
} else {
    Write-Host "$count solutions from $length built successfully.`n" -ForegroundColor Yellow
}
