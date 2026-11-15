# Decisions

Keep entries current; delete those that no longer constrain anything. Counts are from the user's agent transcripts and PowerShell history as of 2026-11-04.

## Design

- **One file per tool:** `.chezmoidata` merges them without a custom generator, so one rule covers every tool, at the cost of many package-only files.
- **One `winget install` per package:** `winget import` cannot pass Build Tools' installer arguments. Exit `-1978335135` means already installed, verified on real WinGet.
- **Human setup is opt-in:** a missed setting costs a person; a leaked alias misleads every agent run.
- **mise shims on PATH:** agent shells skip profiles, so `mise activate` would not reach them. Cost: `mise.toml` `[env]` does not load. The environment script changes only this `PATH` entry, which stays if mise is removed.
- **Bitwarden SSH agent:** keys stay in Bitwarden. Git uses Windows OpenSSH because Git for Windows' ssh cannot read the agent's named pipe. Windows' `ssh-agent` service, disabled by default, would take that pipe, so it stays off. Agents cannot answer SSH's host key prompt, so a person accepts GitHub's key once. `gh` logs in with the SSH protocol because with HTTPS it writes a credential helper into the managed `~/.gitconfig`, and the next apply stops on that change.
- **`.wslconfig`:** `sparseVhd` applies only to new disks, so it must exist before Docker Desktop's first start.
- **`~/.claude/settings.json`:** the user chose to manage it, for clean installs. It is created only when absent: Claude Code writes to this file, so a managed copy would revert its changes. It holds only what shapes every session.
- **Docs:** agent instructions load every session, so they stay small.
- **Rulesync:** generated files are committed, as in Rulesync's FAQ, because a fresh clone, CI and GitHub need them. `rulesync gitignore` would ignore them, so `.gitignore` lists only per-person files. The `claudecode` target writes `CLAUDE.md`; the `agentsmd` target would prepend an empty heading to `AGENTS.md`.
- **Renovate:** Dependabot reads neither mise configuration nor tool files. Renovate's PRs merge themselves once CI passes. `mise.toml` pins Rulesync so that a release that changes the generated files fails only its own update PR.

## Pinned versions

- **CLIP STUDIO PAINT 5.0.4:** perpetual license.
- **Node `lts`:** a moving channel, not a pin. `cf` supports only even release lines (`^22.23.0 || ^24.22.0 || ^26.12.0`), which `latest` leaves when an odd release ships.
- **`cf` beta:** mise's `latest` skips prereleases and gives 0.15.0. Use `latest` from 1.0.0.

## Tools

- **`python`, `pnpm`:** 1,289 and 483 runs, so global through mise.
- **`cf`, Supabase CLI:** requested by the user. Supabase has no WinGet package and refuses global npm.
- **Godot:** through mise rather than WinGet, so projects can pin versions in `mise.toml`.
- **`eza`:** `ls` is the most used human command, at 511 of 2,317 PowerShell history lines, so it stays for people.
- **humanizer:** requested by the user for the English docs. Its `SKILL.md` is copied into `.rulesync/skills/`, because Rulesync's `install` and `fetch` read only `skills/<name>/SKILL.md` and humanizer keeps `SKILL.md` at its repository root.
- **AMD Software, XPPenTablet:** Person steps. WinGet has only AMD's cloud edition and nothing from XP-Pen.
