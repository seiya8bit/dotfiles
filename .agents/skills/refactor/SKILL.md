---
name: refactor
description: Simplify code in this dotfiles repository without changing behavior or policy. Use when asked to refactor, clean up, simplify or deduplicate scripts, templates, tests or docs.
---

# Refactor

A refactor changes no behavior, output or policy. Anything that does needs an explicit user decision and its own `feat:`/`fix:` change.

1. Name the scope and the behavior that must stay identical.
2. Run the `verify` skill first, so existing failures are not blamed on the refactor.
3. For each template you touch, save `chezmoi execute-template --file <source>` output for every OS branch, overriding `chezmoi.os` and `chezmoi.osRelease.id` with `--override-data` as `tests/verify-ubuntu.sh` does.
4. Apply the Ponytail ladder: delete first, then reuse what exists, then native features, then shorter code. Keep error handling, input validation and checksum checks.
5. Re-render and diff against step 3; any difference is a behavior change.
6. Run `verify`, then `review-change` on your own diff. Commit as `refactor:`.
