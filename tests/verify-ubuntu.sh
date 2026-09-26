#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Ubuntu verification failed at line $LINENO" >&2' ERR

if [[ $(uname -s) != Linux || $EUID == 0 || -e /var/run/docker.sock ]] || command -v sudo >/dev/null; then
    echo 'Run as a normal Ubuntu user without sudo or a Docker socket.' >&2
    exit 1
fi

repository=$(cd "$(dirname "$0")/.." && pwd)
chezmoi_bin=$(command -v chezmoi)
shellcheck --external-sources --source-path="$repository" "$repository/tests/verify-ubuntu.sh"

# Exercise Ubuntu's group-writable shell default with an existing 0755 bin directory.
umask 002

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
checkout="$temporary/checkout with spaces"
destination="$temporary/home with spaces"
chezmoi=("$chezmoi_bin" --config "$temporary/config.toml" --destination "$destination"
    --persistent-state "$temporary/state.boltdb" --cache "$temporary/cache" --no-tty --no-pager)
config_only=(--exclude 'scripts,externals')

mkdir -p "$checkout" "$destination/.local/bin" "$temporary/bin"
# Hooks install into $HOME; keep them inside the disposable destination.
export HOME="$destination"
chmod 755 "$destination/.local" "$destination/.local/bin"
cp "$repository/.chezmoiroot" "$repository/.chezmoiversion" "$checkout/"
cp -R "$repository/home" "$checkout/home"
"${chezmoi[@]}" init --source "$checkout" --promptString 'Git name=Test User,Git email=test@example.invalid'
"${chezmoi[@]}" init

external="$checkout/home/.chezmoiexternal.toml"
tools_hook="$checkout/home/.chezmoiscripts/ubuntu/run_after_install-tools.sh.tmpl"
"${chezmoi[@]}" execute-template --file "$tools_hook" | shellcheck -
host_hook="$checkout/home/.chezmoiscripts/ubuntu/run_after_setup-host.sh.tmpl"
"${chezmoi[@]}" execute-template --file "$host_hook" | shellcheck -

for source in "$external" "$tools_hook" "$host_hook"; do
    test -z "$("${chezmoi[@]}" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file "$source")"
    test -z "$("${chezmoi[@]}" --override-data '{"chezmoi":{"osRelease":{"id":"debian"}}}' execute-template --file "$source")"
done

if "${chezmoi[@]}" --override-data '{"chezmoi":{"arch":"riscv64"}}' execute-template --file "$external" > "$temporary/arch.log" 2>&1; then
    echo 'An unsupported architecture must fail.' >&2
    exit 1
fi
grep -q 'Zellij requires Ubuntu amd64 or arm64' "$temporary/arch.log"

zellij="$destination/.local/bin/zellij"
failed_destination="$temporary/failed-external-home"
cp "$external" "$temporary/external.toml"
printf '#!/bin/sh\necho untrusted\n' > "$temporary/zellij"
tar -czf "$temporary/zellij.tar.gz" -C "$temporary" zellij
for url in https://127.0.0.1:1/zellij.tar.gz "file://$temporary/zellij.tar.gz"; do
    sed -i "s|^url = .*|url = \"$url\"|" "$external"
    if "${chezmoi[@]}" --destination "$failed_destination" apply --exclude scripts > "$temporary/external.log" 2>&1; then
        echo "A failed or mismatched download must fail apply: $url" >&2
        exit 1
    fi
    grep -Eq '127\.0\.0\.1:1|SHA256 mismatch' "$temporary/external.log" || {
        cat "$temporary/external.log" >&2
        exit 1
    }
    test ! -e "$failed_destination/.local/bin/zellij"
    rm -rf "$failed_destination"
done
cp "$temporary/external.toml" "$external"

# Mock only the disposable host hook; no real sudo or Docker socket enters this container.
export DOTFILES_HOST_STATE="$temporary/host"
mkdir -p "$DOTFILES_HOST_STATE/etc" "$DOTFILES_HOST_STATE/run"
printf 'ID=ubuntu\nVERSION_ID=26.04\nVERSION_CODENAME=resolute\n' > "$DOTFILES_HOST_STATE/etc/os-release"
cp "$repository/tests/fixtures/ubuntu-host.sh" "$DOTFILES_HOST_STATE/mock.sh"
shellcheck --shell=bash --exclude=SC2329 "$DOTFILES_HOST_STATE/mock.sh"

