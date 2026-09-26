# Agent instructions

- Edit chezmoi sources in `home/`; never create or overwrite the unmanaged personal overrides listed in README.
- Change as little as possible: delete before adding, reuse what exists, prefer package-manager and chezmoi features, and add no file, dependency, option or abstraction without a current need.
- Follow README's [Setup policy](README.md#setup-policy). Change it only on an explicit user decision or new evidence, recommending one default with its material tradeoffs.
- Keep templates rendering on Windows, Ubuntu, WSL and other Linux, installer failures stopping apply, and a second `chezmoi apply` changing nothing. New behavior gets a check in `tests/`.
- Run README's [Verification](README.md#verification) for the platforms you can, fixing failures your change causes without asking. Report implementation, checks (pass/fail/not run) and real-machine acceptance separately.
- English code and docs; respond in the user's language. Setup and usage docs live only in README. Conventional Commits and branch names; one squash-merged PR per change.
