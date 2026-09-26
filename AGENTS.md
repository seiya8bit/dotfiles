# Agent instructions

- Follow README's [Policy](README.md#policy); change it only on the user's decision or new evidence, recommending one default and its tradeoffs.
- Edit sources in `home/`; never create or overwrite the files README lists as never managed.
- Delete before adding; prefer package-manager and chezmoi features; add no file, dependency, option or abstraction without a current need.
- Keep templates rendering on Windows, Ubuntu, WSL and other Linux, installer failures stopping apply, and a second apply changing nothing. New behavior gets a test.
- Run README's [Verification](README.md#verification) where possible and fix what you broke. Report implementation, checks (pass/fail/not run) and hardware acceptance separately.
- English code and docs, replies in the user's language; setup docs only in README. Conventional Commits, one squash-merged PR per change.
