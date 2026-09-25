# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 or arm64, chezmoi 2.72.1+.
Fork, edit [winget.json](winget.json) and use your fork URL below. Move conflicting files aside before applying.

## Setup policy

- Priorities: preserve data and settings, limit disruption, then repeatability and low maintenance. Use official tools and native package managers (WinGet via `winget.json`, APT); propagate installation failures.
- chezmoi owns configuration, not software versions. Official installers add other missing tools once; then each tool's own updater owns updates. Pin a checksum-verified download only when a tool has neither (currently Zellij). Never replace existing installations or disable vendor updates.
- Preserve existing package sources and OS security updates; stop on file collisions. Never remove conflicting packages, force-replace settings, change sudoers, restart existing services or reboot; leave disabled/masked services alone.
- Firmware, Secure Boot enrollment, re-login, upgrades and repairs are manual. APT dependency updates and their standard service effects are allowed; supervise them.
- Project runtimes, SDKs and databases live in containers. Credentials and personal agent settings/skills stay outside this repository.
- Ubuntu: run chezmoi as your normal user. Automated sudo only installs the tools listed below (APT, or Tailscale's official installer), adds their verified APT sources, adds you to the Docker group, and starts and checks services once.

## Windows

Finish Windows Update and enable CPU virtualization. For AMD GPUs, run [AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) (Recommended driver, no Factory Reset). In **administrator PowerShell**:

```powershell
wsl --install --no-distribution --web-download
winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
```

No WinGet? Update App Installer in Microsoft Store. After any restart, open **PowerShell 7.5+** (not administrator). Documents must not be redirected.

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
chezmoi init https://github.com/seiya8bit/dotfiles
chezmoi diff
chezmoi apply
```

Then: select `JetBrainsMono Nerd Font Mono` in Windows Terminal, enable Docker Desktop's WSL 2 engine, run `docker run --rm hello-world`, and sign in to apps.

## Ubuntu Server

Installs Docker/Compose/Buildx, SSH, Tailscale, Codex, Claude Code, OpenCode, Zellij, zoxide, and NVIDIA drivers/Toolkit when an NVIDIA GPU is present.
Agent CLIs install into `~/.local/bin` and update themselves. You join the **root-equivalent Docker group**.

```sh
sudo apt-get update && sudo apt-get install -y ca-certificates curl git tar
installer=$(curl --fail --location --silent --show-error https://get.chezmoi.io) &&
    sh -c "$installer" -- -b "$HOME/.local/bin" -t v2.72.1
export PATH="$HOME/.local/bin:$PATH"
chezmoi init https://github.com/seiya8bit/dotfiles
chezmoi diff
chezmoi apply
```

On errors, stop and fix the cause; retrying does not repair partial installs ([NVIDIA driver guide](https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/)).

Then refresh your session:

- **New NVIDIA driver:** `sudo reboot`, reconnect, `chezmoi apply`. Enroll Secure Boot at the console if asked.
- **Otherwise:** log out of the login shell (outside Zellij/tmux) and reconnect; a new shell is not enough.
- Follow any manual actions apply prints.

Verify without sudo, and test SSH from another machine:

```sh
docker run --rm hello-world
codex --version && claude --version && opencode --version
nvidia-ctk cdi list                            # NVIDIA: expect nvidia.com/gpu=all
docker run --rm --gpus all ubuntu:26.04 nvidia-smi   # NVIDIA: shows your GPU
```

Sign in: `sudo tailscale up`; `codex login --device-auth` (enable device code login in ChatGPT settings first); run `claude`, or `opencode` then `/connect`, and open the shown URL on another device.
`zj attach --create work` opens Zellij; `z` jumps to visited directories.

## Updates

Edit sources via `chezmoi cd`. Routine configuration-only update (no installs, scripts or sudo):

```sh
chezmoi update --apply=false
chezmoi init
chezmoi diff --exclude scripts,externals
chezmoi apply --exclude scripts,externals
```

Run full `chezmoi apply` only for intentional provisioning; it never upgrades or replaces an existing command. To update Zellij, change its URL and both SHA-256 checksums in `home/.chezmoiexternal.toml` together.

Personal overrides stay unmanaged and are never created by automation: `~/.gitconfig.local`, host-specific Windows `$PROFILE`, and `.bashrc` outside the managed block at its end. Change Git identity with `chezmoi init --prompt`.

## Verification

For behavior changes, run the affected platform: `./tests/verify-windows.ps1` on Windows, and for Ubuntu (same image as CI):

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```

Tests use disposable destinations and mocked provisioning, so they do not prove service or GPU readiness.
Documentation-only edits need reference checks and `git diff --check`.
**Real APT, SSH, Secure Boot and GPU containers remain unverified.** Record hardware acceptance here with OS/architecture/GPU/kernel/driver/Toolkit versions, and confirm existing containers keep their ID and start time across apply.
