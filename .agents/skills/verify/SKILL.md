---
name: verify
description: Choose and run this dotfiles repository's checks for the current change, then report results. Use before committing, opening or merging a PR, after a refactor, or when asked to verify, test or check a change.
---

# Verify

1. Collect changed paths: `git status --short` and `git diff --name-only main...HEAD`.
2. Always run `git diff --check`. Pick the rest from [README Verification](../../../README.md#verification):
   - Windows-only paths (`windows`, `Documents/PowerShell`, `winget.json`) → `./tests/verify-windows.ps1`.
   - Ubuntu-only paths (`ubuntu`, bash files, `.chezmoiexternal.toml`, `.devcontainer/`) → the Ubuntu Docker commands.
   - Any other file under `home/`, `tests/` or `.github/`, or `.chezmoiroot`/`.chezmoiversion` → both.
   - Docs and agent files only → reference checks: links and anchors resolve, and every mentioned path, command and version exists in the repository.
3. A platform you cannot run here (wrong OS, no Docker) is **not run**, never passed; the PR's CI covers it.
4. Fix only failures your change caused and rerun. Report failures that also occur on `main` without fixing them.
5. Report three separate sections:
   - **Implementation**: what changed.
   - **Checks**: each command and pass/fail/not run, with the failing output excerpt.
   - **Real-machine acceptance**: what remains unverified per README (real APT, SSH, Secure Boot, GPU containers). Tests never prove it.
