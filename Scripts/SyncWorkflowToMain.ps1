# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\SyncWorkflowToMain.ps1

$baseDir = "c:\Users\jakub\GitHub\DigiProject"
$targetDirectories = Get-ChildItem -Path $baseDir -Directory -Filter "DiGi.*"

$targetsContent = @'
<Project>
  <PropertyGroup Condition="'$(IsTestProject)' != 'true' And '$(MSBuildProjectExtension)' == '.csproj'">
    <NoWarn>$(NoWarn);1591</NoWarn>
  </PropertyGroup>

  <ItemGroup Condition="'$(IsTestProject)' != 'true' And '$(MSBuildProjectExtension)' == '.csproj'">
    <PackageReference Include="DefaultDocumentation" Version="1.2.5" PrivateAssets="all" />
  </ItemGroup>

  <PropertyGroup Condition="'$(IsTestProject)' != 'true' And '$(MSBuildProjectExtension)' == '.csproj'">
    <DefaultDocumentationFolder>$(MSBuildThisFileDirectory)documentation\API\$(AssemblyName)</DefaultDocumentationFolder>
    <DefaultDocumentationCleanOutputFolder>true</DefaultDocumentationCleanOutputFolder>
    <DefaultDocumentationGeneratedPages>Namespaces</DefaultDocumentationGeneratedPages>
    <DefaultDocumentationConfigurationFile>$(MSBuildThisFileDirectory)DefaultDocumentation.json</DefaultDocumentationConfigurationFile>
  </PropertyGroup>
</Project>
'@

$jsonContent = @'
{
  "RemoveFileExtensionFromLinks": true
}
'@

$workflowContent = @'
name: Sync API Docs to Wiki

on: [push]

jobs:
  build-and-sync:
    runs-on: windows-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build and Generate Docs (Always Runs)
        run: dotnet build --configuration Release

      # Gracefully attempt to check out DiGi.Maintenance for scripts
      - name: Try checkout DiGi.Maintenance
        id: checkout-maintenance
        uses: actions/checkout@v4
        continue-on-error: true
        with:
          repository: ZiolkowskiJakub/DiGi.Maintenance
          path: DiGi.Maintenance

      # Only run sync script if DiGi.Maintenance was successfully checked out
      # AND we are on master/main branch
      - name: Run Wiki Sync Script (Conditional)
        if: steps.checkout-maintenance.outcome == 'success' && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master')
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        shell: pwsh
        run: |
          if (Test-Path ./DiGi.Maintenance/Scripts/SyncWiki.ps1) {
            ./DiGi.Maintenance/Scripts/SyncWiki.ps1 -RepoPath ${{ github.workspace }}
          } else {
            Write-Host "Sync script not found, skipping wiki push."
          }
'@

foreach ($dir in $targetDirectories) {
    $dirName = $dir.Name
    $dirPath = $dir.FullName
    
    if (-not (Test-Path (Join-Path $dirPath ".git"))) {
        continue
    }
    
    Push-Location $dirPath
    
    # Get current branch to return to it later
    $activeBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    
    Write-Host "Processing $($dirName) (Active: $activeBranch)" -ForegroundColor Cyan
    
    # 1. Checkout main and update it
    git checkout main | Out-Null
    git pull origin main | Out-Null
    
    # Skip DiGi.Maintenance custom workflow, but still apply targets/json
    if ($dirName -ne "DiGi.Maintenance") {
        # Write Directory.Build.targets
        $targetsPath = Join-Path $dirPath "Directory.Build.targets"
        Set-Content -Path $targetsPath -Value $targetsContent -Force
        
        # Write DefaultDocumentation.json
        $jsonPath = Join-Path $dirPath "DefaultDocumentation.json"
        Set-Content -Path $jsonPath -Value $jsonContent -Force
        
        # Write GitHub Actions Workflow file
        $workflowDir = Join-Path $dirPath ".github\workflows"
        if (-not (Test-Path $workflowDir)) {
            New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
        }
        $workflowPath = Join-Path $workflowDir "sync-wiki.yml"
        Set-Content -Path $workflowPath -Value $workflowContent -Force
    }
    
    # 2. Check for changes in main
    $status = git status --porcelain
    if ($status) {
        Write-Host "Committing workflow changes to main in: $($dirName)" -ForegroundColor Green
        git add .
        git commit -m "chore: update documentation workflow and build targets"
        git push origin main
    } else {
        Write-Host "Main is already up-to-date in: $($dirName)" -ForegroundColor Yellow
    }
    
    # 3. Return to active branch
    git checkout $activeBranch | Out-Null
    
    Pop-Location
}

Write-Host "All main branch syncs completed!" -ForegroundColor Green
