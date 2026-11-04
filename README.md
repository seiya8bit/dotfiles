# dotfiles

Windows 11 x64 dotfiles. Agents: start at [AGENTS.md](AGENTS.md).

## Setup

1. **Person:** finish Windows Update, enable CPU virtualization, and for AMD GPUs run [AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) (no Factory Reset).
2. **Person:** in administrator PowerShell, then restart if asked:

   ```powershell
   wsl --install --no-distribution --web-download
   winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
   ```

3. In PowerShell 7, not administrator, with the user's Git identity (CSV-quote a value containing a comma):

   ```powershell
   chezmoi init --apply --promptString "Git name=<name>,Git email=<email>" https://github.com/seiya8bit/dotfiles
   ```

   A person must accept any UAC prompts while installers run.

4. Restart terminals and agent apps. `chezmoi verify` must exit 0 and `mise ls --missing` must print nothing.
5. **Person:** select `JetBrainsMono NFM` in Windows Terminal, enable Docker Desktop's WSL 2 engine, install the XPPenTablet driver from XP-Pen's site, enable Bitwarden's SSH agent, disable the `ssh-agent` Windows service, and sign in: `gh auth login`, `claude`, `cf auth login`, `supabase login`, desktop apps.

## Tasks

- **Add a tool:** create `home/.chezmoidata/<tool>.toml` with `[tools.<tool>]`. Check the ID with `winget show --id <id> --exact --source winget`. For mise, check `Backend` in `mise tool <name>`: the name can be another project.
- **Remove a tool:** delete its file. The package stays installed.
- **Upgrade:** agents run the body of `update` from the [profile](home/Documents/PowerShell/profile.ps1.tmpl), adding `--disable-interactivity` to WinGet.
- **Bump cf:** set `mise` in [cf.toml](home/.chezmoidata/cf.toml) to `npm view cf dist-tags.latest`, after checking `npm view cf engines` against the Node LTS.
- **New Godot project:** in an empty folder, run `mise use godot@<version>-stable`, write `project.godot` with `config_version=5` and `[application]` `config/name="<name>"`, then run `godot_v<version>-stable_win64_console --headless --path . --import`. Ignore `.godot/` in Git. The `godot` shim is a GUI build that returns before importing finishes.
- **Change Git identity (Person):** `chezmoi init --prompt`.

## Tool settings

A tool needs `winget` or `mise`.

| Setting | Effect |
|---|---|
| `winget` | WinGet package identifier |
| `source` | `msstore` for Store packages (default `winget`) |
| `version` | Installs and pins this WinGet version |
| `override` | Installer arguments |
| `mise` | mise version of the tool named like the file |
| `mise_name` | mise tool name when it differs from the file name |
| `human` | PowerShell run only in human shells, in file name order |
| `upgrade` | Command `update` runs after upgrading WinGet packages |

## Failures

| Symptom | Action |
|---|---|
| `Documents is redirected to ...` | **Person:** stop OneDrive's Documents backup, then apply again |
| `Reboot to finish installing <id>.` | Tell the user; apply continues |
| `WinGet failed to install <id> (exit <code>)` | Report the code |
| `mise install failed (exit <code>)` | Run `mise install` and report the failing tool |
| `No version is set for shim: <tool>` | Add the tool, or `mise reshim` if it was removed |

## Verification

```powershell
git diff --check
./tests/verify-windows.ps1
```

`chezmoi` must be a real binary, not a shim without a version. The test must end with `... passed.`. It mocks WinGet and mise; only CI runs the environment script. Renaming the required `windows` CI job means changing the ruleset.

**Not covered: real WinGet installs and a full apply on a fresh machine.** Record acceptance here:

| Date | OS / architecture | Result |
|---|---|---|
