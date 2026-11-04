# Agent instructions

Dotfiles for Windows 11 x64, applied with chezmoi. Agents run most commands on this machine, so they are the primary users of the shell and of this repository.

## Map

- [README.md](README.md): setup, tasks, tool settings, failures and verification. Read only the section you need.
- [docs/decisions.md](docs/decisions.md): why things are as they are. Read the matching entry before changing, removing or re-adding anything it covers.
- `home/.chezmoidata/<tool>.toml`: one file per tool. The install script, profile, PATH and mise configuration are generated from these.
- `tests/verify-windows.ps1`: the only test.

## Policy

Change this section only on the user's decision or new evidence, recommending one default and its tradeoffs.

- Preserve data and settings, then limit disruption, then stay repeatable and low-maintenance. Stop on errors; don't repair.
- Agents first: every process gets the same PATH and unmodified commands. Aliases, prompts and interactive defaults go in `human`, which loads only for a person at a terminal.
- Install only through package managers, one per tool: WinGet; mise for language runtimes and CLIs without a WinGet package; rustup for Rust toolchains. No piped install scripts or unmanaged downloads.
- Track latest releases. Pin only for a need recorded in [decisions](docs/decisions.md#pinned-versions).
- Never uninstall, change system settings or reboot automatically.
- Keep credentials and personal agent settings out of this repository.

## Rules

- Edit sources in `home/`; never create or overwrite `~/.gitconfig.local` or the host-specific `$PROFILE`.
- Apply to a real home only when the user asks. First inspect `~/.gitconfig` and the PowerShell profile: symlinks or local content there get replaced.
- Delete before adding; prefer package-manager and chezmoi features; add no file, dependency, setting or abstraction without a current need.
- Keep installer failures stopping apply and a second apply changing nothing. New behavior gets a test.
- Run [Verification](README.md#verification) and fix what you broke. Report implementation, checks (pass/fail/not run) and hardware acceptance separately.
- Conventional Commits, one squash-merged PR per change. English code and docs; replies in the user's language.

## Docs

Agents read these literally, so write for that reader.

- Give exact commands that run without prompts, their expected result, and what to do on failure. Mark what only a person can do.
- Keep each fact in one place and link to it. State only what you verified.
- This file loads in every session: keep it to rules and pointers.
- Record a decision that was not obvious, or a rejected option an agent could reintroduce, in [decisions](docs/decisions.md).
