---
name: verify
description: Choose and run this dotfiles repository's checks for the current change, then report results. Use before committing, opening or merging a PR, after a refactor, or when asked to verify, test or check a change.
---

# Verify

1. Changed paths: `git status --short` and `git diff --name-only main...HEAD`.
2. Always run `git diff --check`, then pick from [README Verification](../../../README.md#verification):
   - Windows: `home/.chezmoiscripts/windows/`, `home/Documents/`, `winget.json`, `tests/verify-windows.ps1` → `./tests/verify-windows.ps1`.
   - Ubuntu: `home/.chezmoiscripts/ubuntu/`, `home/dot_bash_aliases`, `home/dot_config/`, `bootstrap.sh`, `tests/verify-ubuntu.sh`, `tests/Dockerfile` → `bash tests/verify-ubuntu.sh`.
   - Docs and agent files (`*.md`, `.agents/`, `.claude/`) → every link, anchor, path and command they mention exists.
   - Any other file → both.
3. A check this machine cannot run (wrong OS, no Docker or chezmoi) is **not run**, never passed; name the CI job that would run it, and say if CI did not run.
4. Fix failures your change caused and rerun. Report failures that also happen on `main` without fixing them.
5. Report separately: implementation, each check as pass/fail/not run with the failing excerpt, and the hardware acceptance README lists as unverified.
