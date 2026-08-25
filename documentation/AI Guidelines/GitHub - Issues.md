# AI Guidelines: GitHub Issues & Comments

Guidelines for managing, commenting on, and closing GitHub issues and pull requests across DiGi repositories.

---

## 1. PowerShell CLI Escaping & `--body-file` (Mandatory)

When creating or editing GitHub issues, pull requests, or comments using the GitHub CLI (`gh`), **never pass multi-line markdown or text containing backticks/code spans directly as an inline string argument** (`--body "..."` or `--comment "..."`).

### The Escape Mangling Problem
In PowerShell (`pwsh`), the backtick (`` ` ``) is the escape character. An inline string such as `"Verified on `api.digiproject.uk` ..."` causes PowerShell to evaluate `` `a `` as the ASCII Bell escape character (`\a` / `^G`), mangling the URL into `\pi.digiproject.uk\`. Similarly, `` `n `` produces newlines, `$` triggers variable expansion, and quotes/backslashes become corrupt.

### Safe Execution Pattern
Always write the formatted markdown body to a temporary/scratch `.md` file encoded as **UTF-8 without BOM**, and pass the file path via `--body-file` or `@<path>`:

1. **Creating a New Issue (Mandatory Type + Priority Labels):**
   Every new issue added to any repository **must** be assigned at least one `type: *` label and one `priority: *` label upon creation:
   ```bash
   gh issue create --repo <owner>/<repo> --title "<Title>" --body-file <path_to_markdown_file> --label "type: <type>,priority: <priority>"
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

3. **Updating an Existing Comment via API:**
   ```bash
   gh api -X PATCH repos/<owner>/<repo>/issues/comments/<comment_id> -F "body=@<path_to_markdown_file>"
   ```

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
