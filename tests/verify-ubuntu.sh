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

# The Ubuntu Server installer writes this when password login is allowed; the dotfiles setting must win.
sudo mkdir -p /etc/ssh/sshd_config.d
echo 'PasswordAuthentication yes' | sudo tee /etc/ssh/sshd_config.d/50-cloud-init.conf > /dev/null
bootstrap=("$repository/bootstrap.sh" --no-tty --promptString 'Git name=Test User,Git email=test@example.invalid')
if "${bootstrap[@]}"; then
    echo 'Apply disabled SSH passwords without an authorized key.' >&2
    exit 1
fi
mkdir -m 700 "$HOME/.ssh"
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDotfilesVerificationKeyOnly test' > "$HOME/.ssh/authorized_keys"
"${bootstrap[@]}"

export PATH="$HOME/.local/share/mise/shims:$PATH"
chezmoi execute-template --file "$script" | shellcheck -
shellcheck --shell=bash "$HOME/.bash_aliases"
test -z "$(chezmoi status)"

for command in chezmoi codex opencode claude tailscale docker zoxide; do
    "$command" --version
done
tmux -V
id -nG "$(id -un)" | grep -qw docker
sudo mkdir -p /run/sshd
sshd=$(sudo sshd -T)
grep -qx 'passwordauthentication no' <<< "$sshd"
grep -qx 'kbdinteractiveauthentication no' <<< "$sshd"
sudo unattended-upgrade --dry-run --debug 2>&1 | grep 'Allowed origins' | grep -q 'site=mise.jdx.dev'
test ! -e "$HOME/Documents"
test -z "$(WSL_DISTRO_NAME=Ubuntu chezmoi execute-template --file "$script")"
WSL_DISTRO_NAME=Ubuntu chezmoi ignored | grep -qx .bash_aliases
bash -ic 'type update z' > /dev/null 2>&1

test "$(git config --global --includes user.name)" = 'Test User'
git config --file "$HOME/.gitconfig.local" user.name 'Local User'
test "$(git config --global --includes user.name)" = 'Local User'
chezmoi apply --no-tty
test "$(git config --global --includes user.name)" = 'Local User'

echo 'Ubuntu: bootstrap, packages, mise tools, SSH, shell and Git configuration passed.'
