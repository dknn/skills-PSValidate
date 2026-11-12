# PowerShell Validate Skill

This repository contains a PowerShell validator for script quality and common
PowerShell pitfalls. It is designed for cross-platform use with PowerShell 7+.

## Table of contents

- [Install the agent skill](#install-the-agent-skill)
  - [Quick start: install skill and configure agents](#quick-start-install-skill-and-configure-agents)
  - [What `Install-AgentInstructions.ps1` does](#what-install-agentinstructionsps1-does)
  - [Make the same installation available to Claude Code](#make-the-same-installation-available-to-claude-code)
  - [Project installation](#project-installation)
  - [Verify skill discovery](#verify-skill-discovery)
- [Validate a script or folder](#validate-a-script-or-folder)
- [License](#license)
- [Versions and releases](#versions-and-releases)

## Install the agent skill

### Quick start: install skill and configure agents

Run these two commands from the repository root to install the skill and
configure all installed coding agents on your machine to use it automatically:

```powershell
# 1. Install the skill to $HOME\.agents\skills\powershell-validate
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1

# 2. Configure all detected agents (Copilot, VS Code, Codex, Claude Code, Gemini)
pwsh -NoProfile -File "$HOME\.agents\skills\powershell-validate\scripts\Install-AgentInstructions.ps1"
```

`Copy-AgentsToUserProfile.ps1` copies the skill files and writes
`.skills-utils-install.json` with SHA-256 file hashes so the installation can
be updated later with `$update-dknn-skills` from
[skills-utils](https://github.com/dknn/skills-utils) without unmanaged-file
conflicts (see [Versions and releases](#versions-and-releases)).

### What `Install-AgentInstructions.ps1` does

Running `Install-AgentInstructions.ps1` ensures your coding agents always load
and follow `powershell-validate` whenever they create, edit, review, or execute
PowerShell scripts, modules, or commands:

- **Detects installed agent products** on your machine and updates only the
  products you actually have installed:
  - **GitHub Copilot (`~/.copilot`):** updates `~/.copilot/copilot-instructions.md`.
  - **VS Code Copilot (`AppData/Roaming/Code/User`):** writes `prompts/powershell.instructions.md` with `applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"`.
  - **Codex (`~/.codex`):** updates `~/.codex/AGENTS.md` (or skips if `Always use powershell-validate` is already present).
  - **Claude Code (`~/.claude`):** updates `~/.claude/CLAUDE.md` and installs a skill copy to `~/.claude/skills/powershell-validate` when missing.
  - **Antigravity / Gemini (`~/.gemini`):** updates `~/.gemini/GEMINI.md`.
- **Preserves existing instructions:** manages only its own
  `<!-- powershell-validate:start -->` ... `<!-- powershell-validate:end -->`
  section and never overwrites unrelated rules.
- **Supports repository-level setup (`-RepositoryRoot`):** pass
  `-RepositoryRoot` to configure `.github/copilot-instructions.md`,
  `.github/instructions/powershell.instructions.md`, and existing `AGENTS.md` /
  `CLAUDE.md` files for a team repository:

```powershell
pwsh -NoProfile -File "$HOME\.agents\skills\powershell-validate\scripts\Install-AgentInstructions.ps1" `
    -RepositoryRoot "C:\path\to\target-repository"
```

| Product | Personal skill directory | Project skill directory | Reads `.agents/skills` |
| --- | --- | --- | --- |
| Codex | `~/.agents/skills` | `<repository>/.agents/skills` | Yes |
| GitHub Copilot | `~/.agents/skills` or `~/.copilot/skills` | `<repository>/.agents/skills`, `.github/skills`, or `.claude/skills` | Yes |
| Claude Code | `~/.claude/skills` | `<repository>/.claude/skills` | No; use a link or second copy |

### Make the same installation available to Claude Code

Claude Code discovers personal skills under `$HOME/.claude/skills`; its
official discovery paths do not include `$HOME/.agents/skills`. Running
`Install-AgentInstructions.ps1` automatically copies the skill to
`$HOME/.claude/skills/powershell-validate` when `$HOME/.claude` exists.

If you prefer a Windows directory junction to keep one canonical copy:

```powershell
$SharedSkill = Join-Path $HOME ".agents\skills\powershell-validate"
$ClaudeSkills = Join-Path $HOME ".claude\skills"
$ClaudeSkill = Join-Path $ClaudeSkills "powershell-validate"

New-Item -ItemType Directory -Path $ClaudeSkills -Force | Out-Null
if (-not (Test-Path -LiteralPath $ClaudeSkill)) {
    New-Item -ItemType Junction -Path $ClaudeSkill -Target $SharedSkill | Out-Null
}
```

On macOS or Linux, create a symbolic link:

```bash
mkdir -p ~/.claude/skills
ln -s ~/.agents/skills/powershell-validate ~/.claude/skills/powershell-validate
```

Or install a second copy directly to Claude's skill root:

```powershell
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1 `
    -TargetRoot (Join-Path $HOME ".claude")
```

### Project installation

To share the skill through a repository, copy the complete skill directory to:

```text
<repository>/.agents/skills/powershell-validate/
```

For example, run this from the skill repository root after selecting the target
repository:

```powershell
$ProjectRoot = "C:\path\to\target-repository"
$TargetRoot = Join-Path $ProjectRoot ".agents"

pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1 `
    -TargetRoot $TargetRoot
```

As with the personal install, matching files are overwritten and stale files
are retained. The command does not delete project files.

Codex and GitHub Copilot both discover that project location. GitHub Copilot
also accepts `.github/skills` and `.claude/skills`.

Claude Code documents `.claude/skills` as its project location. For a project
that must work with all three products, keep the canonical skill under
`.agents/skills` and create this link from the repository root:

```powershell
$SharedSkill = (Resolve-Path ".agents\skills\powershell-validate").Path
$ClaudeSkills = ".claude\skills"
$ClaudeSkill = Join-Path $ClaudeSkills "powershell-validate"

New-Item -ItemType Directory -Path $ClaudeSkills -Force | Out-Null
if (-not (Test-Path -LiteralPath $ClaudeSkill)) {
    New-Item -ItemType Junction -Path $ClaudeSkill -Target $SharedSkill | Out-Null
}
```

Do not create the link if that Claude skill path already contains files. A
portable alternative is to keep a second complete copy under
`.claude/skills/powershell-validate`.

### Verify skill discovery

First verify the installation paths:

```powershell
Test-Path (Join-Path $HOME ".agents\skills\powershell-validate\SKILL.md")
Test-Path (Join-Path $HOME ".claude\skills\powershell-validate\SKILL.md")
```

Both commands should return `True` when the personal shared install and Claude
link or copy are ready.

- **Codex:** open `/skills` or type `$powershell-validate` in a prompt. Codex
  detects changes automatically; restart Codex if a new skill does not appear.
- **GitHub Copilot:** in Copilot CLI, run `/skills reload`, followed by
  `/skills info powershell-validate` (or `/skills list`) to confirm discovery.
  Invoke the skill as `/powershell-validate`. Copilot can also select it
  automatically when the request matches the skill description.
- **Claude Code:** invoke `/powershell-validate` or make a matching request.
  Claude watches existing skill directories, but restart Claude Code if the
  top-level skills directory was created after the session started.

Discovery is metadata-first: each product initially reads the `name` and
`description` from `SKILL.md`, then loads the full instructions when the skill
is invoked or the task matches its description.

Official references:

- [Codex: Build skills](https://learn.chatgpt.com/docs/build-skills)
- [GitHub Copilot: Adding agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- [Claude Code: Extend Claude with skills](https://code.claude.com/docs/en/slash-commands)

## Validate a script or folder

Run against a single file:

```powershell
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./scripts/Test-PowerShellValidation.ps1
```

Run recursively on all PowerShell files in the repository:

```powershell
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path . -Recurse
```

To run the behavior tests and measure command coverage, install Pester 6.2.0
and run `pwsh -NoProfile -File ./tests/Invoke-Coverage.ps1`. The suite measures
the production PowerShell scripts, including the installation wrapper, and
fails when command coverage is 98 percent or lower. The report is written to
`coverage/coverage.xml`; the GitHub Actions test workflow runs the same check
on Windows and Linux.

## License

This project is released under the [MIT License](LICENSE).

## Versions and releases

This repository is versioned independently with stable SemVer tags
`vMAJOR.MINOR.PATCH`. All skills in the repository share that release. Skill
Markdown and PowerShell are distributed as validated source, without compilation.

The workflow calculates the next version from commits after the latest reachable
stable tag: `fix`, `test`, and `docs` increment patch, `feat` increments minor,
and a breaking change increments major. Breaking changes use `!` in a conventional commit
header or a `BREAKING CHANGE:` footer. The highest increment wins; other commits
do not trigger a release by themselves. Published tags are never moved or reused.

Merge a pull request after both `Validate (windows-latest)` and
`Validate (ubuntu-latest)` pass. Then run **Actions > Release > Run workflow**
on `main`. The workflow validates that exact commit again,
creates a new tag, prepares a draft, publishes it, and verifies the release
is immutable. Administrators enable immutability in repository settings; the
Actions token intentionally has no administration permission. A failed publication can leave a tag or draft for manual inspection; the
workflow never overwrites an existing tag. Publish a new version for corrections.

Repository rules require PRs, passing checks, an up-to-date branch, and resolved
review conversations on main. Force pushes and deletion are blocked. There are
no bypass actors and no required external approvals, permitting solo maintenance.
Version tags cannot be updated or deleted; releases are immutable after publication.

Use `$update-dknn-skills` from [skills-utils](https://github.com/dknn/skills-utils)
to install or update. New installations use Stable; Latest explicitly follows
the default branch. Installed source choices and pinned versions persist.
Commit SHAs and managed-file hashes identify installed content, not timestamps.
