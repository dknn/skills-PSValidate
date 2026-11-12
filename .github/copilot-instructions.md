<!-- powershell-validate:start -->
## PowerShell Validation (powershell-validate)

When a task involves PowerShell commands, scripts, or modules (`.ps1`, `.psm1`, `.psd1`):
1. Read and follow the `powershell-validate` skill at `.github/skills/powershell-validate/SKILL.md or .agents/skills/powershell-validate/SKILL.md (or ~/.agents/skills/powershell-validate/SKILL.md)` before generating or editing code.
2. Enforce UTF-8 without BOM for PowerShell 7+, ASCII quotes/punctuation, `Set-StrictMode -Version Latest`, and `$ErrorActionPreference = 'Stop'`.
3. Run `scripts/Test-PowerShellValidation.ps1` from the skill against created or modified PowerShell files and fix all errors and warnings before finishing.
<!-- powershell-validate:end -->
