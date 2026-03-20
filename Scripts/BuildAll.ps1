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
	"DiGi.Core\DiGi.Core.slnx",
	"DiGi.User\DiGi.User.slnx",
	"DiGi.BDL\DiGi.BDL.slnx",
	"DiGi.EPW\DiGi.EPW.slnx",
	"DiGi.GML\DiGi.GML.slnx",
	"DiGi.OSM\DiGi.OSM.slnx",
	"DiGi.YOLO\DiGi.YOLO.slnx",
	"DiGi.Math\DiGi.Math.slnx",
	"DiGi.VoTT\DiGi.VoTT.slnx",
	"DiGi.GitHub\DiGi.GitHub.slnx"
	"DiGi.PostgreSQL\DiGi.PostgreSQL.slnx",
	"DiGi.WebAPI\DiGi.WebAPI.slnx"
	"DiGi.User.WebAPI\DiGi.User.WebAPI.slnx",
	"DiGi.Typology\DiGi.Typology.slnx",
	"DiGi.Serilog\DiGi.Serilog.slnx",
	"DiGi.Log\DiGi.Log.slnx",
	"DiGi.SQLite\DiGi.SQLite.slnx",
	"DiGi.Scripting\DiGi.Scripting.slnx",
	"DiGi.Scripting.Rhino\DiGi.Scripting.Rhino.slnx",
	"DiGi.Translate\DiGi.Translate.slnx",
	"DiGi.HttpQuery\DiGi.HttpQuery.slnx",
	"DiGi.AssemblyResolver\DiGi.AssemblyResolver.slnx",
	"DiGi.Geometry\DiGi.Geometry.slnx",
	"DiGi.Geometry.Random\DiGi.Geometry.Random.slnx",
	"DiGi.Geometry.Visual\DiGi.Geometry.Visual.slnx",
	"DiGi.UI.WPF\DiGi.UI.WPF.slnx",
	"DiGi.Emgu.CV\DiGi.Emgu.CV.slnx",
	"DiGi.ComputeSharp\DiGi.ComputeSharp.slnx",
	"DiGi.ComputeSharp.Rhino\DiGi.ComputeSharp.Rhino.slnx",
	"DiGi.Solar\DiGi.Solar.slnx",
	"DiGi.Solar.Rhino\DiGi.Solar.Rhino.slnx",
	"DiGi.CityGML\DiGi.CityGML.slnx",
	"DiGi.BDOT10k\DiGi.BDOT10k.slnx",
	"DiGi.BDOT10k.UI\DiGi.BDOT10k.UI.slnx",
	"DiGi.Analytical\DiGi.Analytical.slnx",
	"DiGi.Analytical.Rhino\DiGi.Analytical.Rhino.slnx",
	"DiGi.GIS\DiGi.GIS.slnx",
	"DiGi.GIS.PostgreSQL\DiGi.GIS.PostgreSQL.slnx",
	"DiGi.GIS.Analytical\DiGi.GIS.Analytical.slnx",
	"DiGi.GIS.Emgu.CV\DiGi.GIS.Emgu.CV.slnx",
	"DiGi.GIS.SQLite\DiGi.GIS.SQLite.slnx",
	"DiGi.GIS.ML\DiGi.GIS.ML.slnx",
	"DiGi.GIS.Rhino\DiGi.GIS.Rhino.slnx",
	"DiGi.GIS.UI\DiGi.GIS.UI.slnx",
	"DiGi.GIS.PostgreSQL.UI\DiGi.GIS.PostgreSQL.UI.slnx"
	"DiGi.Communication\DiGi.Communication.slnx",
	"DiGi.Rhino\DiGi.Rhino.slnx",
	"DiGi.Communication.Rhino\DiGi.Communication.Rhino.slnx",
	"DiGi.SAM\DiGi.SAM.slnx",
	"DiGi.Tas\DiGi.Tas.slnx"
	"DiGi.Maintenance\DiGi.Maintenance.slnx"
	"DiGi.GIS.PostgreSQL.WebAPI\DiGi.GIS.PostgreSQL.WebAPI.slnx"
	"DiGi.WebAPI.WindowsService\DiGi.WebAPI.WindowsService.slnx"
	# add more in the order you need
)

$platform_x64 = @(
	"DiGi.Tas\DiGi.Tas.slnx"
)

$count = 0

foreach ($relativePath in $solutionOrder) 
{
	$sln = Join-Path $Root $relativePath

	if (-Not (Test-Path $sln)) 
	{
		Write-Host "Solution not found (skipping): $slnx" -ForegroundColor Yellow
		continue
	}

	Write-Host "Building solution: $slnx"

	# Determine platform parameter
	if ($platform_x64 -contains $relativePath) 
	{
		$platformParam = "/p:Platform=x64"
	} 
	else 
	{
		$platformParam = ""
	}

	# Build the solution
	& $VsMsbuildPath $sln /p:Configuration=$Configuration $platformParam /m:1 /p:VisualStudioVersion=17.0 /verbosity:minimal

	if ($LASTEXITCODE -ne 0) 
	{
		Write-Host "Build failed for $slnx" -ForegroundColor Red
		exit $LASTEXITCODE
	}
	
	Write-Host "Building succeeded`n"-ForegroundColor Green
	
	$count = $count + 1
}

$length = $solutionOrder.Count

if ($count -eq $length) 
{
	Write-Host "$count solutions from $length built successfully.`n" -ForegroundColor Green
} 
else 
{
	Write-Host "$count solutions from $length built successfully.`n" -ForegroundColor Yellow
}
