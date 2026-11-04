# Agent instructions

- Follow README's [Policy](README.md#policy); change it only on the user's decision or new evidence, recommending one default and its tradeoffs.
- Edit sources in `home/`; never create or overwrite the files README lists as never managed.
- A tool is one file in `home/.chezmoidata`, named after it, with the settings README's [Tools](README.md#tools) lists. Anything that only helps a person at a terminal goes in `human`; `path` must suit agents.
- Delete before adding; prefer package-manager and chezmoi features; add no file, dependency, setting or abstraction without a current need.
- Keep installer failures stopping apply and a second apply changing nothing. New behavior gets a test.
- Run README's [Verification](README.md#verification) where possible and fix what you broke. Report implementation, checks (pass/fail/not run) and hardware acceptance separately.
- English code and docs, replies in the user's language; setup docs only in README. Conventional Commits, one squash-merged PR per change.
