# dotfiles

Windows 11 x64 and Ubuntu Server 26.04 LTS (amd64/arm64), applied to fresh installs.

## Policy

- Preserve data and settings, then limit disruption, then stay repeatable and low-maintenance. Stop on errors; don't repair.
- Install only through package managers, one per tool: WinGet (`winget.json`); APT from the Ubuntu archive, else vendor repositories trusted by key fingerprint; mise only for CLIs without an APT repository. No piped install scripts or unmanaged downloads.
- Track latest releases. Pin only with a `Version` in `winget.json` (CLIP STUDIO PAINT 5.0.4: perpetual license).
- Never uninstall, change sudoers or reboot automatically; removing a package from a list leaves it installed.
- Project runtimes live in containers. Credentials and personal agent settings stay out of this repository.

## Windows

Finish Windows Update and enable CPU virtualization; for AMD GPUs run [AMD Auto-Detect](https://www.amd.com/en/resources/support-articles/faqs/GPU-131.html) (Recommended driver, no Factory Reset). In administrator PowerShell:

```powershell
wsl --install --no-distribution --web-download
winget install Git.Git twpayne.chezmoi Microsoft.PowerShell --exact
```

After any restart, in PowerShell 7 (not administrator):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
chezmoi init --apply https://github.com/seiya8bit/dotfiles
```

Then select `JetBrainsMono Nerd Font Mono` in Windows Terminal, enable Docker Desktop's WSL 2 engine and sign in to apps.

## Ubuntu Server

Setup disables SSH password login, so first add your key to `~/.ssh/authorized_keys` (installer import or `ssh-copy-id`).

```sh
git clone https://github.com/seiya8bit/dotfiles ~/.local/share/chezmoi
~/.local/share/chezmoi/bootstrap.sh
```

Reboot if asked (NVIDIA: enroll Secure Boot at the console), otherwise reconnect: you are now in the **root-equivalent** `docker` group. With an NVIDIA GPU, `docker run --rm --gpus all ubuntu:26.04 nvidia-smi` shows it.

Sign in: `sudo tailscale up`, `codex login --device-auth` (enable device code login in ChatGPT first), `claude`, and `opencode` then `/connect`. Ubuntu on WSL gets only the Git configuration.

## Maintenance

`update` (in a new shell) runs `chezmoi update`, upgrades everything unpinned and reports a required reboot. Add packages to `winget.json`, the [Ubuntu package script](home/.chezmoiscripts/ubuntu/run_onchange_after_install-packages.sh.tmpl) or the [mise configuration](home/dot_config/mise/config.toml); changed lists rerun on the next apply.

Never managed: `~/.gitconfig.local`, host-specific `$PROFILE` and `~/.bashrc`. Change Git identity with `chezmoi init --prompt`.

New Ubuntu LTS: change `FROM` in [tests/Dockerfile](tests/Dockerfile), the CI runners and this README's versions in one PR.

## Verification

Behavior changes: `./tests/verify-windows.ps1` (WinGet mocked) and `bash tests/verify-ubuntu.sh` (Docker, real packages). Docs only: check references and `git diff --check`.

CI also runs weekly for upstream package and key changes. GitHub stops that schedule after 60 idle days: re-enable it, and run it manually before any setup.

**Unverified: services, SSH, Secure Boot, NVIDIA and real WinGet installs.** Record hardware acceptance below; delete the NVIDIA branch if it has no row when the next LTS is adopted.

| Date | OS / architecture | GPU / kernel / driver / Toolkit | Result |
|---|---|---|---|
