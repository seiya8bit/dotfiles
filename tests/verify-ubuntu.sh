#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Ubuntu verification failed at line $LINENO" >&2' ERR

repository=$(cd "$(dirname "$0")/.." && pwd)

# This installs real packages, so it reruns itself in a disposable container.
if [[ ! -e /.dockerenv ]]; then
    docker build --tag dotfiles-verify "$repository/tests"
    exec docker run --rm --env GITHUB_TOKEN         --mount "type=bind,source=$repository,target=/workspaces/dotfiles,readonly"         dotfiles-verify bash tests/verify-ubuntu.sh
fi
script="$repository/home/.chezmoiscripts/ubuntu/run_onchange_after_install-packages.sh.tmpl"
shellcheck "$0"

# Bootstrap as in README, from this checkout instead of GitHub.
curl -fsSL https://mise.jdx.dev/gpg-key.pub -o /tmp/mise.asc
gpg --show-keys --with-colons /tmp/mise.asc | grep -q '^fpr:::::::::24853EC9F655CE80B48E6C3A8B81C9D17413A06D:' &&
    sudo gpg --dearmor -o /etc/apt/keyrings/mise.gpg /tmp/mise.asc
printf '%s\n' 'Types: deb' 'URIs: https://mise.jdx.dev/deb' 'Suites: stable' 'Components: main' \
    'Signed-By: /etc/apt/keyrings/mise.gpg' | sudo tee /etc/apt/sources.list.d/mise.sources
sudo apt-get update && sudo apt-get install -y mise
mise exec chezmoi@latest -- chezmoi init --apply --no-tty --source "$repository" \
    --promptString 'Git name=Test User,Git email=test@example.invalid'

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
