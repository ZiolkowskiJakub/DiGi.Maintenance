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
Builds all DiGi solution repositories in Release configuration.
```powershell
PowerShell -NoProfile -ExecutionPolicy Bypass -File ".\BuildAll.ps1" -Configuration Release
```

### Sync Output Directories
Synchronizes output binary directories across web services and the configured software output directory (`SOFTWARE_DIRECTORY` in `user files/Directories.conf`).
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\SyncDirectories.ps1"
```

### Copy User Files
Copies `user files` configuration folders from all DiGi repositories to the backup data directory (`USER_FILES_BACKUP_DIRECTORY` in `user files/Directories.conf`), or restores from the backup directory back to matching repositories when `-Reverse` or `-Restore` is specified.
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
