# Agent instructions

- Edit chezmoi sources in `home/`; preserve unmanaged files and personal overrides.
- Always apply the Ponytail skill during planning, design, implementation, refactoring and review; where the skill is unavailable, apply its principles directly. Prefer native features, readable code and fewer dependencies; preserve clear responsibility boundaries when simplifying.
- Write English code, comments and docs; respond in the user's language. Keep setup and usage documentation in `README.md` only.
- Use Conventional Commits/Branch and squash merges; delete merged branches.

## Task context

- Setup recommendations or changes: follow [Setup policy](README.md#setup-policy), including the automation boundaries. Recommend one default and explain material tradeoffs. Revise policy for explicit user decisions or new evidence; discussing an alternative alone does not change it.
- Configuration or pinned-version changes: follow [Updates](README.md#updates) for configuration-only apply, checksums and personal override boundaries.
- Behavior changes: use [Verification](README.md#verification) for the affected platforms. Documentation-only edits need reference and diff checks.

## Verification boundaries

The documented tests use disposable destinations and mocked provisioning commands. You may run them, fix failures caused by the requested change,
and rerun affected checks without asking for approval at each step. Preserve the documented test isolation.

Report implementation, checks actually run and real-machine acceptance separately. Mock success or package installation does not establish service/GPU readiness.
