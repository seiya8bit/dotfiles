# Decisions

Keep entries current; delete those that no longer constrain anything. Counts are from 7,317 agent commands on this machine, as of 2026-11-04.

## Design

- **Windows only:** the user uses nothing else. `wsl` stays only as Docker Desktop's backend.
- **chezmoi data files:** merging `.chezmoidata` gives one file per tool without a custom generator. Rejected: Nix (no native Windows support).
- **One file per tool:** one rule for everything, at the cost of many package-only files. Rejected: `winget.json` plus config files, which splits a tool in two.
- **One `winget install` per package:** `winget import` cannot pass Build Tools' installer arguments. Exit `-1978335135` means already installed, verified on real WinGet.
- **Human setup is opt-in:** the profile needs a terminal and no agent variable. A missed setting costs a person; a leaked alias misleads every agent run. Rejected: human default with agent exclusions.
- **No agent-only variables:** Claude Code sets `GIT_EDITOR=true` itself and no other agent is installed. Rejected: the same variable in the user environment, which agents started from a human shell lost and which disabled editors in other human shells. Revisit if another agent is installed.
- **mise shims on PATH:** agent shells skip profiles, so `mise activate` would not reach them. Cost: `mise.toml` `[env]` does not load.
- **`DOTFILES_PATH`:** records our PATH entries so removed ones disappear. PATH is read unexpanded to keep `%VARIABLE%`.
- **No scheduled CI:** the test mocks WinGet and mise, so a schedule adds nothing.
- **Docs:** `AGENTS.md` loads every session, so it stays small. One decisions file needs no index, unlike per-file ADRs.

## Fonts

- **Japanese:** BIZ UDGothic.
- **Everything else:** JetBrainsMono Nerd Font, from the `jetbrains-mono-nerd-font` tool. Terminals use its fixed-width family, `JetBrainsMono NFM`.

## Pinned versions

- **CLIP STUDIO PAINT 5.0.4:** perpetual license.
- **`cf` beta:** mise's `latest` skips prereleases and gives 0.15.0. Use `latest` from 1.0.0.

## Tools

- **`python`, `pnpm`:** 1,289 and 483 runs, so global through mise.
- **`cf`, Supabase CLI:** requested by the user. Supabase has no WinGet package and refuses global npm. Rejected: Scoop, a second package manager.
- **Godot:** through mise rather than WinGet, so projects can pin versions in `mise.toml`.
- **Wrangler:** not installed; Cloudflare is moving to `cf`.
- **`jq`:** rejected. 3 runs, and native `jq.exe` writes CRLF in Git Bash.
- **`rg`, `fd`, `yq`:** rejected. 3, 1 and 0 runs.
