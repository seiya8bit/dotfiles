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
Use `zj attach --create work` to create or reattach to a session, and `zj list-sessions` to list sessions.
After applying alias changes, run `source ~/.bash_aliases` in existing Bash shells or open a new shell.
Codex CLI installs as your normal user without sudo or Node.js. Enable device code login in your
ChatGPT security settings or workspace permissions, then run `codex login --device-auth` on the server.
Open the printed URL in a browser on another device and enter the one-time code there; the server needs no browser.
After signing in, run `codex` from a project directory. See the [official authentication guide](https://learn.chatgpt.com/docs/auth#login-on-headless-devices).
Missing Tailscale installs through its [official installer](https://tailscale.com/install.sh) using sudo; sign in with `sudo tailscale up`.

## Ubuntu host services

Normal `chezmoi apply` uses sudo to install missing host packages, create verified APT keys/sources,
add the invoking user to the Docker group and start enabled services. Disabled/masked services stay unchanged.
The hooks do not request service restarts or OS reboots.

| Component | Installation |
| --- | --- |
| Docker, Compose, Buildx | [Docker stable APT](https://docs.docker.com/engine/install/ubuntu/): `docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin`. |
| SSH | Ubuntu `openssh-server`; new installs use socket activation. Existing service/socket policy, configuration, keys and firewall rules remain. |
| NVIDIA driver | [Ubuntu](https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/) `ubuntu-drivers list --gpgpu --recommended`, then APT installs signed modules and the driver. Working drivers remain; no automatic DKMS fallback. |
| GPU containers | NVIDIA stable APT `nvidia-container-toolkit-base`; the packaged [CDI refresh service](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html) maintains device specifications. |

GPU containers use native CDI: [Docker 29.2+ `--gpus all`](https://docs.docker.com/engine/release-notes/29/#2920),
[Compose 2.30+ `gpus: all`](https://docs.docker.com/reference/compose-file/services/#gpus) and Toolkit 1.18+.
No NVIDIA PCI GPU skips NVIDIA setup. WSL, Jetson/L4T, unsupported GPU/kernel recommendations and broken
drivers stop with an explanation; automatic GPU setup targets amd64 / arm64 SBSA.

APT resolves dependencies and preserves conffiles; [package operations can restart services](https://discourse.ubuntu.com/t/needrestart-changes-in-ubuntu-24-04-service-restarts/44671).
Existing Docker installations keep their package source. Conflicting packages, settings and APT keys/sources
require manual resolution; no automatic removal, migration or configuration replacement occurs.
Vendor keys are SHA-256 verified; review key rotation before changing template checksums.
Failures fail apply; resolve the reported issue and rerun. Completed installations do not repeat.

After apply, follow the reported manual actions:

- Log out and back in for the **root-equivalent** [Docker group](https://docs.docker.com/engine/install/linux-postinstall/).
- Reboot after driver installation, enroll a Secure Boot key if requested, then rerun apply.
- If Docker predates Toolkit, restart Docker in a maintenance window (or reboot) for `--gpus all`.
  New installs put Toolkit first. Older Docker or custom/disabled CDI needs manual setup using the original package source.

Verify after reboot/relogin: `docker run --rm hello-world`, `docker compose version`, `docker buildx version`,
a new SSH connection, `nvidia-smi -L`, and `docker run --rm --gpus all ubuntu:26.04 nvidia-smi`.
Host checks never start containers. Keep project runtimes, SDKs and databases in containers.
Project CUDA compatibility, images, clones, `.env`, data, models and credentials remain outside this repository.

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

Hooks live in `home/.chezmoiscripts/{ubuntu,windows}/`. The Ubuntu host entrypoint assembles common, Docker,
OpenSSH and NVIDIA parts from `home/.chezmoitemplates/ubuntu-host/`; these sources are not installed into the home directory.

From the repository (`chezmoi cd`):

Windows: with PowerShell 7.5+ and chezmoi on PATH, run `./tests/verify-windows.ps1`.
Ubuntu checks: with Docker running and network access, run these commands in PowerShell or Bash:

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```

Ubuntu checks use disposable command mocks, non-root execution, no real sudo and no Docker socket on amd64/arm64.
They cover preview/configuration-only isolation, provisioning, retries, CDI, conflicts and failures. Real APT resolution,
SSH connections, Secure Boot and GPU containers are **unverified**. Record tested OS/architecture/GPU/kernel/driver/Toolkit
versions here after hardware acceptance; also confirm existing containers retain their ID/start time across apply.
