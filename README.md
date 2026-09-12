# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 or arm64. Requires internet and chezmoi 2.72.1+.
Fork, customize [winget.json](winget.json), and substitute your fork URL below. Setup asks for your Git identity.
Back up existing files and move conflicting files, directories or links before applying.

## Setup policy

- Preserve data/settings and control disruption first, then repeatability and low maintenance. Use official tools and native package managers.
- Full apply installs missing components through WinGet/APT and official installers; supervise package operations, which can restart services.
- Keep existing settings, package sources and disabled/masked services. Hooks never restart services or reboot. Handle firmware, Secure Boot, upgrades and repairs manually; preserve OS security updates.
- Use [configuration-only updates](#updates) routinely. Keep project runtimes, CUDA SDKs and databases in containers; credentials and personal agent settings stay outside this repository.

## Windows

Finish Windows Update; enable CPU virtualization. For Ryzen 7 7700 / RX 9060 XT, run
[AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html): Recommended driver, no Factory Reset.
Restart when requested. In **administrator PowerShell**:

```powershell
wsl --install --no-distribution --web-download
winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
```

Missing WinGet: update App Installer in Microsoft Store. After any requested restart, open **normal PowerShell 7.5+**.
`$PROFILE.CurrentUserAllHosts` must be `$HOME\Documents\PowerShell\profile.ps1` (no redirected Documents).

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
chezmoi init https://github.com/seiya8bit/dotfiles
chezmoi diff
chezmoi apply
```

Reopen Windows Terminal; select `JetBrainsMono Nerd Font Mono`. Enable Docker Desktop's WSL 2 engine;
check `docker run --rm hello-world`. Sign in to apps and enable VS Code Settings Sync as needed; updates/licenses are manual.

## Ubuntu Server

### 1. Install as your normal user

Automatically installs Docker/Compose/Buildx, SSH, Tailscale, Codex, Zellij and zoxide.
Adds you to the **root-equivalent Docker group** for use without sudo; installs NVIDIA drivers/Toolkit when an NVIDIA GPU is present.

```sh
sudo apt-get update && sudo apt-get install -y ca-certificates curl git tar
installer=$(curl --fail --location --silent --show-error https://get.chezmoi.io) &&
    sh -c "$installer" -- -b "$HOME/.local/bin" -t v2.72.1
export PATH="$HOME/.local/bin:$PATH"
chezmoi init https://github.com/seiya8bit/dotfiles
chezmoi diff
chezmoi apply
```

**Errors:** stop and resolve them; retrying does not repair partial installations. For driver failures, follow
[Ubuntu's driver guide](https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/).

### 2. Reboot or log in again

- **New NVIDIA driver (e.g. RTX 4080 SUPER):** run `sudo reboot`, reconnect, then `chezmoi apply`. Complete Secure Boot enrollment at the console only if requested. This also refreshes Docker group membership.
- **Otherwise:** `exit` from the login shell (outside Zellij/tmux), then reconnect with `ssh user@server` or log in at the console. A new shell alone does not refresh group membership.
- Follow apply's remaining manual actions. If Docker predates Toolkit, schedule a Docker restart or reboot for GPU access.

### 3. Verify without sudo

```sh
docker run --rm hello-world
docker compose version
docker buildx version
```

Expect `Hello from Docker!` and version outputs. Also test a new SSH connection from another machine.
**NVIDIA only:** run `nvidia-ctk cdi list`; expect `nvidia.com/gpu=all`. If `nvidia-smi` is installed, also run:

```sh
nvidia-smi -L
docker run --rm --gpus all ubuntu:26.04 nvidia-smi
```

Both should show your GPU. Test actual CUDA workloads in project containers separately.
GPU setup uses Ubuntu-recommended signed modules (no DKMS fallback) and native CDI: Docker 29.2+, Compose 2.30+, Toolkit 1.18+.
Automatic GPU setup supports amd64/arm64 SBSA, not WSL or Jetson/L4T; unsupported or broken setups require manual resolution.

### 4. Sign in and work

| Tool | Action |
| --- | --- |
| Tailscale | `sudo tailscale up`; follow the sign-in link. |
| Codex | Enable device code login in ChatGPT security/workspace settings, then `codex login --device-auth`; open the URL and enter the code on another device. Run `codex` in your project. |
| Zellij | `zj attach --create work` creates or resumes a session. |
| zoxide | `z` revisits directories; `cd` stays unchanged. |

Prepare project clones, `.env`, data, models and credentials yourself.

## Updates

Edit sources in `home/` via `chezmoi cd`. For **configuration only** (no app/binary installation, scripts or sudo; downloads may occur):

```sh
chezmoi update --apply=false
chezmoi init
chezmoi diff --exclude scripts,externals
chezmoi apply --exclude scripts,externals
```

Use full `chezmoi diff` and `chezmoi apply` only for intentional provisioning or pinned-binary updates during maintenance.
Zellij/Codex pins live in `home/.chezmoiexternal.toml`; update official release URLs and both architecture SHA-256 checksums, then verify.

Personal overrides: `~/.gitconfig.local` (included last), host-specific Windows `$PROFILE`, or outside Ubuntu's managed `.bashrc` block.
Change Git identity with `chezmoi init --prompt`, then review/apply. After Bash edits, `source ~/.bashrc` or open a new shell.

## Verification

From the repository (`chezmoi cd`), run `./tests/verify-windows.ps1` on Windows. For Ubuntu checks, with Docker running:

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```

Tests use disposable destinations and mocks; Ubuntu runs non-root without real sudo or a Docker socket.
**Real APT, SSH, Secure Boot and GPU containers remain unverified.** Record hardware acceptance here with
OS/architecture/GPU/kernel/driver/Toolkit versions and confirm existing containers retain their ID/start time across apply.
