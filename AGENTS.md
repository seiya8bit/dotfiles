# Agent instructions

Windows 11 x64 dotfiles, applied with chezmoi. Agents are the primary users.

- [README](README.md): setup, tasks, settings, failures, verification.
- [Decisions](docs/decisions.md): read the matching entry before changing what it covers.
- `home/.chezmoidata/<tool>.toml`: one file per tool; the install script, profile, PATH and mise configuration are generated from them.

## Policy

Change only on the user's decision or new evidence, recommending one default and its tradeoffs.

- Preserve data and settings, then limit disruption, then stay low-maintenance. Stop on errors; don't repair.
- Every process gets the same PATH and unmodified commands. Conveniences go in `human`.
- Install only through package managers, one per tool: WinGet; mise for runtimes and CLIs without a WinGet package; rustup for Rust toolchains.
- Tool files set global defaults; projects pin their own versions.
- Track latest. Pin only for a reason in [Decisions](docs/decisions.md#pinned-versions).
- Never uninstall, change system settings or reboot automatically.
- Keep credentials and personal agent settings out of this repository.

## Rules

- Edit sources in `home/`; never touch `~/.gitconfig.local` or the host-specific `$PROFILE`.
- Apply to a real home only when the user asks, after inspecting `~/.gitconfig` and the PowerShell profile: symlinks there get replaced.
- Delete before adding; add nothing without a current need.
- Installer failures stop apply, a second apply changes nothing, and new behavior gets a test.
- Run [Verification](README.md#verification). Report implementation, checks and hardware acceptance separately.
- Docs: as short as possible, prompt-free commands, each fact once, only what you verified. Record non-obvious decisions and rejected options in Decisions.
- Conventional Commits, one squash-merged PR per change. English code and docs; replies in the user's language.
