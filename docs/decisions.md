# Decisions

Keep entries current; delete those that no longer constrain anything. Counts are from agent transcripts and PowerShell history on this machine, as of 2026-11-04.

## Design

- **One file per tool:** `.chezmoidata` merges them without a custom generator, so one rule covers every tool, at the cost of many package-only files.
- **One `winget install` per package:** `winget import` cannot pass Build Tools' installer arguments. Exit `-1978335135` means already installed, verified on real WinGet.
- **Human setup is opt-in:** a missed setting costs a person; a leaked alias misleads every agent run.
- **mise shims on PATH:** agent shells skip profiles, so `mise activate` would not reach them. Cost: `mise.toml` `[env]` does not load. Only this entry is managed, so it stays if mise goes.
- **Bitwarden SSH agent:** keys stay in Bitwarden. Git uses Windows OpenSSH because Git for Windows' ssh cannot read the agent's named pipe. The `ssh-agent` service would compete for that pipe, and disabling it is a Person step because it is a system setting.
- **`.wslconfig`:** `sparseVhd` applies only to new disks, so it must exist before Docker Desktop's first start.
- **`~/.claude/settings.json`:** the user chose to manage it, for clean installs. It is created only when absent: Claude Code writes to this file, so a managed copy would revert its changes. It holds only what shapes every session.
- **Docs:** `AGENTS.md` loads every session, so it stays small.

## Pinned versions

- **CLIP STUDIO PAINT 5.0.4:** perpetual license.
- **Node `lts`:** a moving channel, not a pin. `cf` supports only even release lines (`^22.23.0 || ^24.22.0 || ^26.12.0`), which `latest` leaves when an odd release ships.
- **`cf` beta:** mise's `latest` skips prereleases and gives 0.15.0. Use `latest` from 1.0.0.

## Tools

- **`python`, `pnpm`:** 1,289 and 483 runs, so global through mise.
- **`cf`, Supabase CLI:** requested by the user. Supabase has no WinGet package and refuses global npm.
- **Godot:** through mise rather than WinGet, so projects can pin versions in `mise.toml`.
- **`eza`:** `ls` is the most used human command, at 511 of 2,317 PowerShell history lines, so it stays for people.
- **AMD Software, XPPenTablet:** Person steps. WinGet has only AMD's cloud edition and nothing from XP-Pen.
