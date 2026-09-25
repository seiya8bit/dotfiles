# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 or arm64. Requires internet and chezmoi 2.72.1+.
Fork, customize [winget.json](winget.json), and substitute your fork URL below. Setup asks for your Git identity.
Back up existing files and move conflicting files, directories or links before applying.

## Setup policy

- Preserve data/settings and control disruption first, then repeatability and low maintenance. Use official tools and native package managers.
- Delegate package validation and installation to WinGet using the single `winget.json` manifest on Windows and APT on Ubuntu. Full apply also uses official installers for missing components and checksum-pinned user binaries via chezmoi externals; propagate installation failures.
- Preserve existing settings and package sources; stop on file/directory/link collisions before apply. Never automatically remove conflicting packages, force replacement of settings or change sudoers.
- Hooks may initially start services, but never restart existing services or reboot. Leave disabled/masked services unchanged. Handle firmware, Secure Boot enrollment, login-session renewal, upgrades and repairs manually.
- Necessary APT dependency updates and their package-standard service effects are allowed. Supervise package operations, which can restart services; preserve OS security updates.
- Use [configuration-only updates](#updates) routinely. Keep project runtimes, SDKs and databases in containers; credentials and personal agent settings and skills stay outside this repository.

On Ubuntu, run chezmoi as your normal user. Automated sudo is limited to installing missing Tailscale through its official stable installer;
APT operations for zoxide, Docker Engine/Compose/Buildx, OpenSSH Server, NVIDIA drivers/Container Toolkit and required OS dependencies;
verified Docker/NVIDIA APT key/source creation; adding only the invoking user to the Docker group; initial service startup and configuration/readiness checks.

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

Automatically installs Docker/Compose/Buildx, SSH, Tailscale, Codex, Claude Code, OpenCode V2, Zellij and zoxide.
The three agent CLIs install for the normal user via checksum-pinned chezmoi externals, without Node.js or global npm packages.
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
codex --version
claude --version
opencode --version
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
| Claude Code | Run `claude` in your project, sign in with a supported account, and open the displayed URL on another device. If prompted, paste the authorization code into the SSH terminal. |
| OpenCode V2 | Run `opencode` in your project; use `/connect` to select and authenticate a provider. Open the displayed URL on another device when needed. |
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
Keep pinned downloads checksum-verified. Zellij/Codex/Claude Code/OpenCode V2 pins live in `home/.chezmoiexternal.toml`;
update official release URLs and both architecture SHA-256 checksums, then verify. The x64 OpenCode build uses
the baseline variant for CPUs without AVX2. Claude Code is pinned to a release from Anthropic's stable channel;
its version is updated through chezmoi rather than the native installer. If an existing native installation owns
`~/.local/bin/claude`, move that launcher manually before full apply; chezmoi stops on a link or directory collision.
Keep agent credentials and personal settings unmanaged. After installation, disable self-updates so they cannot
replace the pinned binaries: merge `"env": {"DISABLE_AUTOUPDATER": "1"}` into `~/.claude/settings.json` and
`"autoupdate": false` into `~/.config/opencode/opencode.json`. Review the new version with `chezmoi diff` and use full `chezmoi apply` when intentionally updating pins.

Personal overrides: `~/.gitconfig.local` (included last), host-specific Windows `$PROFILE`, or outside Ubuntu's managed `.bashrc` block.
Keep these unmanaged; automation must never create or import personal overrides. Manage Bash initialization in a marked block at the end of `.bashrc`,
preserving content outside it; keep `.bash_aliases` for aliases.
Change Git identity with `chezmoi init --prompt`, then review/apply. After Bash edits, `source ~/.bashrc` or open a new shell.

## Verification

For behavior changes, run the affected platform checks from the repository (`chezmoi cd`). Run `./tests/verify-windows.ps1` on native Windows.
For Ubuntu, use the same `.devcontainer/Dockerfile` as CI, with Docker running:

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```

Tests use disposable destinations and mocked WinGet/Tailscale/host provisioning commands;
Ubuntu runs non-root without real sudo or a Docker socket. Documentation-only edits need reference checks and `git diff --check`.
Mock-test results and package installation do not establish service/GPU readiness.
**Real APT, SSH, Secure Boot and GPU containers remain unverified.** Record hardware acceptance here with
OS/architecture/GPU/kernel/driver/Toolkit versions and confirm existing containers retain their ID/start time across apply.
