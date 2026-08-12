---
name: powershell-validate
description: Validate and troubleshoot PowerShell scripts for encoding, quoting, parsing, and common Windows automation mistakes. Use whenever Claude or Codex creates, edits, reviews, or debugs `.ps1`, `.psm1`, or `.psd1` files — especially after generating PowerShell from scratch, copy-paste, heredoc output, or cross-shell edits, or when a script fails with symptoms like missing terminators, bad encoding/mojibake, silent `catch` blocks, or suspicious path and regex handling. Run the validator before handing PowerShell back to the user, even if they don't explicitly ask for validation.
---

# PowerShell Validate

Use this skill whenever PowerShell code might have been produced by a non-PowerShell toolchain or is failing in ways that suggest text corruption, parser confusion, or PowerShell-specific footguns.

## Workflow

1. Run `scripts/Test-PowerShellValidation.ps1` against the target file or folder.
2. Read the findings before editing anything. Treat `Error` as fix-now and `Warning` as review-now.
3. Fix the file with ASCII-safe edits unless non-ASCII content is clearly required.
4. Re-run the validator after each meaningful change.
5. If the script still fails, inspect the parser error and compare it to the patterns in `references/checks.md`.

## Fast Paths

These use `pwsh` (PowerShell 7+), which runs on Linux, macOS, and Windows. On a
Windows-only host with Windows PowerShell 5.1, substitute
`powershell -ExecutionPolicy Bypass` for `pwsh -NoProfile` and use backslash paths.

### Validate one file

```bash
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./deploy.ps1
```

### Validate a folder recursively

```bash
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./Tools -Recurse
```

### Validate BOM expectations for PowerShell 7+ scripts

```bash
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./src -Recurse -ExpectedBom Absent
```

### Warn when scripts contain Danish letters

```bash
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./deploy.ps1 -WarnOnDanishLetters
```

### Fail the run when any warning is found

```bash
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./src -Recurse -FailOn Warning
```

## How It Works

The validator runs two passes. **Encoding/character checks** work on the raw
bytes and text, because they are about how the file was saved. **Code checks**
parse the file with the PowerShell parser itself
(`[System.Management.Automation.Language.Parser]::ParseInput`) and walk the AST,
so comments and string literals can never be mistaken for code (a `for` in a
comment, or a `}` inside a string, no longer fools the loop detection) and
line-continuations are understood. As a bonus, the parser's own errors are
reported, so genuine syntax mistakes surface too.

## What The Script Checks

Encoding / characters (raw bytes):

- Smart quotes, guillemets, en dash, em dash, ellipsis, and non-breaking space.
- UTF-8 BOM presence and optional BOM expectation checks, UTF-16-style null bytes, and mixed line endings.
- Likely mojibake for Danish characters such as `Ã¦`, plus optional warnings for raw `æøå`.

Code (PowerShell parser / AST):

- Real syntax/parse errors, reported with line numbers (`parse-error`).
- Variable-colon inside expandable strings such as `"$name: ..."` and double-quoted here-strings — caught by the parser, which correctly leaves valid scope/drive forms like `"$env:PATH"` alone (`variable-colon`).
- `$null` on the right of `-eq`/`-ne`, which silently filters a collection instead of comparing (`null-comparison`).
- Assignment (`=`) used directly as an `if`/`while` condition where `-eq` was likely meant (`assignment-in-condition`).
- `ConvertTo-Json` without `-Depth` (sees `-Depth` even on a continuation line; skips splatted calls).
- A *native* command piped to `Out-Null` without a nearby `$LASTEXITCODE` check (pure cmdlets are intentionally ignored).
- `+=` inside a loop *body* — array growth (the increment in a `for` header is correctly ignored).

Heuristic line checks (regex):

- `Rename-Item -NewName` receiving what looks like a full path.
- `.Count` on unwrapped command output that should be assigned with `@(...)`.

## Fixing Guidance

- Prefer rewriting broken quotes and punctuation to plain ASCII.
- Preserve the repository's existing line-ending convention unless the file is mixed.
- Remove BOM only when the script is intended for PowerShell 7+ or cross-platform use.
- Use `-ExpectedBom Present` or `-ExpectedBom Absent` when the target environment is known.
- Treat UTF-16/null-byte findings as re-encode-the-file issues, not line-edit issues.
- Treat `Ã¦`, `Ã¸`, and similar mojibake as an encoding bug. Treat plain `æøå` as a context-dependent warning.
- When the validator reports a heuristic warning, verify the surrounding code before changing it.

## References

- Read [references/checks.md](references/checks.md) for the detailed bug catalog, examples, and triage notes.
