---
name: review-change
description: Review a change in this dotfiles repository against its Policy and agent rules, for correctness and over-engineering. Use when asked to review a diff, branch or PR, before merging, or on your own change before reporting it done.
---

# Review change

Scope: the given PR or branch, else `git diff main...HEAD` plus uncommitted changes. Read each touched file fully and whatever renders, runs or tests it. Do not edit unless asked.

Check in this order:

1. **Correctness**: every OS branch of each template (Windows, Ubuntu, WSL, other Linux); installer failures stop apply; paths with spaces and non-ASCII; a second apply changes nothing.
2. **[Policy](../../../README.md#policy)**: each bullet, one by one.
3. **[AGENTS.md](../../../AGENTS.md)**: sources in `home/`, never-managed files untouched, new behavior tested, setup docs only in README, commit and branch names.
4. **Deletion**: what can be removed, reused, or replaced by a package-manager or chezmoi feature.

Findings most severe first, one per line: `path:line — problem — failure scenario — fix`. Nothing found → say so and name what was not checked.
