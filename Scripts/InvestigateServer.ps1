<#
.SYNOPSIS
    Queries and displays remote diagnostic, version, route catalog, and system telemetry from a DiGi WebAPI host.

.DESCRIPTION
    Provides a token-optimized interface for AI models and developers to investigate live, staging, or local DiGi
    WebAPI servers (e.g. 'https://api.digiproject.uk' or 'https://localhost:5001') via InformationController endpoints.

.PARAMETER HostUri
    The base URI of the WebAPI host to investigate (default: 'https://api.digiproject.uk').

.PARAMETER Key
    Optional diagnostic API key to access protected telemetry (/system, /assemblies, /controllers, internal /endpoints
    and the commit hashes on /version). Sent as the 'key' request header, never as a query parameter.
    When omitted, it is read from 'user files/WebAPI_Diagnostics.conf' if that file exists.

.PARAMETER Health
    Queries GET /information/health (liveness probe, server time, process ID, uptime).

.PARAMETER Version
    Queries GET /information/version (service version, git commits, CLR runtime, framework description).

.PARAMETER Endpoints
    Queries GET /information/endpoints (route catalog, HTTP verbs, parameter contracts).

.PARAMETER Controller
    Optional controller filter when querying endpoints (e.g. -Controller "Terrain").

.PARAMETER IncludeIgnored
    When querying endpoints, includes internal/write endpoints marked with [ApiExplorerSettings(IgnoreApi = true)].

.PARAMETER Controllers
    Queries GET /information/controllers (registered controllers, assembly metadata, action counts, route prefixes).
    Protected: requires a key.

.PARAMETER Assemblies
    Queries GET /information/assemblies (all loaded assemblies in AssemblyLoadContext).

.PARAMETER System
    Queries GET /information/system (host memory, GC collections, thread pool available threads, OS version).

.PARAMETER All
    Queries all diagnostic areas and displays a comprehensive health and operational summary.

.PARAMETER Json
    Outputs raw or structured JSON instead of human/AI-readable text.

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File ".\InvestigateServer.ps1" -Health

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File ".\InvestigateServer.ps1" -All

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File ".\InvestigateServer.ps1" -Endpoints -Controller "Terrain" -IncludeIgnored
#>
[CmdletBinding(PositionalBinding = $false)]
param (
    [string]$HostUri = "https://api.digiproject.uk",

    [string]$Key,

    [switch]$Health,

    [switch]$Version,

    [switch]$Endpoints,

    [string]$Controller,

    [switch]$IncludeIgnored,

    [switch]$Controllers,

    [switch]$Assemblies,

    [switch]$System,

    [switch]$All,

    [switch]$Json
)

$ErrorActionPreference = "Stop"

# Normalize base URI
$baseUri = $HostUri.TrimEnd('/')

# Fall back to the local configuration file so the secret does not have to be typed on the
# command line, where it would land in PSReadLine history.
if (-not $Key) {
    $keyConfPath = Join-Path $PSScriptRoot "..\user files\WebAPI_Diagnostics.conf"
    if (Test-Path $keyConfPath) {
        foreach ($line in Get-Content $keyConfPath) {
            if ($line -match '^\s*Key\s*=\s*"?([^"]*)"?\s*$') {
                if ($Matches[1]) {
                    $Key = $Matches[1]
                    Write-Host "Using diagnostic key from 'user files/WebAPI_Diagnostics.conf'." -ForegroundColor DarkGray
                }
                break
            }
        }
    }
}

# Certificate validation is only relaxed for loopback hosts running a development certificate.
# Never skip it against a remote host: the diagnostic key travels in a request header.
$isLoopback = $baseUri -match '^https?://(localhost|127\.0\.0\.1|\[::1\])(:|/|$)'

function Invoke-DiagnosticGet {
    param (
        [string]$Path
    )

    $targetPath = $Path.TrimStart('/')
    $targetUrl = "$baseUri/$targetPath"

    $arguments = @('-s')
    if ($isLoopback) {
        $arguments += '-k'
    }
    if ($Key) {
        # The key is sent as a request header, never as a query parameter: query strings are
        # written to server access logs, browser history and Referer headers.
        $arguments += @('-H', "key: $Key")
    }
    $arguments += $targetUrl

    try {
        $response = & curl.exe @arguments
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $null
        }
        return $response
    } catch {
        Write-Error "Failed to reach $targetUrl : $_"
        return $null
    }
}