fixture_sha=$(printf 'fixture-key\n' | sha256sum | cut -d ' ' -f 1)
sed -i "/^set -Eeuo pipefail$/a source \"$DOTFILES_HOST_STATE/mock.sh\"" "$host_hook"
sed -i "s|^etc=/etc$|etc=\"$DOTFILES_HOST_STATE/etc\"|; s|^run=/run$|run=\"$DOTFILES_HOST_STATE/run\"|; s|/usr/bin/nvidia-cdi-hook|$DOTFILES_HOST_STATE/mock.sh|; s|[a-f0-9]\{64\}|$fixture_sha|g" \
    "$host_hook" "$checkout/home/.chezmoitemplates/ubuntu-host/"*.tmpl
sed -i "s|/proc/driver/nvidia/version|$DOTFILES_HOST_STATE/nvidia-version|g" \
    "$checkout/home/.chezmoitemplates/ubuntu-host/nvidia.sh.tmpl"

printf 'docker-ce\ndocker-ce-cli\ncontainerd.io\ndocker-compose-plugin\ndocker-buildx-plugin\nopenssh-server\npciutils\n' > "$DOTFILES_HOST_STATE/packages"
printf 'docker.service\nssh.socket\nnvidia-cdi-refresh.path\n' > "$DOTFILES_HOST_STATE/active"
touch "$DOTFILES_HOST_STATE/group"

# Installed tools answer only version checks; configuration-only apply must not run them.
for command in tailscale claude codex opencode; do
    printf '#!/bin/sh\ntest "$*" = --version\necho %s >> "%s"\n' "$command" "$temporary/tool-calls" > "$temporary/bin/$command"
    chmod +x "$temporary/bin/$command"
done
export PATH="$temporary/bin:$PATH"

"${chezmoi[@]}" diff "${config_only[@]}" > /dev/null
"${chezmoi[@]}" apply --dry-run "${config_only[@]}"
test ! -e "$destination/.gitconfig"
"${chezmoi[@]}" apply "${config_only[@]}"
test ! -e "$DOTFILES_HOST_STATE/calls"
test ! -e "$temporary/tool-calls"

for directory in ubuntu windows ubuntu-host .chezmoiscripts .chezmoitemplates; do
    test ! -e "$destination/$directory"
done

test "$(stat -c %a "$destination/.gitconfig")" = 644
test "$(stat -c %a "$destination/.bash_aliases")" = 644
test "$(stat -c %a "$destination/.bashrc")" = 644
head -n "$(wc -l < /etc/skel/.bashrc)" "$destination/.bashrc" | cmp /etc/skel/.bashrc -
cp "$destination/.bashrc" "$temporary/expected-bashrc"
"${chezmoi[@]}" apply "${config_only[@]}"
cmp "$temporary/expected-bashrc" "$destination/.bashrc"

# Personal additions survive apply, and initialization moves after prompt settings.
printf '# Personal shell settings\nPROMPT_COMMAND=custom' >> "$destination/.bashrc"
"${chezmoi[@]}" apply "${config_only[@]}"
test "$(grep -c '^# >>> dotfiles: zoxide >>>$' "$destination/.bashrc")" = 1
test "$(tail -n 1 "$destination/.bashrc")" = '# <<< dotfiles: zoxide <<<'
cp "$destination/.bashrc" "$temporary/expected-bashrc"
HOME="$destination" bash --noprofile --norc -eic '
    [[ -z $(command -v zoxide) ]]
    source "$1"
    [[ -z $(declare -F z) ]]
    zoxide() {
        [[ $* == "init bash" ]] || return 1
        printf "%s\n" "z() { echo initialized; }" "PROMPT_COMMAND+=zoxide"
    }
    source "$1"
    [[ $(z) == initialized && $PROMPT_COMMAND == customzoxide ]]
    [[ -z $(declare -F cd) ]]
' bash "$destination/.bashrc" 2>"$temporary/bash-init.log"

# Reject damaged markers before they can consume personal settings on a later apply.
for edit in '/^# >>> dotfiles: zoxide >>>$/d' '/^# <<< dotfiles: zoxide <<<$/d' \
    '/^# >>> dotfiles: zoxide >>>$/a # >>> dotfiles: zoxide >>>' \
    's/^# <<< dotfiles: zoxide <<<$/& trailing comment/'; do
    sed "$edit" "$temporary/expected-bashrc" > "$destination/.bashrc"
    cp "$destination/.bashrc" "$temporary/damaged-bashrc"
    if "${chezmoi[@]}" apply --force "${config_only[@]}" > "$temporary/marker.log" 2>&1; then
        echo "Malformed Bash markers must fail apply: $edit" >&2
        exit 1
    fi
    grep -Fq 'Unbalanced zoxide block markers' "$temporary/marker.log"
    cmp "$temporary/damaged-bashrc" "$destination/.bashrc"
