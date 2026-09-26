#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Ubuntu verification failed at line $LINENO" >&2' ERR

# This installs real packages, so it only runs in the disposable verification container.
if [[ ! -e /.dockerenv ]]; then
    echo 'Run inside the dotfiles-verify container (see README).' >&2
    exit 1
fi

repository=$(cd "$(dirname "$0")/.." && pwd)
script="$repository/home/.chezmoiscripts/ubuntu/run_onchange_after_install-packages.sh.tmpl"
shellcheck "$0"

# Bootstrap as in README, from this checkout instead of GitHub.
sudo add-apt-repository -y ppa:jdxcode/mise
sudo apt-get install -y mise
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
test ! -e "$HOME/Documents"
bash -ic 'type update z' > /dev/null 2>&1

test "$(git config --global --includes user.name)" = 'Test User'
git config --file "$HOME/.gitconfig.local" user.name 'Local User'
test "$(git config --global --includes user.name)" = 'Local User'
chezmoi apply --no-tty
test "$(git config --global --includes user.name)" = 'Local User'

echo 'Ubuntu: bootstrap, packages, mise tools, shell and Git configuration passed.'
