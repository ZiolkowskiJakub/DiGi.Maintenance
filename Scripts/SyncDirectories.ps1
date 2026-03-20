# Define a list of folder pairs using an array of hashtables
$SyncList = @(
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.GIS.PostgreSQL.UI\bin"; Destination = "D:\Nextcloud\Work\DigiProject\Software\DiGi.GIS.PostgreSQL.UI" },
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.GIS.UI\bin"; Destination = "D:\Nextcloud\Work\DigiProject\Software\DiGi.GIS.UI" },
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.GIS.PostgreSQL.WebAPI\bin"; Destination = "C:\Users\jakub\GitHub\DigiProject\DiGi.WebAPI.WindowsService\bin\extensions\gis" },
    @{ Source = "C:\Users\jakub\GitHub\DigiProject\DiGi.WebAPI.WindowsService\bin"; Destination = "D:\Nextcloud\Work\DigiProject\Software\DiGi.WebAPI.WindowsService" }
)

Write-Host "Starting batch synchronization process..." -ForegroundColor Cyan
Write-Host "==========================================="

foreach ($Pair in $SyncList) {
    Write-Host "Processing: $($Pair.Source) -> $($Pair.Destination)" -ForegroundColor White
    
    # Execute the sync script for each pair
    .\SyncDirectory.ps1 -Source $Pair.Source -Destination $Pair.Destination
    
    Write-Host "-------------------------------------------"
}

Write-Host "All tasks completed." -ForegroundColor Yellow