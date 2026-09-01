# AI Guidelines: GitHub Issues & Comments

Guidelines for managing, commenting on, and closing GitHub issues and pull requests across DiGi repositories.

---

## 1. PowerShell CLI Escaping & `--body-file` (Mandatory)

When creating or editing GitHub issues, pull requests, or comments using the GitHub CLI (`gh`), **never pass multi-line markdown or text containing backticks/code spans directly as an inline string argument** (`--body "..."` or `--comment "..."`).

### The Escape Mangling Problem
In PowerShell (`pwsh`), the backtick (`` ` ``) is the escape character. An inline string such as `"Verified on `api.digiproject.uk` ..."` causes PowerShell to evaluate `` `a `` as the ASCII Bell escape character (`\a` / `^G`), mangling the URL into `\pi.digiproject.uk\`. Similarly, `` `n `` produces newlines, `$` triggers variable expansion, and quotes/backslashes become corrupt.

### Safe Execution Pattern
Always write the formatted markdown body to a temporary/scratch `.md` file encoded as **UTF-8 without BOM**, and pass the file path via `--body-file` or `@<path>`:

1. **Creating a New Issue (Mandatory Type + Priority + AI Complexity Labels):**
   Every new issue added to any repository **must** be assigned at least one `type: *` label, one `priority: *` label, and exactly one `ai: *` complexity tier upon creation (tier criteria: `GitHub - AI Issue Classification.md`):
   ```bash
   gh issue create --repo <owner>/<repo> --title "<Title>" --body-file <path_to_markdown_file> --label "type: <type>,priority: <priority>,ai: <tier>"
   ```
   *(Note: During label synchronization or audits, update labels **ONLY on open issues** by default. Modify closed issues **ONLY if explicitly instructed by the user**).*

2. **Adding a Comment:**
   ```bash
   gh issue comment <issue_number> --repo <owner>/<repo> --body-file <path_to_markdown_file>
   ```

3. **Closing an Issue with Resolution Comment:**
   ```bash
   gh issue comment <issue_number> --repo <owner>/<repo> --body-file <path_to_markdown_file>
   gh issue close <issue_number> --repo <owner>/<repo>
   ```

4. **Updating an Existing Comment via API:**
   ```bash
   gh api -X PATCH repos/<owner>/<repo>/issues/comments/<comment_id> -F "body=@<path_to_markdown_file>"
   ```

### Line Endings, `\r\r\n` Translation & Markdown Table Integrity
When writing markdown body files programmatically (e.g. using Python or PowerShell scripts on Windows):
1. **The Double-Carriage-Return Trap (`\r\r\n`):** On Windows, writing in default text mode (`open(path, 'w')`) automatically translates `\n` to `\r\n`. If the input text or template already contains Windows `\r\n` line endings, this translation creates `\r\r\n` (CR CR LF).
2. **Table Rendering Destruction:** GitHub Flavored Markdown (GFM) parses `\r\r\n` as an empty line (`\r` followed by `\r\n`). Because GFM requires table rows to be strictly contiguous, any empty line inside a table breaks parsing and renders raw text with pipes instead of a formatted grid.
3. **Safe File Writing Pattern:** Always write markdown files with explicit `newline='\n'` in Python, or strip/normalize `\r` before writing:
   ```python
   # Python — explicit LF newlines and UTF-8 encoding (no BOM):
   with open(path, 'w', newline='\n', encoding='utf-8') as f:
       f.write(markdown_content)
   ```
   In PowerShell:
   ```powershell
   [System.IO.File]::WriteAllText($path, ($content -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
   ```
4. **Table Contiguity Rule:** Markdown tables must never contain blank lines between the header row (`| Col1 | Col2 |`), separator row (`|---|---|`), and data rows (`| Data1 | Data2 |`).
5. **Unicode Typography Preservation:** Always use UTF-8 without BOM to preserve typographic characters (`—` em-dash, `–` en-dash, `§` section sign, `→` arrow, `·` bullet) and prevent codepage replacement artifacts (`` / `ÔÇö`).

### The PowerShell Pipeline Decoding Trap (Capture Mangling)
When reading or modifying an existing issue body, pull request, or comment:
1. **The Native Pipeline Decoding Failure:** In Windows PowerShell (`pwsh` or `powershell.exe`), the standard output of external executables (like `gh issue view ... --json body` or `gh api ...`) is automatically decoded by PowerShell's pipeline using `[Console]::OutputEncoding`, which defaults to legacy OEM/ANSI codepages (e.g. CP437 or Windows-1252), **not UTF-8**.
2. **Irreversible In-Memory Corruption:** Any multi-byte UTF-8 character (`—` em-dash `\u2014`, `–` en-dash `\u2013`, `·` middle dot `\u00b7`, `→` arrow `\u2192`, `§` section sign `\u00a7`, `✅` checkmark `\u2705`) is irrevocably converted to `\ufffd` replacement characters (``) or broken multi-character mojibake (`ÔÇö`) the instant it enters a PowerShell variable or pipeline (`$body = gh ...` or `gh ... | ConvertFrom-Json`). Saving that string out to disk—even with explicit UTF-8 encoding—writes the corrupted replacement characters permanently.
3. **Inline Command Mangling:** Running inline scripts via `python -c "..."` inside PowerShell causes PowerShell to treat backticks as escape characters and re-encode arguments. Always write scripts to a standalone `.py` file and execute via `python <script_path>`.

### Safe Reading, Modifying, and Editing Workflow (Python Scripts)
To inspect, check off sub-tasks, or modify existing issue bodies without text corruption:
1. **Use a Standalone Python Script:** Run a script using `subprocess.run` with explicit `encoding="utf-8"`:
   ```python
   import subprocess
   import json

   res = subprocess.run(["gh", "api", "repos/<owner>/<repo>/issues/<number>"], capture_output=True, text=True, encoding="utf-8")
   body = json.loads(res.stdout)["body"]

   # Apply the modification (e.g. check off a sub-task)
   target = "- [ ] **S8 · Add a `building_data` write endpoint"
   replacement = "- [x] **S8 · Add a `building_data` write endpoint"
   assert target in body, "Target text not found in issue body!"
   modified_body = body.replace(target, replacement)

   # Mandatory Pre-Save Integrity Assertions
   assert "\ufffd" not in modified_body, "Corruption detected: replacement character present!"
   assert "ÔÇ" not in modified_body, "Corruption detected: CP1252 mojibake present!"

   # Write with explicit LF newlines and UTF-8
   with open("temp_body.md", "w", newline="\n", encoding="utf-8") as f:
       f.write(modified_body)

   # Edit via --body-file
   subprocess.run(["gh", "issue", "edit", "<number>", "--repo", "<owner>/<repo>", "--body-file", "temp_body.md"], check=True)
   ```
2. **Mandatory Pre-Save Integrity Assertions:**
   Before updating any issue body or comment, verify:
   - Zero replacement characters: `assert "\ufffd" not in text`
   - Zero codepage artifacts (`ÔÇ`, `â`)
   - All expected markdown tables and headers remain structurally contiguous.

### Recovery via GitHub GraphQL API History
If an issue's markdown body is ever accidentally corrupted or mangled:
1. **Do not attempt manual reconstruction or lossy rewriting.**
2. **Query GitHub's GraphQL API:** GitHub maintains the complete immutable edit history under `userContentEdits`:
   ```graphql
   query {
     repository(owner: "<owner>", name: "<repo>") {
       issue(number: <number>) {
         userContentEdits(first: 5) {
           nodes {
             editedAt
             diff
           }
         }
       }
     }
   }
   ```
3. **Extract Pristine Revision:** Each edit node provides `diff` containing the exact, pristine text of that revision. Retrieve the uncorrupted revision, apply the intended change with strict UTF-8 (`newline='\n'`, `encoding='utf-8'`), and update via `--body-file`.

---

## 2. Verifying an Issue Before Implementing It

An issue's problem statement is a hypothesis — including one you wrote yourself. Confirm each claim
against the code before building to it, because an issue that is wrong about the cause is usually also
wrong about the fix.

- **Does the optimization it says is missing already exist?** Open the file it names.
- **Is the quoted latency reproducible?** Run the repository's own benchmark `[Fact]` (isolated — see
  `Coding - Automatic Tests.md` §4) rather than trusting a figure in the description.
