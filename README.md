# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 and arm64 setup with chezmoi 2.72.1+.
Fork this repository, edit the [Windows app list](winget.json) and use your fork URL below.
Setup requires internet access; init prompts for your Git name and email.

Apply manages `.gitconfig`, the Windows common PowerShell profile and Ubuntu's `.bash_aliases`, `~/.local/bin/zellij` and `~/.local/bin/codex`.
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

chezmoi uses umask `022`: managed regular files use `0644`, and managed directories and executables use `0755`,
regardless of your shell's umask.

Log in again to keep `~/.local/bin` on PATH; run `zellij` to start a terminal session.
Ubuntu's default Bash configuration loads the managed `.bash_aliases`, which defines `zj` as `zellij`.
Apply installs [zoxide from Ubuntu APT](https://packages.ubuntu.com/resolute/zoxide) if missing;
`.bash_aliases` initializes it when available. Use `z` to revisit directories.
Use `zj attach --create work` to create or reattach to a session, and `zj list-sessions` to list sessions.
After applying alias changes, run `source ~/.bash_aliases` in existing Bash shells or open a new shell.
Codex CLI installs as your normal user without sudo or Node.js. Enable device code login in your
ChatGPT security settings or workspace permissions, then run `codex login --device-auth` on the server.
Open the printed URL in a browser on another device and enter the one-time code there; the server needs no browser.
After signing in, run `codex` from a project directory. See the [official authentication guide](https://learn.chatgpt.com/docs/auth#login-on-headless-devices).
Missing Tailscale installs through its [official installer](https://tailscale.com/install.sh) using sudo; sign in with `sudo tailscale up`.

## Ubuntu host services

Normal `chezmoi apply` uses sudo to install missing packages and verified APT keys/sources, add you to the
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
Conflicting packages, settings and APT keys/sources require manual resolution. On failure, resolve the reported issue
and rerun apply; completed installations do not repeat. After apply, follow the reported manual actions:

- Log out and back in for the **root-equivalent** [Docker group](https://docs.docker.com/engine/install/linux-postinstall/).
- Reboot after driver installation, enroll a Secure Boot key if requested, then rerun apply.
- If Docker predates Toolkit, restart Docker in a maintenance window (or reboot) for `--gpus all`.
  Older Docker or custom/disabled CDI needs manual setup using the original package source.

Verify after reboot/relogin: `docker run --rm hello-world`, `docker compose version`, `docker buildx version`
and a new SSH connection. For NVIDIA GPUs, run `nvidia-ctk cdi list`. If `nvidia-smi` is installed, also run `nvidia-smi -L` and
`docker run --rm --gpus all ubuntu:26.04 nvidia-smi`. Test CUDA workloads separately in the project's containers.
Keep project runtimes, SDKs and databases in containers; project images, CUDA compatibility, clones, `.env`, data,
models and credentials remain outside this repository.

## Personal settings and updates

Change your Git identity with `chezmoi init --prompt`, then review and apply.
Create `~/.gitconfig.local` for Git overrides and the host-specific `$PROFILE` for Windows PowerShell settings.
These take precedence over shared settings. Keep credentials and signing keys out of the repository.
Personal Codex settings, credentials and skills remain unmanaged.

Ubuntu's Zellij and Codex versions are pinned in `home/.chezmoiexternal.toml`. To update a tool,
change its release URL and both architecture SHA-256 checksums using the official release assets,
then run verification and review the diff before applying.

Use `chezmoi cd` to edit `home/` or `winget.json`. To retrieve and apply repository updates:

```sh
chezmoi update --apply=false
chezmoi init
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

Ubuntu amd64/arm64 checks use disposable command mocks, non-root execution, no real sudo and no Docker socket.
Real APT resolution, SSH, Secure Boot and GPU containers are **unverified**. After hardware acceptance, record the
OS/architecture/GPU/kernel/driver/Toolkit versions here and check that existing containers retain their ID/start time across apply.
