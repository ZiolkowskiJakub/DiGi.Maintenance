# C:\Users\jakub\GitHub\DigiProject\DiGi.Maintenance\Scripts\ApplyDocumentationSetup.ps1

$baseDir = (Resolve-Path "$PSScriptRoot\..\..").Path
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
    <!-- Without this, multi-namespace assemblies fall back to the generic "index" page name; when a repo has
         more than one assembly, every assembly's index.md collides in the GitHub wiki's flat page sidebar. -->
    <DefaultDocumentationAssemblyPageName>$(AssemblyName).Overview</DefaultDocumentationAssemblyPageName>
  </PropertyGroup>
</Project>
'@

$jsonContent = @'
{
  "LogLevel": "Warning",
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
          GITHUB_TOKEN: ${{ secrets.WIKI_SYNC_PAT || secrets.GITHUB_TOKEN }}
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
    
    # Skip DiGi.Maintenance as it has a custom direct workflow already set up
    if ($dirName -eq "DiGi.Maintenance") {
        Write-Host "Skipping $dirName (already configured custom workflow)" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Applying documentation setup to: $dirName" -ForegroundColor Cyan
    
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

Write-Host "All repository setups completed!" -ForegroundColor Green
