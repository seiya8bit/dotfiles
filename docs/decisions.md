# Decisions

Keep entries current; delete those that no longer constrain anything. Counts are from agent transcripts and PowerShell history on this machine, as of 2026-11-04.

## Design

- **Windows only:** the user uses nothing else. WSL comes from a setup step, only as Docker Desktop's backend.
- **chezmoi data files:** merging `.chezmoidata` gives one file per tool without a custom generator. Rejected: Nix (no native Windows support).
- **One file per tool:** one rule for everything, at the cost of many package-only files. Rejected: `winget.json` plus config files, which splits a tool in two.
- **One `winget install` per package:** `winget import` cannot pass Build Tools' installer arguments. Exit `-1978335135` means already installed, verified on real WinGet.
- **Human setup is opt-in:** the profile needs a terminal and no agent variable. A missed setting costs a person; a leaked alias misleads every agent run. Rejected: human default with agent exclusions.
- **No agent-only variables:** Claude Code sets `GIT_EDITOR=true` itself and no other agent is installed. Rejected: the same variable in the user environment, which agents started from a human shell lost and which disabled editors in other human shells. Revisit if another agent is installed.
- **mise shims on PATH:** agent shells skip profiles, so `mise activate` would not reach them. Cost: `mise.toml` `[env]` does not load. PATH is read unexpanded to keep `%VARIABLE%`, and only this entry is managed, so it stays if mise goes.
- **Bitwarden SSH agent:** keys stay in Bitwarden. Git uses Windows OpenSSH because Git for Windows' ssh cannot read the agent's named pipe. The `ssh-agent` service would compete for that pipe, and disabling it is a Person step because it is a system setting.
- **`.wslconfig`:** `sparseVhd` applies only to new disks, so it must exist before Docker Desktop's first start.
- **No scheduled CI:** the test mocks WinGet and mise, so a schedule adds nothing.
- **No Claude Code deny rules:** SSH keys stay in Bitwarden, `pip` has 0 runs and Windows has no `sudo`, leaving only `.env`. That does not justify managing the personal `~/.claude/settings.json`.
- **Not managed:** `~/.ssh/config` (this repository is public and it names private hosts), VS Code settings (Settings Sync), Windows Terminal `settings.json` (Terminal rewrites it), and PowerToys, Start menu and taskbar state (per-machine or binary).
- **Docs:** `AGENTS.md` loads every session, so it stays small. One decisions file needs no index, unlike per-file ADRs. Rejected: "as short as possible" as the docs rule, because shortening in #39 lost rules that had to be restored.

## Fonts

- **Japanese:** BIZ UDGothic.
- **Everything else:** JetBrainsMono Nerd Font, from the `jetbrains-mono-nerd-font` tool. Terminals use its fixed-width family, `JetBrainsMono NFM`.

## Pinned versions

- **CLIP STUDIO PAINT 5.0.4:** perpetual license.
- **Node `lts`:** a moving channel, not a pin. `cf` supports only even release lines (`^22.23.0 || ^24.22.0 || ^26.12.0`), which `latest` leaves when an odd release ships.
- **`cf` beta:** mise's `latest` skips prereleases and gives 0.15.0. Use `latest` from 1.0.0.

## Tools

- **`python`, `pnpm`:** 1,289 and 483 runs, so global through mise.
- **`cf`, Supabase CLI:** requested by the user. Supabase has no WinGet package and refuses global npm. Rejected: Scoop, a second package manager.
- **Godot:** through mise rather than WinGet, so projects can pin versions in `mise.toml`.
- **Wrangler:** not installed; Cloudflare is moving to `cf`.
- **`eza`:** `ls` is the most used human command, at 511 of 2,317 PowerShell history lines, so it stays for people.
- **FFmpeg:** rejected. 2 agent runs and no human history lines.
- **Starship:** rejected. It added about 1.2 s to every human shell start.
- **`bat`, `delta`, `fzf`:** rejected. `cat` 10, `git diff` 1 and `fzf` 0 lines in the same history; all 45 `git log` lines use `--oneline`, which shows no diffs.
- **LINE:** from the Store, the only package source.
- **AMD Software, XPPenTablet:** Person steps. WinGet has only AMD's cloud edition and nothing from XP-Pen.
- **`jq`:** rejected. 3 runs, and native `jq.exe` writes CRLF in Git Bash.
- **`rg`, `fd`, `yq`:** rejected. 3, 1 and 0 runs.
