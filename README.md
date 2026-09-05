# PowerShell Validate Skill

This repository contains a PowerShell validator for script quality and common
PowerShell pitfalls. It is designed for cross-platform use with PowerShell 7+.

## Table of contents

- [Repository layout](#repository-layout)
- [Validate a script or folder](#validate-a-script-or-folder)
- [Install the agent skill](#install-the-agent-skill)
  - [Personal installation for Codex and GitHub Copilot](#personal-installation-for-codex-and-github-copilot)
  - [Make the same installation available to Claude Code](#make-the-same-installation-available-to-claude-code)
  - [Project installation](#project-installation)
  - [Verify skill discovery](#verify-skill-discovery)
- [License](#license)

## Repository layout

```text
skills-PSValidate\
  agents\openai.yaml
  references\checks.md
  scripts\
    Checks\
    Test-PowerShellValidation.ps1
  tools\
    Copy-AgentSkillToUserProfile.ps1
  Copy-AgentsToUserProfile.ps1
  AGENTS.md
  README.md
  SKILL.md
```

`SKILL.md` references files under `scripts` and `references`. Install the skill
as a directory and keep those relative paths together; copying only `SKILL.md`
produces an incomplete skill. The `agents` directory contains optional OpenAI
display metadata.

## Validate a script or folder

Run against a single file:

```powershell
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path ./scripts/Test-PowerShellValidation.ps1
```

Run recursively on all PowerShell files in the repository:

```powershell
pwsh -NoProfile -File scripts/Test-PowerShellValidation.ps1 -Path . -Recurse
```

## Install the agent skill

Agent skills use one directory per skill. The directory name should match the
skill's `name`, so this skill belongs in a directory named
`powershell-validate`.

The installation wrapper uses the bundled
`tools/Copy-AgentSkillToUserProfile.ps1` utility. The reusable source is
maintained in the `skills-utils` repository, but this repository includes the
version it needs and has no runtime dependency on `skills-utils`.

| Product | Personal skill directory | Project skill directory | Reads `.agents/skills` |
| --- | --- | --- | --- |
| Codex | `~/.agents/skills` | `<repository>/.agents/skills` | Yes |
| GitHub Copilot | `~/.agents/skills` or `~/.copilot/skills` | `<repository>/.agents/skills`, `.github/skills`, or `.claude/skills` | Yes |
| Claude Code | `~/.claude/skills` | `<repository>/.claude/skills` | No; use a link or second copy |

### Personal installation for Codex and GitHub Copilot

Codex and GitHub Copilot both discover personal skills under
`$HOME/.agents/skills`. Install this skill for the current user from the
repository root:

```powershell
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1
```

The script resolves `$HOME` for the current user, copies the complete skill to
`$HOME/.agents/skills/powershell-validate`, and prints the resolved destination.
Matching files are overwritten. Other skills are not changed.

### Make the same installation available to Claude Code

Claude Code discovers personal skills under `$HOME/.claude/skills`; its
official discovery paths do not include `$HOME/.agents/skills`. To keep one
canonical copy, link Claude's skill directory to the shared installation.

On Windows, create a directory junction after completing the shared install:

```powershell
$SharedSkill = Join-Path $HOME ".agents\skills\powershell-validate"
$ClaudeSkills = Join-Path $HOME ".claude\skills"
$ClaudeSkill = Join-Path $ClaudeSkills "powershell-validate"

New-Item -ItemType Directory -Path $ClaudeSkills -Force | Out-Null
if (-not (Test-Path -LiteralPath $ClaudeSkill)) {
    New-Item -ItemType Junction -Path $ClaudeSkill -Target $SharedSkill | Out-Null
}
```

Claude Code officially supports symlinked skill directories in current
releases. A Windows junction is a convenient filesystem link, but if Claude
does not discover it, use a symbolic link (which may require Developer Mode or
administrator rights on Windows) or use the complete-copy fallback below.

On macOS or Linux, create a symbolic link:

```bash
mkdir -p ~/.claude/skills
ln -s ~/.agents/skills/powershell-validate ~/.claude/skills/powershell-validate
```

If links are unavailable, copy the complete skill directory instead. Repeat
the copy whenever the shared skill changes. Matching files are overwritten;
stale files in the Claude copy are retained:

```powershell
$SharedSkill = Join-Path $HOME ".agents\skills\powershell-validate"
$ClaudeSkill = Join-Path $HOME ".claude\skills\powershell-validate"

New-Item -ItemType Directory -Path $ClaudeSkill -Force | Out-Null
Copy-Item -Path "$SharedSkill\*" -Destination $ClaudeSkill -Recurse -Force
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

## License

This project is released under the [MIT License](LICENSE).

## Versions and releases

This repository is versioned independently with stable SemVer tags
`vMAJOR.MINOR.PATCH`. All skills in the repository share that release. Skill
Markdown and PowerShell are distributed as validated source, without compilation.

Use a patch release for compatible corrections, a minor release for compatible
features, and a major release for breaking instructions, interfaces, or packaging.
The initial release is `v1.0.0`; do not edit a published tag to fix a release.

Merge a pull request after both `Validate (windows-latest)` and
`Validate (ubuntu-latest)` pass. Then run **Actions > Release > Run workflow**
on `main` with the new version. The workflow validates that exact commit again,
requires immutable releases, creates a new tag, prepares a draft, and publishes
it. A failed publication can leave a tag or draft for manual inspection; the
workflow never overwrites an existing tag. Publish a new version for corrections.

Repository rules require PRs, passing checks, an up-to-date branch, and resolved
review conversations on main. Force pushes and deletion are blocked. There are
no bypass actors and no required external approvals, permitting solo maintenance.
Version tags cannot be updated or deleted; releases are immutable after publication.

Use `$update-dknn-skills` from [skills-utils](https://github.com/dknn/skills-utils)
to install or update. New installations use Stable; Latest explicitly follows
the default branch. Installed source choices and pinned versions persist.
Commit SHAs and managed-file hashes identify installed content, not timestamps.
