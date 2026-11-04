# dotfiles

Windows 11 x64, applied to fresh installs. Agents run most commands here, so the defaults serve them and conveniences for people are opt-in.

## Policy

- Preserve data and settings, then limit disruption, then stay repeatable and low-maintenance. Stop on errors; don't repair.
- Agents first: every process, including shells agents start without a profile, gets commands that behave as agents expect and nothing that waits for input. Aliases, prompts and interactive defaults load only in PowerShell attached to a terminal without `CLAUDECODE`, `CODEX_SANDBOX`, `GEMINI_CLI`, `CURSOR_AGENT` or `AI_AGENT`, so a missing human setting costs a person, never an agent.
- One file per tool: `home/.chezmoidata/<tool>.toml` holds its package and everything it configures, so deleting the file undoes all of it except the installed package.
- Install only through package managers, one per tool: WinGet; mise for language runtimes and CLIs without a WinGet package; rustup for Rust toolchains. No piped install scripts or unmanaged downloads.
- Track latest releases. Pin only with a WinGet `version` (CLIP STUDIO PAINT 5.0.4: perpetual license).
- Never uninstall, change system settings or reboot automatically; removing a tool leaves its package installed.
- mise and rustup hold global defaults, and projects pin versions in their own files (`mise.toml`, `rust-toolchain.toml`). Credentials and personal agent settings stay out of this repository.

## Setup

Finish Windows Update and enable CPU virtualization; for AMD GPUs run [AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) (Recommended driver, no Factory Reset). In administrator PowerShell (Docker Desktop runs on WSL 2):

```powershell
wsl --install --no-distribution --web-download
winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
```

After any restart, in PowerShell 7 (not administrator):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
chezmoi init --apply https://github.com/seiya8bit/dotfiles
```

Then restart open terminals and agent apps so they see the new environment, select `JetBrainsMono Nerd Font Mono` in Windows Terminal, enable Docker Desktop's WSL 2 engine and sign in to apps.

## Tools

Each file in [home/.chezmoidata](home/.chezmoidata) declares one tool, `[tools.<file name>]`, with any of:

| Setting | Effect |
|---|---|
| `winget` | WinGet package identifier |
| `source` | `msstore` for Microsoft Store packages (default `winget`) |
| `version` | Installs and pins this version |
| `override` | Installer arguments |
| `mise` | mise version of the tool named like the file |
| `mise_name` | mise tool name when it differs from the file name |
| `path` | User PATH entries, for every process |
| `ai` | User variables for every process, removed again in human shells |
| `human` | PowerShell run only in human shells, in file name order |
| `upgrade` | Command `update` runs after upgrading WinGet packages |

Agents see `path` and `ai` through the user environment, which shells inherit even without a profile; the [profile](home/Documents/PowerShell/profile.ps1.tmpl) stops before `human` for them.

## Maintenance

`update` (in a new terminal) runs `chezmoi update`, upgrades unpinned WinGet packages and runs each tool's `upgrade`. Add or remove a tool file to change what is installed; changed tools rerun the installers on the next apply.

Never managed: `~/.gitconfig.local` and the host-specific `$PROFILE`, which loads in agent shells too unless it checks for them. Change Git identity with `chezmoi init --prompt`.

## Verification

Always run `git diff --check`. Changes to `home/` or `tests/`: `./tests/verify-windows.ps1` (WinGet and mise mocked; it changes the user environment only on CI runners); docs: check that every link, path and command they mention exists.

**Unverified: real WinGet installs and human shell detection in a real terminal.** Record hardware acceptance below.

| Date | OS / architecture | Result |
|---|---|---|
