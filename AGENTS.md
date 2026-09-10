# Agent instructions

- Apply Ponytail throughout planning, design, implementation, refactoring and review: prefer native features, readable code and fewer dependencies. Consult official tool documentation.
- Write English code, comments and docs; respond in the user's language. Document current setup and usage in `README.md` only.
- Use Conventional Commits/Branch and squash merges; delete merged branches.
- Edit chezmoi sources in `home/`. Preserve unmanaged files and reject file/directory/link collisions before apply. Keep `.gitconfig.local` included last and host-specific PowerShell profiles unmanaged; never create or import personal overrides.
- Configuration-only apply (`--exclude scripts,externals`) must not install apps or binaries or run scripts or sudo. Keep pinned downloads checksum-verified and propagate installation failures. Delegate package validation and installation to WinGet using one manifest.
- Run Ubuntu Server 26.04 LTS chezmoi as a normal user. Automated sudo is limited to installing missing Tailscale through its official stable installer. Keep project runtimes, SDKs and databases in containers, and personal agent settings and skills outside this repository.
- Run `./tests/verify-windows.ps1` on native Windows and `bash tests/verify-ubuntu.sh` on Ubuntu with disposable destinations and mocked WinGet/Tailscale. Use the same `.devcontainer/Dockerfile` locally and in CI; run Ubuntu checks non-root, without sudo or a Docker socket.
