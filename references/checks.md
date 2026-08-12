# PowerShell Validation Checks

Use this file when the validator reports an issue or when you are debugging a PowerShell script that "looks fine" but still fails.

## Encoding And Character Issues

### Smart quotes and guillemets

Replace `\u2018`, `\u2019`, `\u201C`, `\u201D`, `\u00AB`, and `\u00BB` with straight ASCII quotes. These are a common cause of `The string is missing the terminator`.

### Non-ASCII punctuation

Replace punctuation that visually mimics ASCII syntax:

- `\u2013` to `-`
- `\u2014` to `--` or `-`, depending on intent
- `\u2026` to `...`
- `\u00A0` to a regular space

### UTF-8 BOM

Treat BOM as context-dependent. It is usually unwanted for PowerShell 7+ and cross-platform scripts, but can be tolerated in Windows PowerShell 5.1-only environments.

If the target is known, validate explicitly:

- `-ExpectedBom Present` for Windows PowerShell 5.1-oriented scripts that intentionally rely on BOM.
- `-ExpectedBom Absent` for PowerShell 7+ and cross-platform scripts.

Use plain BOM presence as a signal, not a universal bug.

### Null bytes

Treat null bytes as a likely UTF-16 save. Re-encode the file as UTF-8 instead of patching isolated lines.

### Danish letters and mojibake

Treat `Ã¦`, `Ã¸`, `Ã¥`, `Ã†`, `Ã˜`, and `Ã…` as likely mojibake caused by decoding UTF-8 bytes as Windows-1252 or Latin-1.

Treat plain `æ`, `ø`, `å`, `Æ`, `Ø`, and `Å` as context-dependent:

- Accept them when the script intentionally contains Danish text and the runtime environment is known to handle UTF-8 correctly.
- Warn on them when you want ASCII-safe deployment scripts, server automation, or predictable console output across mixed Windows environments.

### Mixed line endings

Normalize the file to one convention. Mixed `CRLF` and `LF` often create noisy diffs and hard-to-explain behavior across tools.

## PowerShell-Specific Bugs

The code checks below run on the PowerShell AST, not on raw text, so they ignore
comments and string contents and understand line-continuations.

### Syntax / parse errors (`parse-error`)

The validator parses every file with the PowerShell parser. Any error the parser
reports (missing `)`, unbalanced `{}`, broken here-string terminator, etc.) is
surfaced with a line number. A "looks fine but won't run" script usually fails
here first — fix these before chasing anything else.

### Here-string header misuse (`herestring-header`)

When a here-string header has extra text on the same line, PowerShell throws:
`No characters are allowed after a here-string header but before the end of the line`.

Use one of these forms:

- Double-quoted here-string:
  `@"`
- Single-quoted here-string:
  `@'`

The opening marker must be the only content on that line. The here-string content
starts on the following line.

### Variable-colon in expandable strings (`variable-colon`)

`"$name: value"` is parsed like a drive-qualified variable reference. Use
`"${name}: value"` instead. This is detected by the parser, so it also fires
inside double-quoted here-strings — and it does **not** fire on valid scope or
drive forms such as `"$env:PATH"`, `"$script:Config"`, or `"$using:x"`.

### `$null` on the right of a comparison (`null-comparison`)

`$x -eq $null` evaluates the collection-filtering behavior of `-eq`: if `$x` is an
array, it returns the *elements equal to $null*, not a boolean. Always put `$null`
on the left: `if ($null -eq $x)`. Same for `-ne`.

### Assignment used as a condition (`assignment-in-condition`)

`if ($x = Get-Thing)` assigns and tests truthiness instead of comparing. Usually a
typo for `if ($x -eq ...)`. If the assignment is deliberate, the warning is safe
to ignore.

### `Rename-Item -NewName` with a full path

`-NewName` expects a leaf name. If the value looks like a path, compute the leaf with `Split-Path -Leaf` first.

### `ConvertTo-Json` without `-Depth`

Default depth is shallow. Use `-Depth 10` unless you intentionally want truncated nesting.

### `.Count` on unwrapped command output

PowerShell enumerates command output. A variable assigned with `$items = Get-Thing` may be `$null`, a scalar, or an array depending on how many objects are emitted. Under `Set-StrictMode -Version Latest`, `$items.Count` can fail when the command emits exactly one scalar object, such as a string.

Use `$items = @(Get-Thing)` when later code expects array semantics such as `.Count` or indexed access.

### Native command piped to `Out-Null`

After `tool.exe ... | Out-Null`, check `$LASTEXITCODE` or throw on failure. `try/catch` alone will not help for native executables. The validator only flags *native* commands here (names that are not `Verb-Noun`); a pure cmdlet such as `Get-ChildItem | Out-Null` is not flagged because cmdlets do not set `$LASTEXITCODE`.

### Array concatenation with `+=`

Inside a loop *body*, `+=` is quadratic. Prefer a generic list or assign the loop output directly. The increment in a `for` header (`for ($i=0; ...; $i += 1)`) is not flagged — only growth inside the body is.

## Triage Hints

- `parse-error`: a real syntax error — fix it first; later checks may be incomplete until it parses.
- `missing terminator`: inspect for smart quotes first.
- `variable reference is not valid`: inspect for `$var:` inside `"..."` (already reported as `variable-colon`).
- `works in ISE but not in terminal`: inspect encoding, BOM, and null bytes.
- `KÃ¸rer` or `Ã¦ndringer` in output: inspect for mojibake and re-encode as UTF-8.
- `catch never runs`: inspect cmdlets inside `try` for missing `-ErrorAction Stop`.
- `silent failure after native command`: inspect `$LASTEXITCODE`.
- `if-condition always true / assigns instead of compares`: inspect for `=` vs `-eq` (`assignment-in-condition`).
- `comparison with $null behaves oddly on arrays`: put `$null` on the left (`null-comparison`).

## Scope Reminder

The validator now parses the file with the real PowerShell parser, so the code
checks are precise rather than heuristic — but the encoding/character checks and
the two remaining regex checks (`rename-item-newname-path`, `unwrapped-command-count`)
are still heuristic. A warning is a prompt to inspect surrounding code, not proof
that the line is wrong.

## Not Currently Checked

Deliberately out of scope for now (would need flow analysis to avoid noise):

- A bare native command whose failure is ignored when it is *not* piped to `Out-Null` (e.g. `git push` on its own line). Only the `Out-Null` form is detected.
