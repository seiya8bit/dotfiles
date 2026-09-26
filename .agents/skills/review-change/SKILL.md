---
name: review-change
description: Review a change in this dotfiles repository against its Policy and agent rules, for correctness and over-engineering. Use when asked to review a diff, branch or PR, before merging, or on your own change before reporting it done.
---

# Review change

Scope: the given PR or branch, else `git diff main...HEAD` plus uncommitted changes. Read each touched file fully and whatever renders, runs or tests it. Do not edit unless asked.

Check each rule in [AGENTS.md](../../../AGENTS.md) and each [Policy](../../../README.md#policy) bullet, one by one, on every OS branch of each touched template and with paths containing spaces and non-ASCII. Then look for what can be deleted.

Findings most severe first, one per line: `path:line — problem — failure scenario — fix`. Nothing found → say so and name what was not checked.
