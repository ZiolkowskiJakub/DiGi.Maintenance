#### [DiGi\.Maintenance](index.md 'index')

## DiGi\.Maintenance Namespace
### Classes

<a name='DiGi.Maintenance.Create'></a>

## Create Class

```csharp
public static class Create
```

Inheritance [System\.Object](https://learn.microsoft.com/en-us/dotnet/api/system.object 'System\.Object') → Create
### Methods

<a name='DiGi.Maintenance.Create.MaintenanceConfigurationFile()'></a>

## Create\.MaintenanceConfigurationFile\(\) Method

Creates and initializes a [MaintenanceConfigurationFile\(\)](DiGi.Maintenance.md#DiGi.Maintenance.Create.MaintenanceConfigurationFile() 'DiGi\.Maintenance\.Create\.MaintenanceConfigurationFile\(\)') by loading settings from the default configuration file located in the application's execution directory\.

```csharp
public static DiGi.Maintenance.Classes.MaintenanceConfigurationFile? MaintenanceConfigurationFile();
```

#### Returns
[MaintenanceConfigurationFile](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.MaintenanceConfigurationFile 'DiGi\.Maintenance\.Classes\.MaintenanceConfigurationFile')  
A new instance of [MaintenanceConfigurationFile\(\)](DiGi.Maintenance.md#DiGi.Maintenance.Create.MaintenanceConfigurationFile() 'DiGi\.Maintenance\.Create\.MaintenanceConfigurationFile\(\)') if successful; otherwise, `null` if the execution directory cannot be determined\.

<a name='DiGi.Maintenance.Create.Solution(string)'></a>

## Create\.Solution\(string\) Method

Creates a [Solution\(string\)](DiGi.Maintenance.md#DiGi.Maintenance.Create.Solution(string) 'DiGi\.Maintenance\.Create\.Solution\(string\)') instance based on the provided file path, attempting to resolve versioning from a 'Directory\.Build\.props' file in the same directory\.

```csharp
public static DiGi.Maintenance.Classes.Solution? Solution(string? path);
```
#### Parameters

<a name='DiGi.Maintenance.Create.Solution(string).path'></a>

`path` [System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')

The path to the solution file\.

#### Returns
[Solution](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.Solution 'DiGi\.Maintenance\.Classes\.Solution')  
A new [Solution\(string\)](DiGi.Maintenance.md#DiGi.Maintenance.Create.Solution(string) 'DiGi\.Maintenance\.Create\.Solution\(string\)') object if the path is valid and the file exists; otherwise, null\.

<a name='DiGi.Maintenance.Create.Solutions(string)'></a>

## Create\.Solutions\(string\) Method

Retrieves a list of solution files from the specified directory\.

```csharp
public static System.Collections.Generic.List<DiGi.Maintenance.Classes.Solution>? Solutions(string? directory);
```
#### Parameters

<a name='DiGi.Maintenance.Create.Solutions(string).directory'></a>

`directory` [System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')

The path to the directory to search for \.sln files\.

#### Returns
[System\.Collections\.Generic\.List&lt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1 'System\.Collections\.Generic\.List\`1')[Solution](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.Solution 'DiGi\.Maintenance\.Classes\.Solution')[&gt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1 'System\.Collections\.Generic\.List\`1')  
A list of [Solution\(string\)](DiGi.Maintenance.md#DiGi.Maintenance.Create.Solution(string) 'DiGi\.Maintenance\.Create\.Solution\(string\)') objects found in the directory, or null if the directory is invalid or does not exist\.

<a name='DiGi.Maintenance.Modify'></a>

## Modify Class

```csharp
public static class Modify
```

Inheritance [System\.Object](https://learn.microsoft.com/en-us/dotnet/api/system.object 'System\.Object') → Modify
### Methods

<a name='DiGi.Maintenance.Modify.CleanDirectories(thisstring)'></a>

## Modify\.CleanDirectories\(this string\) Method

Recursively removes empty directories within the specified root directory\.

```csharp
public static System.Collections.Generic.HashSet<string>? CleanDirectories(this string directory);
```
#### Parameters

<a name='DiGi.Maintenance.Modify.CleanDirectories(thisstring).directory'></a>

`directory` [System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')

The path to the root directory to clean\.

#### Returns
[System\.Collections\.Generic\.HashSet&lt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.hashset-1 'System\.Collections\.Generic\.HashSet\`1')[System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')[&gt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.hashset-1 'System\.Collections\.Generic\.HashSet\`1')  
A [System\.Collections\.Generic\.HashSet&lt;&gt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.hashset-1 'System\.Collections\.Generic\.HashSet\`1') containing the paths of the deleted directories, or `null` if the input directory is invalid or no empty directories were found\.

<a name='DiGi.Maintenance.Modify.Write(thisDiGi.Maintenance.Classes.MaintenanceConfigurationFile)'></a>

## Modify\.Write\(this MaintenanceConfigurationFile\) Method

Writes the specified maintenance configuration file to the default configuration path relative to the executing assembly\.

```csharp
public static bool Write(this DiGi.Maintenance.Classes.MaintenanceConfigurationFile maintenanceConfigurationFile);
```
#### Parameters

<a name='DiGi.Maintenance.Modify.Write(thisDiGi.Maintenance.Classes.MaintenanceConfigurationFile).maintenanceConfigurationFile'></a>

`maintenanceConfigurationFile` [MaintenanceConfigurationFile](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.MaintenanceConfigurationFile 'DiGi\.Maintenance\.Classes\.MaintenanceConfigurationFile')

The maintenance configuration file instance to write\.

#### Returns
[System\.Boolean](https://learn.microsoft.com/en-us/dotnet/api/system.boolean 'System\.Boolean')  
True if the operation was successful; otherwise, false\.

<a name='DiGi.Maintenance.Modify.Write(thisDiGi.Maintenance.Classes.Solution)'></a>

## Modify\.Write\(this Solution\) Method

Writes the version information of the specified solution to the Directory\.Build\.props file\.

```csharp
public static bool Write(this DiGi.Maintenance.Classes.Solution solution);
```
#### Parameters

<a name='DiGi.Maintenance.Modify.Write(thisDiGi.Maintenance.Classes.Solution).solution'></a>

`solution` [Solution](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.Solution 'DiGi\.Maintenance\.Classes\.Solution')

The solution instance whose version is to be written\.

#### Returns
[System\.Boolean](https://learn.microsoft.com/en-us/dotnet/api/system.boolean 'System\.Boolean')  
True if the operation was successful; otherwise, false\.