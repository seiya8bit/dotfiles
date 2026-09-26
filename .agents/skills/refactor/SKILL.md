---
name: refactor
description: Simplify this dotfiles repository without changing behavior or policy. Use when asked to refactor, clean up, simplify or deduplicate scripts, templates, tests or docs.
---

# Refactor

A refactor changes no behavior, rendered output or policy. Anything that does is a separate `feat:` or `fix:` the user decides on.

1. Name the scope and the behavior that must stay identical.
2. Run the `verify` skill first, so existing failures are not blamed on the refactor.
3. Where chezmoi is installed, save `chezmoi execute-template --file <source>` for each touched template.
4. Delete first, then reuse what exists, then package-manager or chezmoi features, then shorter code. Keep error handling and key fingerprint checks.
5. Re-render and diff against step 3; any difference is a behavior change.
6. Run `verify`, then `review-change` on your diff. Commit as `refactor:`.