done
cp "$temporary/expected-bashrc" "$destination/.bashrc"
test ! -e "$zellij"
test ! -e "$destination/Documents"

git_config=(git config --file "$destination/.gitconfig" --includes)
test "$("${git_config[@]}" --get user.name)" = 'Test User'
test "$("${git_config[@]}" --get user.email)" = 'test@example.invalid'
test ! -e "$destination/.gitconfig.local"

git config --file "$destination/.gitconfig.local" user.name 'Local User'
git config --file "$destination/.gitconfig.local" user.email 'local@example.invalid'
cp "$destination/.gitconfig" "$temporary/expected-git"
cp "$destination/.gitconfig.local" "$temporary/expected-local"

mkdir -p "$destination/Documents/PowerShell"
printf '# Unmanaged profile\n' > "$destination/Documents/PowerShell/profile.ps1"
mkdir -p "$destination/.codex" "$destination/.agents/skills/personal" "$destination/.claude" "$destination/.config/opencode"
printf '# Unmanaged Codex settings\n' > "$destination/.codex/config.toml"
printf '{"test":"unmanaged credential fixture"}\n' > "$destination/.codex/auth.json"
printf '# Unmanaged skill\n' > "$destination/.agents/skills/personal/SKILL.md"
printf '# Unmanaged Claude settings\n' > "$destination/.claude/settings.json"
printf '{"test":"unmanaged OpenCode settings"}\n' > "$destination/.config/opencode/opencode.json"
cp -R "$destination/.codex" "$temporary/expected-codex"
cp -R "$destination/.claude" "$temporary/expected-claude"
cp -R "$destination/.config/opencode" "$temporary/expected-opencode"

# Reject every managed file and ancestor collision before writing any configuration.
mkdir "$temporary/link-target"
for relative in .bash_aliases .bashrc .gitconfig .local .local/bin .local/bin/zellij; do
    conflict="$temporary/conflict-home/$relative"
    mkdir -p "$(dirname "$conflict")"
    for kind in link collision; do
        if [[ $kind == link ]]; then
            ln -s "$temporary/link-target" "$conflict"
        elif [[ $relative == .local || $relative == .local/bin ]]; then
            printf 'unmanaged\n' > "$conflict"
        else
            mkdir "$conflict"
        fi
        if "${chezmoi[@]}" --destination "$temporary/conflict-home" apply --force > "$temporary/conflict.log" 2>&1; then
            echo "Accepted $kind at $relative." >&2
            exit 1
        fi
        grep -q 'must be a regular' "$temporary/conflict.log"
        if [[ $relative == .local && $kind == link ]]; then
            if "${chezmoi[@]}" --destination "$temporary/conflict-home" apply --force "${config_only[@]}" > "$temporary/conflict.log" 2>&1; then
                echo 'Configuration-only apply accepted a managed path collision.' >&2
                exit 1
            fi
            grep -q 'must be a regular' "$temporary/conflict.log"
        fi
        [[ $relative == .gitconfig ]] || test ! -e "$temporary/conflict-home/.gitconfig"
        test -z "$(ls -A "$temporary/link-target")"
        if [[ $kind == link ]]; then
            test -L "$conflict"
            rm "$conflict"
        elif [[ -d $conflict ]]; then
            rmdir "$conflict"
        else
            grep -qx unmanaged "$conflict"
            rm "$conflict"
        fi
    done
done

"${chezmoi[@]}" diff > /dev/null
"${chezmoi[@]}" apply --dry-run > /dev/null
test ! -e "$DOTFILES_HOST_STATE/calls"
test ! -e "$zellij"

"${chezmoi[@]}" apply
printf 'tailscale\nclaude\ncodex\nopencode\n' | cmp - "$temporary/tool-calls"
for path in "$destination/.local/bin" "$zellij"; do
    test "$(stat -c %a "$path")" = 755
done
sha256sum "$zellij" > "$temporary/expected-binaries"
zellij_version=$("$zellij" --version)
[[ $zellij_version == zellij\ * ]]
test "$(HOME="$destination" PATH="$destination/.local/bin:$PATH" bash --noprofile --rcfile "$destination/.bashrc" \
    -ic 'zj --version' 2>"$temporary/bash.log")" = "$zellij_version"
HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply

printf '#!/bin/sh\necho modified\n' > "$temporary/modified-binary"
cp "$temporary/modified-binary" "$zellij"
HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply "${config_only[@]}"
cmp "$temporary/modified-binary" "$zellij"

HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply --exclude scripts --force
sha256sum --check --status "$temporary/expected-binaries"

