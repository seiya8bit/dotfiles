# dotfiles

Dotfiles for Windows 11 x64, applied to fresh installs with chezmoi. Agents: start at [AGENTS.md](AGENTS.md); this file is the operating manual.

## Setup

An agent cannot do the steps marked **Person**.

1. **Person:** finish Windows Update and enable CPU virtualization. For AMD GPUs, run [AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) (Recommended driver, no Factory Reset).
2. **Person:** in administrator PowerShell, install the prerequisites, then restart if asked. Docker Desktop needs WSL 2.

   ```powershell
   wsl --install --no-distribution --web-download
   winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
   ```

3. In PowerShell 7, not administrator. Ask the user for the Git name and email.

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   chezmoi init --apply --promptString "Git name=<name>,Git email=<email>" https://github.com/seiya8bit/dotfiles
   ```

4. Restart open terminals and agent apps so they see the new PATH.
5. Confirm: `chezmoi verify` exits 0 and `mise ls --missing` prints nothing.
6. **Person:** select `JetBrainsMono Nerd Font Mono` in Windows Terminal, enable Docker Desktop's WSL 2 engine, and sign in: `gh auth login`, `claude`, `cf auth login`, `supabase login`, Tailscale and desktop apps.

## Tasks

### Add a tool

1. Prefer WinGet: `winget show --id <id> --exact --source winget` must exit 0.
2. Use mise for language runtimes and CLIs without a WinGet package. Run `mise tool <name>` and read `Backend`: a registry name can be another project. `cf` there is Cloud Foundry, so [cf.toml](home/.chezmoidata/cf.toml) sets `mise_name`.
3. Create `home/.chezmoidata/<tool>.toml` with `[tools.<tool>]` and the [settings](#tool-settings) it needs.
4. Run [Verification](#verification). The next apply reruns the installers.

### Remove a tool

Delete its file. The next apply drops its PATH entries, `human` setup and mise entry. Its package stays installed; uninstall it only when the user asks.

### Add something for people only

Put the PowerShell in the tool's `human` setting, as in [starship.toml](home/.chezmoidata/starship.toml). Setup loads in file name order.

### Give every process a directory

Add it to the tool's `path` setting, as in [mise.toml](home/.chezmoidata/mise.toml). Use `%VARIABLE%` rather than absolute paths.

### Upgrade the machine

`update` exists only in human shells. Agents run the commands in its body in the [profile template](home/Documents/PowerShell/profile.ps1.tmpl) directly, adding `--disable-interactivity` to WinGet.

### Bump the cf beta

Set `mise` in [cf.toml](home/.chezmoidata/cf.toml) to the output of `npm view cf dist-tags.latest`. At 1.0.0, use `latest` and update [Pinned versions](docs/decisions.md#pinned-versions).

### Change the Git identity

**Person:** `chezmoi init --prompt`.

## Tool settings

Each file in [home/.chezmoidata](home/.chezmoidata) declares one tool. It needs `winget` or `mise`.

| Setting | Effect |
|---|---|
| `winget` | WinGet package identifier |
| `source` | `msstore` for Microsoft Store packages (default `winget`) |
| `version` | Installs and pins this WinGet version |
| `override` | Installer arguments |
| `mise` | mise version of the tool named like the file |
| `mise_name` | mise tool name when it differs from the file name |
| `path` | User PATH entries, for every process |
| `human` | PowerShell run only in human shells |
| `upgrade` | Command `update` runs after upgrading WinGet packages |

## Failures

| Symptom | Cause | Action |
|---|---|---|
| `Documents is redirected to ...` | OneDrive backup moved Documents, so PowerShell would not load the profile | **Person:** stop OneDrive's Documents backup, then apply again |
| `Reboot to finish installing <id>.` | The installer needs a restart; apply continues | Tell the user. Never reboot automatically |
| `WinGet failed to install <id> (exit <code>)` | Installer failure; apply stopped | Report the code. Exit `-1978335135` (already installed) is not a failure |
| `mise install failed (exit <code>)` | A mise tool failed; apply stopped | Run `mise install` to see which, then report it |
| `mise ERROR No version is set for shim: <tool>` | A shim outlived its configuration | Add the tool, or run `mise reshim` after removing it |
| `Git name and email must not be empty` | `chezmoi init` got an empty identity | Pass both to `--promptString` |

## Verification

Run these from the repository root. `chezmoi` must resolve to a real binary, not a mise shim without a version.

```powershell
git diff --check
./tests/verify-windows.ps1
```

`git diff --check` prints nothing. The test ends with `Windows: identity, tool files, installs, reruns, mise, profile, environment, Documents guard, docs and Git configuration passed.` It mocks WinGet and mise and uses a temporary home. Only on CI does it change the real user environment; elsewhere it prints `Skipped running the environment script outside CI.`

CI runs the same test. The required check is the `windows` job, so renaming the job also means changing the repository ruleset.

**Not covered: real WinGet installs and a full apply on a fresh machine.** Record that acceptance here:

| Date | OS / architecture | Result |
|---|---|---|
