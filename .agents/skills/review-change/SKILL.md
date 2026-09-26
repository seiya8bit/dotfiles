---
name: review-change
description: Review a change in this dotfiles repository for correctness, Setup policy violations and over-engineering. Use when asked to review a diff, branch or PR, before merging, or on your own change before reporting it done.
---

# Review change

Scope: the given PR or branch, else `git diff main...HEAD` plus uncommitted changes. Read each touched file fully and whatever calls or renders it. Do not edit unless asked.

Check, in this order:

1. **Correctness**: templates render on every OS branch (Windows, Ubuntu, other); scripts stop on errors and propagate installer failures; paths with spaces and non-ASCII work; a second `chezmoi apply` changes nothing.
2. **[Setup policy](../../../README.md#setup-policy)**: flag anything that replaces or upgrades existing installations, disables vendor updates, removes packages, force-replaces settings, touches sudoers, restarts services or reboots, downloads without checksum verification, pins versions a tool's own updater owns, or adds credentials or personal agent settings.
3. **Boundaries**: chezmoi sources stay in `home/`; unmanaged personal overrides are never created or overwritten; setup and usage docs live only in README; new behavior has a test in `tests/`.
4. **Ponytail**: what can be deleted, reused or replaced with a native feature.

Output findings most severe first, one per line: `path:line — problem — concrete failure scenario — fix`. Recommend one fix per finding. Nothing found → say so and name what was not checked.
