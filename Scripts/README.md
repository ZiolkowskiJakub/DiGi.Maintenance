# DiGi Maintenance Scripts

This directory contains PowerShell maintenance scripts for managing, building, synchronizing, and setting up DiGi solution repositories.

## Configuration

Configuration settings for maintenance scripts are stored in relative configuration files under the `user files/` directory:

### `user files/Directories.conf`
Copy `files/Directories.conf` to `user files/Directories.conf` and configure the target path variables:
- `SOFTWARE_DIRECTORY`: Target directory for software output binary synchronization (used by `SyncDirectories.ps1`).
- `USER_FILES_BACKUP_DIRECTORY`: Target directory for copying and restoring repository `user files` folders (used by `CopyUserFiles.ps1`).
- `GLOBAL_AGENTS_FILE`: Path to a machine-global `AGENTS.md` outside the workspace, refreshed from the AI Guidelines by `UpdateAgents.ps1`. Leave empty to skip that step.

---

## Execution Commands

### Build All Solutions
Builds all DiGi solution repositories in Release configuration. Pass `-CheckDependencies` to run
`CheckHostDependencies.ps1` against the produced output once every solution has built, failing when
a host is missing an assembly its libraries reference.
```powershell
PowerShell -NoProfile -ExecutionPolicy Bypass -File ".\BuildAll.ps1" -Configuration Release

# Build, then audit the host outputs for unresolvable assembly references
PowerShell -NoProfile -ExecutionPolicy Bypass -File ".\BuildAll.ps1" -Configuration Release -CheckDependencies
```

### Check Host Dependencies
Audits the build output of every deployed host for assembly references that cannot be resolved at
runtime. DiGi repositories reference each other by `HintPath`, which is opaque to NuGet, so a
library's transitive NuGet dependencies never reach a host that consumes it that way — the host
builds clean, the tests pass, and the assembly is missing only at runtime, usually as a *partial
result* rather than an error. Requires a prior build; reviewed exceptions are declared per unit
inside the script. `DiGi.WebAPI.WindowsService` is audited together with `bin\extensions\*`, because
they share one probing set.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\CheckHostDependencies.ps1"

# Audit a single deployment unit
PowerShell -ExecutionPolicy Bypass -File ".\CheckHostDependencies.ps1" -Unit "DiGi.GIS.WebAPI.UI"

# Exit with code 1 when a gap is found (for use in automation)
PowerShell -ExecutionPolicy Bypass -File ".\CheckHostDependencies.ps1" -FailOnMissing
```

### Sync Output Directories
Synchronizes output binary directories across web services and the configured software output directory (`SOFTWARE_DIRECTORY` in `user files/Directories.conf`).
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\SyncDirectories.ps1"
```

### Copy User Files
Copies `user files` configuration folders from all DiGi repositories to the backup data directory (`USER_FILES_BACKUP_DIRECTORY` in `user files/Directories.conf`), excluding `reports` folders, or restores from the backup directory back to matching repositories when `-Reverse` or `-Restore` is specified.
```powershell
# Copy user files to backup directory
PowerShell -ExecutionPolicy Bypass -File ".\CopyUserFiles.ps1"

# Restore user files from backup directory to workspace
PowerShell -ExecutionPolicy Bypass -File ".\CopyUserFiles.ps1" -Reverse

# Override backup directory explicitly via parameter
PowerShell -ExecutionPolicy Bypass -File ".\CopyUserFiles.ps1" -Destination "<PathToBackupDirectory>"
```

### Pull Branches Across All Repositories
Synchronizes all DiGi repositories to their highest SemVer branch and pulls remote changes.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\PullBranchesAllRepos.ps1"
```

### Sync Branches Across All Repositories
Merges active version branch to main, bumps patch version, creates a new branch, and pushes across all repositories.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\SyncBranchesAllRepos.ps1"
```

### Commit All Repositories
Commits pending changes across all DiGi repositories.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\CommitAllRepos.ps1" -Message "Update"
```

### Push All Repositories
Pushes commits across all DiGi repositories.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\PushAllRepos.ps1"
```