# Isolate PATH so every tool is missing, including on hosts that already have them.
export DOTFILES_TOOLS_BIN="$temporary/tools-bin" DOTFILES_TOOLS_LOG="$temporary/tools-runs"
mkdir "$DOTFILES_TOOLS_BIN"
for command in bash sh cat chmod env ln mkdir sed; do
    ln -s "$(command -v "$command")" "$DOTFILES_TOOLS_BIN/$command"
done
cat > "$DOTFILES_TOOLS_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# == 5 && "$1 $2 $3 $4" == '--fail --location --silent --show-error' ]]
case "$5" in
    https://tailscale.com/install.sh) tool=tailscale ;;
    https://claude.ai/install.sh) tool=claude ;;
    https://chatgpt.com/codex/install.sh) tool=codex ;;
    https://opencode.ai/install) tool=opencode ;;
    *) exit 99 ;;
esac
echo "download $tool" >> "$DOTFILES_TOOLS_LOG"
[[ ${DOTFILES_TOOLS_FAILURE-} != "download $tool" ]]
sed "s/@TOOL@/$tool/g" "$DOTFILES_TOOLS_BIN/installer.sh"
EOF
cat > "$DOTFILES_TOOLS_BIN/installer.sh" <<'EOF'
set -eu
echo "install @TOOL@${*:+ $*}" >> "$DOTFILES_TOOLS_LOG"
test -f "$CHEZMOI_DEST_DIR/.gitconfig"
test "${DOTFILES_TOOLS_FAILURE-}" != 'install @TOOL@'
case @TOOL@ in
    tailscale) test "$TRACK" = stable; directory=$DOTFILES_TOOLS_BIN ;;
    codex) test "$CODEX_NON_INTERACTIVE" = 1; directory=$HOME/.local/bin ;;
    opencode) directory=$HOME/.opencode/bin ;;
    *) directory=$HOME/.local/bin ;;
esac
mkdir -p "$directory"
printf '#!/bin/sh\ntest "$*" = --version\n' > "$directory/@TOOL@"
chmod +x "$directory/@TOOL@"
EOF
chmod +x "$DOTFILES_TOOLS_BIN/curl"
export TRACK=unstable
tools=("${chezmoi[@]}" apply --source-path "$tools_hook")
PATH="$DOTFILES_TOOLS_BIN" "${chezmoi[@]}" apply "${config_only[@]}"
test ! -e "$DOTFILES_TOOLS_LOG"
for failure in 'download tailscale' 'install tailscale' 'install opencode'; do
    if PATH="$DOTFILES_TOOLS_BIN" DOTFILES_TOOLS_FAILURE="$failure" "${tools[@]}" > "$temporary/tools.log" 2>&1; then
        echo "A failed $failure must fail apply." >&2
        exit 1
    fi
done
test ! -e "$destination/.local/bin/opencode"
PATH="$DOTFILES_TOOLS_BIN" "${tools[@]}"
PATH="$DOTFILES_TOOLS_BIN" "${tools[@]}"
test "$(readlink "$destination/.local/bin/opencode")" = "$destination/.opencode/bin/opencode"
cat > "$temporary/expected-runs" <<'EOF'
download tailscale
download tailscale
install tailscale
download tailscale
install tailscale
download claude
install claude stable
download codex
install codex
download opencode
install opencode --no-modify-path
download opencode
install opencode --no-modify-path
EOF
cmp "$temporary/expected-runs" "$DOTFILES_TOOLS_LOG"
"${chezmoi[@]}" verify --exclude scripts
test "$("${git_config[@]}" --get user.name)" = 'Local User'
cmp "$temporary/expected-git" "$destination/.gitconfig"
cmp "$temporary/expected-local" "$destination/.gitconfig.local"
grep -qx '# Unmanaged profile' "$destination/Documents/PowerShell/profile.ps1"
cmp "$temporary/expected-bashrc" "$destination/.bashrc"
grep -qx '# Personal shell settings' "$destination/.bashrc"
grep -qx 'PROMPT_COMMAND=custom' "$destination/.bashrc"
cmp "$temporary/expected-codex/config.toml" "$destination/.codex/config.toml"
cmp "$temporary/expected-codex/auth.json" "$destination/.codex/auth.json"
cmp "$temporary/expected-claude/settings.json" "$destination/.claude/settings.json"
cmp "$temporary/expected-opencode/opencode.json" "$destination/.config/opencode/opencode.json"
grep -qx '# Unmanaged skill' "$destination/.agents/skills/personal/SKILL.md"
echo 'Ubuntu: identity, configuration, externals, retries, conflicts and preservation passed.'

# shellcheck source=tests/cases/ubuntu-host.sh
source "$repository/tests/cases/ubuntu-host.sh"