# If no specific switch was passed, default to -All
if (-not ($Health -or $Version -or $Endpoints -or $Controllers -or $Assemblies -or $System -or $All)) {
    $All = $true
}

$results = [ordered]@{}

# 1. Health
if ($Health -or $All) {
    $raw = Invoke-DiagnosticGet -Path "information/health"
    if ($raw) {
        try {
            $parsed = $raw | ConvertFrom-Json
            $results["Health"] = $parsed
        } catch {
            $results["Health"] = $raw
        }
    }
}

# 2. Version
if ($Version -or $All) {
    $raw = Invoke-DiagnosticGet -Path "information/version"
    if ($raw) {
        try {
            $parsed = $raw | ConvertFrom-Json
            $results["Version"] = $parsed
        } catch {
            $results["Version"] = $raw
        }
    }
}

# 3. System
if ($System -or $All) {
    $raw = Invoke-DiagnosticGet -Path "information/system"
    if ($raw) {
        try {
            $parsed = $raw | ConvertFrom-Json
            $results["System"] = $parsed
        } catch {
            $results["System"] = $raw
        }
    }
}

# 4. Controllers
if ($Controllers -or $All) {
    $raw = Invoke-DiagnosticGet -Path "information/controllers"
    if ($raw) {
        try {
            $parsed = $raw | ConvertFrom-Json
            $results["Controllers"] = $parsed
        } catch {
            $results["Controllers"] = $raw
        }
    }
}

# 5. Assemblies
if ($Assemblies) {
    $raw = Invoke-DiagnosticGet -Path "information/assemblies"
    if ($raw) {
        try {
            $parsed = $raw | ConvertFrom-Json
            $results["Assemblies"] = $parsed
        } catch {
            $results["Assemblies"] = $raw
        }
    }
}

# 6. Endpoints
if ($Endpoints) {
    $path = "information/endpoints"
    $queryParts = @()
    if ($Controller) {
        $queryParts += "controller=$Controller"
    }
    if ($IncludeIgnored) {
        $queryParts += "includeignored=true"
    }
    if ($queryParts.Count -gt 0) {
        $path += "?" + ($queryParts -join '&')
    }

    $raw = Invoke-DiagnosticGet -Path $path
    if ($raw) {
        try {
            $parsed = $raw | ConvertFrom-Json
            $results["Endpoints"] = $parsed
        } catch {
            $results["Endpoints"] = $raw
        }
    }
}

# Output format handling
if ($Json) {
    $results | ConvertTo-Json -Depth 6
    exit 0
}

# Formatted Token-Efficient Display for AI & Developers
Write-Host "`n=== Server Diagnostics: $baseUri ===`n" -ForegroundColor Cyan

if ($results.Contains("Health")) {
    $h = $results["Health"]
    Write-Host "[Health]" -ForegroundColor Green
    if ($h -is [PSCustomObject]) {
        Write-Host "  Status:      $($h.Status)" -ForegroundColor White
        Write-Host "  UTC Time:    $($h.ServerTimeUtc)" -ForegroundColor DarkGray
        Write-Host "  Local Time:  $($h.ServerTimeLocal)" -ForegroundColor DarkGray
        Write-Host "  Uptime:      $($h.Uptime)" -ForegroundColor White
        Write-Host "  Process ID:  $($h.ProcessId)" -ForegroundColor DarkGray
    } else {
        Write-Host "  $h"
    }
    Write-Host ""
}