### Commit and Push Current Branch
Commits and pushes current branch across all DiGi repositories.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\CommitAndPushCurrentBranch.ps1" -Message "Update"
```

### Sync Wiki
Synchronizes local documentation and Wiki pages with GitHub wikis.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\SyncWiki.ps1"
```

### Check Wiki Pages
Verifies and checks structure of GitHub wiki pages.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\CheckWikiPages.ps1"
```

### Update AI Agents & Guidelines
Regenerates `.agents/AGENTS.md` and `.agents/skills/*/SKILL.md` across all DiGi repositories from `DiGi.Maintenance/documentation/AI Guidelines`, and refreshes the machine-global `AGENTS.md` when `GLOBAL_AGENTS_FILE` is configured. Changes are committed per repository unless `-NoCommit` is passed.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\UpdateAgents.ps1"

# Update the files without creating commits
PowerShell -ExecutionPolicy Bypass -File ".\UpdateAgents.ps1" -NoCommit
```

### Update Solution READMEs
Replaces the shared `## 💻 Coding Guidelines for Developers & AI Agents` block at the end of every `DiGi.*/README.md` with the canonical block from `files/README - Coding Guidelines.md`, preserving the repository-specific content above it. Changes are committed per repository unless `-NoCommit` is passed.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\UpdateReadmes.ps1"

# Update the files without creating commits
PowerShell -ExecutionPolicy Bypass -File ".\UpdateReadmes.ps1" -NoCommit
```

### Set Secrets Across All Repositories
Sets secret (e.g. `WIKI_SYNC_PAT`) across all GitHub repositories.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\SetSecretsAllRepos.ps1" -PatToken "<PAT_TOKEN>"
```

### Sync GitHub Workflows to Main
Synchronizes GitHub Actions workflows to `main` branch across all repositories.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\SyncWorkflowToMain.ps1"
```

### Apply Documentation Setup
Applies XML documentation build targets to project files.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\ApplyDocumentationSetup.ps1"
```

### Filter GitHub Issues by Labels
Searches, filters, and inspects GitHub issues across a single repository or all DiGi repositories by labels, repository, state, and search terms with token-efficient output. Automatically normalizes shorthand label names (`standard`, `high`, `bug`, etc.) to standard DiGi taxonomy names.
```powershell
# Filter issues in a specific repository by labels
PowerShell -ExecutionPolicy Bypass -File ".\FilterIssues.ps1" -Repo "DiGi.Core" -Labels "ai: standard, priority: high"

# Filter issues across all repositories using label shorthands
PowerShell -ExecutionPolicy Bypass -File ".\FilterIssues.ps1" -Labels "standard, high"

# Search keyword in titles/descriptions
PowerShell -ExecutionPolicy Bypass -File ".\FilterIssues.ps1" -Repo "DiGi.GIS.PostgreSQL" -Search "subdivision"

# Inspect specific issue with description preview
PowerShell -ExecutionPolicy Bypass -File ".\FilterIssues.ps1" -Repo "DiGi.GIS.PostgreSQL" -Issue 42 -Detail

# Output clean JSON for programmatic processing
PowerShell -ExecutionPolicy Bypass -File ".\FilterIssues.ps1" -Labels "critical" -Json
```

### Sync GitHub Labels Across All Repositories
Synchronizes the standardized 20-label taxonomy across all DiGi repositories on GitHub.
```powershell
# Preview label sync changes across all repositories
PowerShell -ExecutionPolicy Bypass -File ".\SyncLabelsAllRepos.ps1" -DryRun

# Sync labels for a single target repository
PowerShell -ExecutionPolicy Bypass -File ".\SyncLabelsAllRepos.ps1" -Repo "DiGi.Core"

# Sync labels across all DiGi repositories
PowerShell -ExecutionPolicy Bypass -File ".\SyncLabelsAllRepos.ps1"
```