- **Does the described failure reproduce at all?** Write the reproducing `[Fact]` first.

When a claim turns out to be wrong, **correct the record in a comment with the evidence**. The issue text
is what the next reader trusts, and a closed issue keeps teaching whatever it last said.

**Worked example.** [DiGi.Geometry#2](https://github.com/ZiolkowskiJakub/DiGi.Geometry/issues/2) asked for
spatial partitioning to cut a reported 15-60 s latency. `Difference.cs` already held an `STRtree`, and the
`< 3.0 s` acceptance criterion was already met at ~1.3 s measured. The real defect was a crash on dense
input. Implementing the issue as written would have added a second spatial index and two NuGet packages
for no measurable gain.

---

## 3. Standard Issue Resolution Comment Structure

When resolving and closing an issue, provide a structured comment covering:

1. **Resolution & Commits:**
   - Mention the commit SHA(s), version branch, and target repository.
2. **Summary of Changes:**
   - Technical summary of the fix or feature implemented.
   - List of modified and added classes/files.
3. **Automated & Integration Tests:**
   - Test facts added to `DiGi.Test` and verification commands run.
4. **Live Deployed Verification (if applicable):**
   - Results of manual verification against deployed WebAPI endpoints or services.

---

## 4. Searching & Filtering Issues (`FilterIssues.ps1`)

To locate, triage, or inspect GitHub issues across repositories without wasting context tokens on bloated JSON payloads, use the dedicated maintenance script `DiGi.Maintenance/Scripts/FilterIssues.ps1`:

```powershell
# Filter issues in a specific repository by labels (supports standard names and shorthands)
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/FilterIssues.ps1" -Repo "DiGi.Core" -Labels "ai: standard, priority: high"

# Search across all repositories by label shorthands
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/FilterIssues.ps1" -Labels "standard, high"

# Search by keyword in title/body
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/FilterIssues.ps1" -Repo "DiGi.GIS.PostgreSQL" -Search "subdivision"

# Inspect a single issue with description preview
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/FilterIssues.ps1" -Repo "DiGi.GIS.PostgreSQL" -Issue 42 -Detail

# Emit minimal JSON for programmatic handling
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/FilterIssues.ps1" -Labels "critical" -Json
```

### Key Advantages for AI Agents:
- **Token Efficiency:** Formats issue summaries into 1–2 lines per issue, saving >90% of tokens compared to raw GitHub CLI JSON.
- **Label Shorthands:** Automatically normalizes common terms (`high` $\rightarrow$ `priority: high`, `standard` $\rightarrow$ `ai: standard`, `bug` $\rightarrow$ `type: bug`, `in-progress` $\rightarrow$ `status: in-progress`).
- **Flexible Scope:** Omit `-Repo` to search across all DiGi repositories under the owner in one command.

