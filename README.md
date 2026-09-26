# dotfiles

Windows 11 x64 / Ubuntu Server 26.04 LTS amd64 or arm64, chezmoi 2.72.1+, applied to freshly installed machines.
Fork, edit [winget.json](winget.json) and use your fork URL below.

## Setup policy

- Priorities: preserve data and settings, limit disruption, then repeatability and low maintenance. Stop on errors instead of repairing.
- Install only through package managers: WinGet via `winget.json`; APT from the Ubuntu archive, then vendor repositories trusted by key fingerprint; mise only for personal CLIs without an APT repository. No piped install scripts or unmanaged downloads, and no tool from two managers.
- Everything tracks the latest release, and `update` upgrades it all. Pin only what must stay: a WinGet package with a `Version` in `winget.json` is installed at and pinned to it (CLIP STUDIO PAINT EX 5.0.4: perpetual license).
- Removing a package from a list does not uninstall it. Never remove packages, change sudoers or reboot automatically; package scripts may start their own services. Firmware and Secure Boot enrollment are manual.
- Project runtimes, SDKs and databases live in containers, not mise. Credentials and personal agent settings/skills stay outside this repository.

## Windows

Finish Windows Update and enable CPU virtualization. For AMD GPUs, run [AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) (Recommended driver, no Factory Reset). In **administrator PowerShell**:

```powershell
wsl --install --no-distribution --web-download
winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
```

No WinGet? Update App Installer in Microsoft Store. After any restart, open **PowerShell 7.5+** (not administrator). Documents must not be redirected.

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
chezmoi init --apply https://github.com/seiya8bit/dotfiles
```

Then: select `JetBrainsMono Nerd Font Mono` in Windows Terminal, enable Docker Desktop's WSL 2 engine, run `docker run --rm hello-world`, and sign in to apps.

## Ubuntu Server

Installs Docker/Compose/Buildx, SSH, Tailscale, Claude Code, tmux and zoxide with APT, Codex, OpenCode and chezmoi with mise, and NVIDIA drivers/Container Toolkit when an NVIDIA GPU is present. You join the **root-equivalent Docker group**.

```sh
sudo add-apt-repository -y ppa:jdxcode/mise
sudo apt-get install -y mise
mise exec chezmoi@latest -- chezmoi init --apply https://github.com/seiya8bit/dotfiles
```

Then reboot if apply asks (NVIDIA: enroll Secure Boot at the console if asked); otherwise log out and reconnect. Verify without sudo, and test SSH from another machine:

```sh
docker run --rm hello-world
codex --version && claude --version && opencode --version
nvidia-ctk cdi list                            # NVIDIA: expect nvidia.com/gpu=all
docker run --rm --gpus all ubuntu:26.04 nvidia-smi   # NVIDIA: shows your GPU
```

Sign in: `sudo tailscale up`; `codex login --device-auth` (enable device code login in ChatGPT settings first); run `claude`, or `opencode` then `/connect`, and open the shown URL on another device.
`tmux new -A -s work` opens or reattaches a session; `z` jumps to visited directories.

## Updates

Run `update` in a new shell. It runs `chezmoi update`, then upgrades mise tools and APT packages (Ubuntu) or all unpinned WinGet packages (Windows), and reports a required reboot. Upgrades may restart services such as Docker and its containers.

Edit sources via `chezmoi cd`. Add packages to `winget.json`, the [Ubuntu package script](home/.chezmoiscripts/ubuntu/run_onchange_after_install-packages.sh.tmpl) or the [mise configuration](home/dot_config/mise/config.toml), preferring APT over mise; each reruns on the next apply when changed.

Personal overrides stay unmanaged and are never created by automation: `~/.gitconfig.local`, host-specific Windows `$PROFILE`, and `~/.bashrc`. Change Git identity with `chezmoi init --prompt`.

## Verification

For behavior changes, run the affected platform: `./tests/verify-windows.ps1` on Windows (WinGet mocked), and for Ubuntu the same container as CI, which installs real packages:

```sh
docker build --tag dotfiles-verify .devcontainer
docker run --rm --env GITHUB_TOKEN --mount "type=bind,source=$PWD,target=/workspaces/dotfiles,readonly" dotfiles-verify bash tests/verify-ubuntu.sh
```

CI also runs weekly to catch upstream package, repository and key changes. Documentation-only edits need reference checks and `git diff --check`.
**Services, SSH, Secure Boot, the NVIDIA branch and real WinGet installs remain unverified.** Record hardware acceptance here with OS/architecture/GPU/kernel/driver/Toolkit versions.
