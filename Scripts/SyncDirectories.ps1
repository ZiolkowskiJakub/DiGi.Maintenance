# Define a list of folder pairs using an array of hashtables
$SyncList = @(
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.GIS.PostgreSQL.UI\bin";       Destination = "D:\Nextcloud\Work\DigiProject\Software\DiGi.GIS.PostgreSQL.UI" },
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.GIS.UI\bin";                  Destination = "D:\Nextcloud\Work\DigiProject\Software\DiGi.GIS.UI" },
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.GIS.PostgreSQL.WebAPI\bin";  Destination = "C:\Users\jakub\GitHub\DigiProject\DiGi.WebAPI.WindowsService\bin\extensions\gis" },
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.WebAPI.WindowsService\bin";  Destination = "D:\Nextcloud\Work\DigiProject\Software\DiGi.WebAPI.WindowsService" }
)

Write-Host "Starting batch synchronization process..." -ForegroundColor Cyan
Write-Host "==========================================="

# Get the absolute path to the helper script in the same directory
$HelperScript = Join-Path -Path $PSScriptRoot -ChildPath "SyncDirectory.ps1"

# Check if the helper script actually exists before starting the loop
if (-not (Test-Path $HelperScript)) {
    Write-Error "Critical Error: '$HelperScript' not found! Make sure both scripts are in the same folder."
    exit
}

foreach ($Pair in $SyncList) {
    Write-Host "Processing: $($Pair.Source) -> $($Pair.Destination)" -ForegroundColor White
    
    # Execute the sync script using the call operator (&) and the full path
    & $HelperScript -Source $Pair.Source -Destination $Pair.Destination
    
    Write-Host "-------------------------------------------"
}

Write-Host "All tasks completed." -ForegroundColor Yellow