#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Ubuntu verification failed at line $LINENO" >&2' ERR

repository=$(cd "$(dirname "$0")/.." && pwd)

# This installs real packages, so it reruns itself in a disposable container.
if [[ ! -e /.dockerenv ]]; then
    docker build --tag dotfiles-verify "$repository/tests"
    exec docker run --rm --env GITHUB_TOKEN \
        --mount "type=bind,source=$repository,target=/workspaces/dotfiles,readonly" \
        dotfiles-verify bash tests/verify-ubuntu.sh
fi

script="$repository/home/.chezmoiscripts/ubuntu/run_onchange_after_install-packages.sh.tmpl"
shellcheck "$0" "$repository/bootstrap.sh"

"$repository/bootstrap.sh" --no-tty --promptString 'Git name=Test User,Git email=test@example.invalid'

export PATH="$HOME/.local/share/mise/shims:$PATH"
chezmoi execute-template --file "$script" | shellcheck -
shellcheck --shell=bash "$HOME/.bash_aliases"
test -z "$(chezmoi status)"

for command in chezmoi codex opencode claude tailscale docker zoxide; do
    "$command" --version
done
tmux -V
id -nG "$(id -un)" | grep -qw docker
sudo unattended-upgrade --dry-run --debug 2>&1 | grep 'Allowed origins' | grep -q 'site=mise.jdx.dev'
test ! -e "$HOME/Documents"
bash -ic 'type update z' > /dev/null 2>&1

test "$(git config --global --includes user.name)" = 'Test User'
git config --file "$HOME/.gitconfig.local" user.name 'Local User'
test "$(git config --global --includes user.name)" = 'Local User'
chezmoi apply --no-tty
test "$(git config --global --includes user.name)" = 'Local User'

echo 'Ubuntu: bootstrap, packages, mise tools, shell and Git configuration passed.'
