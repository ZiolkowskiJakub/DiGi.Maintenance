#### [DiGi\.Maintenance\.UI](index.md 'index')

## DiGi\.Maintenance\.UI Namespace
### Classes

<a name='DiGi.Maintenance.UI.Create'></a>

## Create Class

```csharp
public static class Create
```

Inheritance [System\.Object](https://learn.microsoft.com/en-us/dotnet/api/system.object 'System\.Object') → Create
### Methods

<a name='DiGi.Maintenance.UI.Create.GitHubConfigurationFile()'></a>

## Create\.GitHubConfigurationFile\(\) Method

Creates or loads a [GitHubConfigurationFile\(\)](DiGi.Maintenance.UI.md#DiGi.Maintenance.UI.Create.GitHubConfigurationFile() 'DiGi\.Maintenance\.UI\.Create\.GitHubConfigurationFile\(\)') instance from the executing assembly's directory\.

```csharp
public static DiGi.GitHub.Classes.GitHubConfigurationFile? GitHubConfigurationFile();
```

#### Returns
[DiGi\.GitHub\.Classes\.GitHubConfigurationFile](https://learn.microsoft.com/en-us/dotnet/api/digi.github.classes.githubconfigurationfile 'DiGi\.GitHub\.Classes\.GitHubConfigurationFile')  
The loaded [GitHubConfigurationFile\(\)](DiGi.Maintenance.UI.md#DiGi.Maintenance.UI.Create.GitHubConfigurationFile() 'DiGi\.Maintenance\.UI\.Create\.GitHubConfigurationFile\(\)') instance if successful; otherwise, `null`\.

<a name='DiGi.Maintenance.UI.Modify'></a>

## Modify Class

```csharp
public static class Modify
```

Inheritance [System\.Object](https://learn.microsoft.com/en-us/dotnet/api/system.object 'System\.Object') → Modify
### Methods

<a name='DiGi.Maintenance.UI.Modify.Sync(thisDiGi.GitHub.Classes.GitHubConfigurationFile,DiGi.Maintenance.Classes.Solution,string)'></a>

## Modify\.Sync\(this GitHubConfigurationFile, Solution, string\) Method

Synchronizes the specified solution with a GitHub repository using the provided configuration settings\.

```csharp
public static bool Sync(this DiGi.GitHub.Classes.GitHubConfigurationFile? gitHubConfigurationFile, DiGi.Maintenance.Classes.Solution solution, string? commitMessage=null);
```
#### Parameters

<a name='DiGi.Maintenance.UI.Modify.Sync(thisDiGi.GitHub.Classes.GitHubConfigurationFile,DiGi.Maintenance.Classes.Solution,string).gitHubConfigurationFile'></a>

`gitHubConfigurationFile` [DiGi\.GitHub\.Classes\.GitHubConfigurationFile](https://learn.microsoft.com/en-us/dotnet/api/digi.github.classes.githubconfigurationfile 'DiGi\.GitHub\.Classes\.GitHubConfigurationFile')

The GitHub configuration file containing integration settings\.

<a name='DiGi.Maintenance.UI.Modify.Sync(thisDiGi.GitHub.Classes.GitHubConfigurationFile,DiGi.Maintenance.Classes.Solution,string).solution'></a>

`solution` [DiGi\.Maintenance\.Classes\.Solution](https://learn.microsoft.com/en-us/dotnet/api/digi.maintenance.classes.solution 'DiGi\.Maintenance\.Classes\.Solution')

The solution to be synchronized\.

<a name='DiGi.Maintenance.UI.Modify.Sync(thisDiGi.GitHub.Classes.GitHubConfigurationFile,DiGi.Maintenance.Classes.Solution,string).commitMessage'></a>

`commitMessage` [System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')

An optional commit message to include with the synchronization process\.

#### Returns
[System\.Boolean](https://learn.microsoft.com/en-us/dotnet/api/system.boolean 'System\.Boolean')  
True if the synchronization was successful; otherwise, false\.