if ($results.Contains("Version")) {
    $v = $results["Version"]
    Write-Host "[Version & Runtime]" -ForegroundColor Green
    if ($v -is [PSCustomObject]) {
        Write-Host "  Service:     $($v.ServiceVersion) ($($v.ServiceInformationalVersion))" -ForegroundColor White
        Write-Host "  WebAPI:      $($v.WebAPIVersion) ($($v.WebAPIInformationalVersion))" -ForegroundColor White
        Write-Host "  .NET CLR:    $($v.RuntimeVersion) ($($v.FrameworkDescription))" -ForegroundColor DarkGray
        Write-Host "  Started:     $($v.StartTimeUtc)" -ForegroundColor DarkGray
    } else {
        Write-Host "  $v"
    }
    Write-Host ""
}

if ($results.Contains("System")) {
    $s = $results["System"]
    Write-Host "[Host & Resources]" -ForegroundColor Green
    if ($s -is [PSCustomObject]) {
        $wsMb = [math]::Round($s.MemoryWorkingSetBytes / (1024 * 1024), 2)
        $gcMb = [math]::Round($s.GCTotalMemoryBytes / (1024 * 1024), 2)
        Write-Host "  Environment: $($s.EnvironmentName)" -ForegroundColor White
        Write-Host "  OS/Arch:     $($s.OSVersion) ($($s.ProcessArchitecture), $($s.ProcessorCount) cores)" -ForegroundColor DarkGray
        Write-Host "  Memory:      WorkingSet: ${wsMb} MB | GC Heap: ${gcMb} MB" -ForegroundColor White
        Write-Host "  GC Sweeps:   Gen0: $($s.GCCollectionsGen0) | Gen1: $($s.GCCollectionsGen1) | Gen2: $($s.GCCollectionsGen2)" -ForegroundColor DarkGray
        Write-Host "  ThreadPool:  Workers: $($s.ThreadPoolAvailableWorkerThreads) | IO Completion: $($s.ThreadPoolAvailableCompletionPortThreads)" -ForegroundColor DarkGray
    } else {
        Write-Host "  $s"
    }
    Write-Host ""
}

if ($results.Contains("Controllers")) {
    $ctrls = $results["Controllers"]
    Write-Host "[Deployed Controllers ($($ctrls.Count))]" -ForegroundColor Green
    if ($ctrls -is [System.Array]) {
        foreach ($c in $ctrls) {
            $prefix = if ($c.RoutePrefix) { " [Route: $($c.RoutePrefix)]" } else { "" }
            $actions = if ($c.ActionCount -gt 0) { " ($($c.ActionCount) actions)" } else { "" }
            Write-Host "  $($c.Name)" -NoNewline -ForegroundColor White
            Write-Host " -> $($c.AssemblyName) $($c.Version)$actions$prefix" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($results.Contains("Assemblies")) {
    $asms = $results["Assemblies"]
    Write-Host "[Loaded Assemblies ($($asms.Count))]" -ForegroundColor Green
    if ($asms -is [System.Array]) {
        foreach ($a in $asms) {
            Write-Host "  $($a.Name)" -NoNewline -ForegroundColor White
            Write-Host " $($a.Version) ($($a.InformationalVersion))" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($results.Contains("Endpoints")) {
    $eps = $results["Endpoints"]
    Write-Host "[Endpoint Catalog ($($eps.Count))]" -ForegroundColor Green
    if ($eps -is [System.Array]) {
        foreach ($e in $eps) {
            $verbs = if ($e.HttpMethods) { "[$($e.HttpMethods -join ',')]" } else { "[ANY]" }
            $ignored = if ($e.IsApiIgnored) { " (Ignored/Hidden)" } else { "" }
            Write-Host "  $verbs " -NoNewline -ForegroundColor Yellow
            Write-Host "$($e.RouteTemplate)" -NoNewline -ForegroundColor White
            Write-Host " -> $($e.ControllerName).$($e.ActionName)$ignored" -ForegroundColor DarkGray

            if ($e.Parameters -and $e.Parameters.Count -gt 0) {
                $paramList = @()
                foreach ($p in $e.Parameters) {
                    $opt = if ($p.IsNullable -or $p.HasDefaultValue) { "?" } else { "" }
                    $paramList += "$($p.Name): $($p.TypeName)$opt [$($p.Source)]"
                }
                Write-Host "      Params: $($paramList -join ', ')" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
}
