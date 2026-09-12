# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 and arm64 setup with chezmoi 2.72.1+.
Fork this repository, edit the [Windows app list](winget.json) and use your fork URL below.
Setup requires internet access; init prompts for your Git name and email.

Apply manages `.gitconfig`, the Windows common PowerShell profile and Ubuntu's `.bash_aliases`, `.bashrc`, `~/.local/bin/zellij` and `~/.local/bin/codex`.
Back up existing files and move conflicting files, directories or links before applying. Unrelated files remain unmanaged.

## Setup policy

<details>
<summary>Automation policy and maintenance boundaries</summary>

Prioritize preserving data and settings and controlling disruption, then repeatability and lower maintenance cost.
Choose automation by official support and these priorities on both Windows and Ubuntu. Use native package managers,
official tools and [idempotent chezmoi scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/);
add machinery only for a demonstrated requirement.

| Area | Default |
| --- | --- |
| Shared user configuration | Use `--exclude scripts,externals` with both diff and apply for routine updates. |
| Windows applications | Let WinGet validate and install packages from `winget.json` during full setup. |
| Ubuntu Docker, Compose, Buildx, SSH, NVIDIA driver and GPU containers | Supervised automatic setup using APT for supported installation and dependency handling. |
| Windows GPU/chipset drivers | Use [Windows Update](https://support.microsoft.com/en-us/windows/hardware/drivers/automatically-get-recommended-and-updated-hardware-drivers) or manually launched official vendor tools for device selection and installation. |
| Firmware, Secure Boot enrollment and reboots | Operator-controlled steps following official instructions. |
| Upgrades, repairs and service restarts | Planned maintenance using the original installation source; preserve the OS security-update policy. |

Full `chezmoi apply` is for intentional provisioning or pinned-binary updates, with package operations and their service
effects expected. Keep host setup supervised until [hardware acceptance](#verification) is recorded for the target
configuration. Preserve existing settings and stop when compatibility or recovery is uncertain.

</details>

## Windows setup

Finish Windows Update and any requested restart. On Ryzen 7 7700 / Radeon RX 9060 XT, manually launch
[AMD Auto-Detect and Install](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) for compatible chipset
and GPU drivers. Prefer the Recommended GPU release unless a documented fix or application requires another version.
Use normal installation without Factory Reset and restart when requested. Enable CPU virtualization, then run as administrator:

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

Follow steps 1–4. Installation is automatic; rebooting, signing in and checking the machine are manual.

| Automatic during setup | You do afterward |
| --- | --- |
| Docker, Compose, Buildx and Docker group membership | Reboot or log in again, then test Docker **without sudo**. |
| SSH, Tailscale, Codex, Zellij and zoxide | Check SSH and sign in to the tools you use. |
| NVIDIA driver and Container Toolkit when an NVIDIA GPU is present | Reboot, rerun apply and check GPU access. |

### 1. Install

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

If apply fails, resolve the reported error before continuing. Repeating apply does not repair every partial installation.

### 2. Reboot or log in again

**New NVIDIA driver installed (including a fresh RTX 4080 SUPER setup):** reboot, reconnect and rerun apply:

```sh
sudo reboot
```

After the server starts, reconnect over SSH or log in at its console, then run:

```sh
chezmoi apply
```

Complete Secure Boot key enrollment at the server console **only if requested**.
The reboot also activates Docker group membership and restarts Docker after Toolkit installation.

**No reboot needed:** run `exit`, then reconnect with your usual `ssh user@server` command,
or log in again at the console. Do this from the login shell, outside Zellij or tmux.
Opening a new shell or sourcing `.bashrc` alone does not refresh Docker group membership.

Follow any remaining manual actions printed by apply. On an existing server, schedule requested Docker restarts
or reboots around running workloads. Docker group membership grants **root-equivalent** access.

### 3. Check Docker, SSH and your GPU

Run these as your normal user, **without sudo**, in the new login session:

```sh
docker run --rm hello-world
docker compose version
docker buildx version
```

Expect `Hello from Docker!` and two version outputs. No manual Docker group setup is needed after a successful apply.
Also open a new SSH connection from another machine to verify remote access.

**NVIDIA GPU only:**

```sh
nvidia-ctk cdi list
```

Expect `nvidia.com/gpu=all`. If `nvidia-smi` is installed, also run:

```sh
nvidia-smi -L
docker run --rm --gpus all ubuntu:26.04 nvidia-smi
```

Both should show your GPU (for example, RTX 4080 SUPER). If a check fails, inspect its error before proceeding.
These checks confirm GPU visibility; test actual CUDA workloads separately in your project's containers.
Keep CUDA SDKs, project runtimes and databases in containers. Prepare project clones, `.env`, data, models
and credentials separately.

### 4. Sign in and start working

Run the commands for the tools you use:

| Tool | Command | Next action |
| --- | --- | --- |
| Tailscale | `sudo tailscale up` | Follow the sign-in link. |
| Codex | `codex login --device-auth` | Enable device code login in ChatGPT security settings or workspace permissions; open the printed URL on another device and enter the code. |
| Zellij | `zj attach --create work` | Start or reattach to your terminal session. |

After signing in, run `codex` from a project directory. Use `z` to revisit directories.
See the [Codex authentication guide](https://learn.chatgpt.com/docs/auth#login-on-headless-devices).

<details>
<summary>Shell configuration and installation details</summary>

chezmoi uses umask `022`: managed regular files use `0644`, and managed directories and executables use `0755`,
regardless of your shell's umask.

Ubuntu's default Bash configuration loads the managed `.bash_aliases`, which defines `zj` as `zellij`.
Apply installs [zoxide from Ubuntu APT](https://packages.ubuntu.com/resolute/zoxide) if missing;
chezmoi manages a marked initialization block at the end of `.bashrc`, preserving all content outside that block.
A missing `.bashrc` starts from Ubuntu's `/etc/skel/.bashrc`. Keep personal settings outside the marked block;
apply moves the block after any later additions. Interactive Bash initializes zoxide when available, keeping `cd` unchanged.
Use `zj list-sessions` to list terminal sessions.
After applying Bash configuration changes, run `source ~/.bashrc` in existing interactive shells or open a new shell.
Codex CLI installs as your normal user without sudo or Node.js; the server needs no browser for authentication.
Missing Tailscale installs through its [official installer](https://tailscale.com/install.sh) using sudo.

</details>

<details>
<summary>Ubuntu host services: package sources, compatibility and recovery</summary>

Full `chezmoi apply` uses sudo to install missing packages and verified APT keys/sources, add you to the
Docker group and start enabled services. Disabled/masked services stay unchanged; hooks never restart services or reboot.

| Component | Installation |
| --- | --- |
| Docker, Compose, Buildx | [Docker stable APT](https://docs.docker.com/engine/install/ubuntu/); existing installations keep their package source. |
| SSH | Ubuntu `openssh-server`, with socket activation on new installs. Existing settings, keys and firewall rules remain. |
| NVIDIA driver | [Ubuntu APT](https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/#manual-driver-installation-using-apt): use `ubuntu-drivers list --gpgpu --recommended`, install matching signed modules, then `nvidia-driver-*`. No DKMS fallback. |
| GPU containers | NVIDIA stable APT `nvidia-container-toolkit-base`, with automatic [CDI refresh](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html). |

GPU containers require [Docker 29.2+ `--gpus all`](https://docs.docker.com/engine/release-notes/29/#2920),
[Compose 2.30+ `gpus: all`](https://docs.docker.com/reference/compose-file/services/#gpus) and Toolkit 1.18+ for native CDI.
No NVIDIA PCI GPU skips NVIDIA setup. Automatic GPU setup supports amd64 / arm64 SBSA;
WSL, Jetson/L4T, unsupported GPU/kernel recommendations and broken drivers stop with an explanation.

Existing drivers are checked with `nvidia-smi -L` when available. Without it, apply checks
[NVIDIA's `/proc/driver/nvidia/version`](https://download.nvidia.com/XFree86/Linux-x86_64/570.86.16/README/procinterface.html),
then tests NVML-based CDI generation without saving a specification and checks CDI discovery. No utility packages
are added just for verification. If the module is unavailable, headless drivers also get the package-based reboot check.
These checks do not verify CUDA execution.

APT resolves dependencies and preserves conffiles; [package operations can restart services](https://discourse.ubuntu.com/t/needrestart-changes-in-ubuntu-24-04-service-restarts/44671).
Conflicts and partial installations require manual resolution before reapplying; completed packages normally stay installed.
If NVIDIA signed modules install but the driver package fails, the existing-driver guard stops the next apply. Inspect
the APT error and repair using the Ubuntu driver instructions above; keep the guard and avoid automatic package removal.
If Docker predates Toolkit, restart Docker in a maintenance window (or reboot) for `--gpus all`.
Older Docker or custom/disabled CDI needs manual setup using the original package source.
See [Docker's post-installation guidance](https://docs.docker.com/engine/install/linux-postinstall/) for group permissions.

</details>

## Personal settings and updates

Change your Git identity with `chezmoi init --prompt`, then review and apply.
Create `~/.gitconfig.local` for Git overrides and the host-specific `$PROFILE` for Windows PowerShell settings.
These take precedence over shared settings. Keep credentials and signing keys out of the repository.
Personal Codex settings, credentials and skills remain unmanaged.

Ubuntu's Zellij and Codex versions are pinned in `home/.chezmoiexternal.toml`. To update a tool,
change its release URL and both architecture SHA-256 checksums using the official release assets,
then run verification and review the diff before applying.

Use `chezmoi cd` to edit `home/` or `winget.json`. For routine configuration updates:

```sh
chezmoi update --apply=false
chezmoi init
chezmoi diff --exclude scripts,externals
chezmoi apply --exclude scripts,externals
```

This applies configuration without installing apps or binaries or running scripts or sudo (downloads may still occur).
To intentionally install missing apps or host components, or update pinned external binaries, use full setup during
an appropriate maintenance window instead:

```sh
chezmoi diff
chezmoi apply
```

## Verification

From the repository (`chezmoi cd`):

Windows: with PowerShell 7.5+ and chezmoi on PATH, run `./tests/verify-windows.ps1`.
Ubuntu checks: with Docker running and network access, run these commands in PowerShell or Bash:

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```

Ubuntu amd64/arm64 checks use disposable command mocks, non-root execution, no real sudo and no Docker socket.
Real APT resolution, SSH, Secure Boot and GPU containers are **unverified**. After hardware acceptance, record the
OS/architecture/GPU/kernel/driver/Toolkit versions here and check that existing containers retain their ID/start time across apply.
