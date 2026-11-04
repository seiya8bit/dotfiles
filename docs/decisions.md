# Decisions

Why this repository is the way it is. Update an entry when its decision changes; delete it when it no longer constrains anything. Usage counts come from 7,317 Claude Code and Codex commands recorded on this machine, as of 2026-11-04.

## Windows 11 only

- **Decision:** Support Windows 11 x64 only. `.chezmoi.toml.tmpl` refuses other systems.
- **Why:** The user no longer uses anything else.
- **Keep:** The `wsl` tool stays because Docker Desktop runs on WSL 2. It carries no Linux dotfiles.

## chezmoi data files

- **Decision:** Keep chezmoi and generate everything from `.chezmoidata` with templates.
- **Why:** chezmoi merges those files into one map, so one tool per file needs no custom generator. It also provides identity prompts, `run_onchange` and `verify`.
- **Rejected:** Nix, which has no native Windows support. A hand-written install script, which would reimplement what chezmoi already does.

## One file per tool

- **Decision:** Every tool has a file, even when it holds only a package.
- **Why:** One rule covers adding and removing anything, and a tool's package and configuration cannot drift apart.
- **Cost:** 32 of 36 files hold only a package. `winget export` and `winget import` no longer round-trip.
- **Rejected:** `winget.json` plus files only for configured tools, which puts a tool in two places once it gains a setting.

## One winget install per package

- **Decision:** Run `winget install --no-upgrade` for each package.
- **Why:** `winget import` cannot pass installer arguments, which the Build Tools C++ workload needs. One code path also handles `source`, `version` and `override`.
- **Verified:** A package already installed exits `-1978335135` (`0x8A150061`) on real WinGet. The script treats that as success.

## Human setup is opt-in

- **Decision:** `profile.ps1` returns unless stdin and stdout are a terminal and `CLAUDECODE`, `CODEX_SANDBOX`, `GEMINI_CLI`, `CURSOR_AGENT` and `AI_AGENT` are empty.
- **Why:** A forgotten human setting costs a person a moment; a leaked alias misleads every agent run.
- **Rejected:** Human setup by default with agent exclusions, because a missed exclusion hits agents.
- **Limit:** The host-specific `$PROFILE` is not managed, so it needs its own check.

## No agent-only variables

- **Decision:** Set no variable such as `GIT_EDITOR=true`, `PAGER=cat` or `GIT_TERMINAL_PROMPT=0`.
- **Why:** Claude Code 2.1.309 sets `GIT_EDITOR=true` itself, and no other agent is installed. Agents get no TTY, so pagers do not start.
- **Rejected:** `GIT_EDITOR=true` in the user environment, removed by the human profile. Agents started from a human shell then lost it, and `git rebase -i` in other human shells silently skipped the editor.
- **Revisit when:** An agent that does not handle this itself is installed.

## mise shims on PATH

- **Decision:** Put `%LOCALAPPDATA%\mise\shims` on the user PATH for everyone; do not use `mise activate`.
- **Why:** Agents start shells without a profile, so activation would never reach them. Shims still honor each project's `mise.toml`, and people and agents get the same behavior.
- **Cost:** `[env]` sections in `mise.toml` do not load in plain shells.

## PATH ownership

- **Decision:** Edit `HKCU\Environment` directly, and record our entries in `DOTFILES_PATH`.
- **Why:** The record lets a removed `path` setting disappear on the next apply. Reading the value unexpanded keeps the user's `%VARIABLE%` references.
- **Test:** The script changes the real environment, so only disposable CI runners execute it.

## Pinned versions

- **CLIP STUDIO PAINT 5.0.4:** Perpetual license.
- **`cf` beta:** mise's `latest` skips prereleases and resolves to 0.15.0, the last version before the beta, while Cloudflare's docs describe the beta. Use `latest` from 1.0.0.

## Agent CLIs

- **`python`, `pnpm`:** Installed globally through mise, at 1,289 and 483 runs. Projects pin their own versions.
- **`cf`, Supabase CLI:** The user asked for them. Supabase has no WinGet package and refuses global npm installs. Scoop would add a second general package manager.
- **Wrangler:** Not installed. Cloudflare is moving to `cf`; projects that still need it can pin it.
- **Rejected `jq`:** 3 runs, and native `jq.exe` writes CRLF in Git Bash without `-b`, so `$(jq -r ...)` keeps a trailing `\r`.
- **Rejected `rg`, `fd`, `yq`:** 3, 1 and 0 runs.
- **Revisit when:** Agents repeatedly hit `command not found` for a tool.

## CI

- **Decision:** Run the mocked test on pull requests, with no weekly schedule.
- **Why:** The schedule caught upstream Ubuntu package and key changes. The Windows test mocks WinGet and mise, so a schedule would exercise nothing new.

## Document layout

- **Decision:** `AGENTS.md` holds rules and pointers, `README.md` holds on-demand procedures, and this single file holds reasons.
- **Why:** `AGENTS.md` costs context in every session, while the others are read only when needed. Tests check links and the settings table because agents act on docs literally.
- **Rejected:** One ADR per file, which needs an index and more reads for this few short decisions.
- **Revisit when:** This file no longer reads quickly as a whole.
