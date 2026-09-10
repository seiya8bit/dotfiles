# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 and arm64 setup with chezmoi 2.72.1+.
Fork this repository, edit the [Windows app list](winget.json) and use your fork URL below.
Setup requires internet access; init prompts for your Git name and email.

Apply manages `.gitconfig`, the Windows common PowerShell profile and Ubuntu's `~/.local/bin/zellij` and `~/.local/bin/codex`.
Back up existing files and move conflicting files, directories or links before applying. Unrelated files remain unmanaged.

## Windows setup

Finish Windows Update, enable CPU virtualization, then run as administrator:

```powershell
wsl --install --no-distribution --web-download
winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
```

If WinGet is missing, update App Installer in Microsoft Store. Restart when requested,
then open a normal (non-administrator) PowerShell 7.5+ window. Check that `$PROFILE.CurrentUserAllHosts` is
`$HOME\Documents\PowerShell\profile.ps1`; redirected Documents locations are unsupported. Then run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
chezmoi init https://github.com/seiya8bit/dotfiles
chezmoi diff
chezmoi apply
```

Missing apps from the list are installed; existing apps are not upgraded.
Reopen the terminal, select `JetBrainsMono Nerd Font Mono` in Windows Terminal and use `z` to revisit directories.
Configure Docker Desktop's WSL 2 engine and run `docker run --rm hello-world`.
Manage app updates, sign-in and licenses manually. Enable VS Code's
[Settings Sync](https://code.visualstudio.com/docs/configure/settings-sync) with the same account across your devices.

## Ubuntu Server setup

On Ubuntu Server 26.04 LTS, run as your normal user. The prerequisite packages require sudo:

```sh
sudo apt-get update && sudo apt-get install -y ca-certificates curl git tar
installer=$(curl --fail --location --silent --show-error https://get.chezmoi.io) &&
    sh -c "$installer" -- -b "$HOME/.local/bin" -t v2.72.1
export PATH="$HOME/.local/bin:$PATH"
chezmoi init https://github.com/seiya8bit/dotfiles
chezmoi diff
chezmoi apply
```

Log in again to keep `~/.local/bin` on PATH; run `zellij` to start a terminal session.
Codex CLI 0.154.0 installs as your normal user without sudo or Node.js. Enable device code login in your
ChatGPT security settings or workspace permissions, then run `codex login --device-auth` on the server.
Open the printed URL in a browser on another device and enter the one-time code there; the server needs no browser.
After signing in, run `codex` from a project directory. See the [official authentication guide](https://learn.chatgpt.com/docs/auth#login-on-headless-devices).
Missing Tailscale installs through its [official installer](https://tailscale.com/install.sh) using sudo; sign in with `sudo tailscale up`.
Keep project runtimes, SDKs and databases in containers.

## Personal settings and updates

Change your Git identity with `chezmoi init --prompt`, then review and apply.
Create `~/.gitconfig.local` for Git overrides and the host-specific `$PROFILE` for Windows PowerShell settings.
These take precedence over shared settings. Keep credentials and signing keys out of the repository.
Personal Codex settings, credentials and skills remain unmanaged.

Ubuntu's Zellij and Codex versions are pinned in `home/.chezmoiexternal.toml`. To update a tool,
change its release URL and both architecture SHA-256 checksums using the official release assets,
update the matching versions in tests and this README, then run verification and review the diff before applying.
Apply maintains these pinned versions.

Use `chezmoi cd` to edit `home/` or `winget.json`. To retrieve and apply repository updates:

```sh
chezmoi update --apply=false
chezmoi diff
chezmoi apply
```

Apply configuration only, without installing apps or binaries or running scripts or sudo (downloads may still occur):

```sh
chezmoi apply --exclude scripts,externals
```

## Verification

From the repository (`chezmoi cd`):

Windows: with PowerShell 7.5+ and chezmoi on PATH, run `./tests/verify-windows.ps1`.
Ubuntu checks: with Docker running and network access, run these commands in PowerShell or Bash:

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```
