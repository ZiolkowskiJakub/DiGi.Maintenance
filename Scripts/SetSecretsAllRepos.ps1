#Requires -Version 7
<#
.SYNOPSIS
    Sets the WIKI_SYNC_PAT Actions secret once, at organization level, for every DiGi repository.

.DESCRIPTION
    The sync-wiki.yml workflow of every DiGi repository pushes the generated API pages to the repository's
    wiki with ${{ secrets.WIKI_SYNC_PAT || secrets.GITHUB_TOKEN }}. GITHUB_TOKEN cannot push to a wiki
    ("Permission ... denied to github-actions[bot]"), so the secret is required. Since 2026-10-14 it is a
    single organization secret (visibility: all) instead of one copy per repository, so a new repository
    needs nothing and a renewed token is set in one place.

    The token is a classic personal access token with the public_repo scope (every DiGi repository with a
    wiki is public; on GitHub Free an organization secret does not reach private repositories anyway).
    It is checked against the GitHub API before it is stored: a token that GitHub does not accept fails
    every wiki push with "Invalid username or token", which is easy to cause by pasting a partial value.

    Requires the GitHub CLI authenticated with the admin:org scope:
        gh auth refresh -h github.com -s admin:org

.PARAMETER Organization
    Organization that owns the secret. Default: DiGi-Organization.

.PARAMETER FromClipboard
    Reads the token from the clipboard instead of prompting for it. Either way the token never appears
    on the command line or in the command history.

.PARAMETER RemoveRepositorySecrets
    Also deletes any repository-level WIKI_SYNC_PAT in the organization. A repository secret overrides the
    organization one, so a stale copy would keep failing after the organization secret is renewed.

.EXAMPLE
    .\SetSecretsAllRepos.ps1 -FromClipboard
    .\SetSecretsAllRepos.ps1 -RemoveRepositorySecrets
#>
param(
    [string]$Organization = "DiGi-Organization",
    [switch]$FromClipboard,
    [switch]$RemoveRepositorySecrets
)

$ErrorActionPreference = "Stop"
$secretName = "WIKI_SYNC_PAT"

if ($FromClipboard) {
    $token = (Get-Clipboard -Raw)
}
else {
    $secureToken = Read-Host "Personal access token (classic, public_repo)" -AsSecureString
    $token = [System.Net.NetworkCredential]::new("", $secureToken).Password
}
$token = "$token".Trim()

# Check the token before storing it
$response = Invoke-WebRequest -Uri "https://api.github.com/user" -Headers @{ Authorization = "token $token" } -SkipHttpErrorCheck
$scopes = "$($response.Headers['X-OAuth-Scopes'])"
Write-Host "Token check: HTTP $($response.StatusCode), length $($token.Length), scopes '$scopes'"
if ($response.StatusCode -ne 200) {
    Write-Host "GitHub did not accept the token - nothing was changed. Copy it again (a classic token is 40 characters, ghp_...)." -ForegroundColor Red
    exit 1
}
if ($scopes -notmatch '(^|,\s*)(public_repo|repo)(\s*,|$)') {
    Write-Host "The token has neither the public_repo nor the repo scope, so it cannot push to a wiki - nothing was changed." -ForegroundColor Red
    exit 1
}

gh secret set $secretName --org $Organization --visibility all --body $token
$exitCode = $LASTEXITCODE
Remove-Variable token
if ($exitCode -ne 0) {
    Write-Host "Setting the organization secret failed (does the GitHub CLI have the admin:org scope?)." -ForegroundColor Red
    exit $exitCode
}
Write-Host "[SUCCESS] $secretName set for organization $Organization (visibility: all)." -ForegroundColor Green

if ($RemoveRepositorySecrets) {
    $repositoryNames = gh repo list $Organization --limit 1000 --json name --jq '.[].name'
    foreach ($repositoryName in $repositoryNames) {
        $repositoryIdentifier = "$Organization/$repositoryName"
        $count = gh secret list --repo $repositoryIdentifier --json name --jq "map(select(.name == `"$secretName`")) | length"
        if ($count -ne "1") { continue }

        gh secret delete $secretName --repo $repositoryIdentifier
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Removed the repository-level $secretName from $repositoryIdentifier" -ForegroundColor Cyan
        }
        else {
            Write-Warning "Could not remove the repository-level $secretName from $repositoryIdentifier"
        }
    }
}
