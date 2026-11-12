---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
---

<!-- powershell-validate:start -->
# PowerShell instructions

For every PowerShell task (`.ps1`, `.psm1`, `.psd1`):
1. Load and follow the `powershell-validate` agent skill at `.github/skills/powershell-validate/SKILL.md or .agents/skills/powershell-validate/SKILL.md (or ~/.agents/skills/powershell-validate/SKILL.md)`.
2. Guard against PowerShell pitfalls: use `${var}:` before colons in strings, place `$null` on the left of `-eq`/`-ne`, pass `-Depth` to `ConvertTo-Json`, avoid `+=` in loops, use `.PSBase.Keys`/`.PSBase.Values` on hashtables, wrap command output in `@(...)` before `.Count`, and check `$LASTEXITCODE` after native commands piped to `Out-Null`.
3. Validate the result with `scripts/Test-PowerShellValidation.ps1` from the skill before presenting code or committing.
<!-- powershell-validate:end -->
