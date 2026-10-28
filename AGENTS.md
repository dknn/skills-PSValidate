# AGENTS.md for skills-PSValidate

## Scope
This repository contains helper skills and scripts for PowerShell validation.

## Instructions hierarchy
When working in this repository:

1. Read `AGENTS.md` first.
2. Read any relevant instruction files referenced here.
3. Then follow existing repo conventions.

## Allowed commands
This project is script-oriented. Common commands should be preferred:
- `pwsh`
- `git`
- `pwsh -NoProfile -File ...`

## Coding conventions
- Keep scripts small and readable.
- Prefer explicit errors (`throw`) over silent failures.
- Use `Set-StrictMode` / `$ErrorActionPreference = "Stop"` in scripts.
- Use `Copy-Item` for file copy operations unless a safer/required alternative exists.
- Preserve existing behavior unless the task explicitly requests behavior changes.

## Safety
- Do not delete user files by default.
- Avoid destructive operations unless explicitly requested.
- Keep script changes scoped to the requested task.
- Do not assume `.agents` exists; only throw when `.agents` is missing at repo root and the copy task requires it.

## Skill installation after gitship
- After a successful `gitship` for this repository, check whether a newer stable release of `powershell-validate` has been published.
- If a newer release exists, replace the old installed version with that release and verify the installed version. Apply this rule only to this repository's skill.
- Use the existing skill-update workflow and preserve locally modified files. If multiple installation roots or unmanaged conflicts make the target or safe replacement unclear, ask before removing or overwriting anything.
- Report the installed version and any installations that could not be updated. A new Codex session may be needed to pick up the updated skill.
