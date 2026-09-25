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
chmod 755 "$destination/.local" "$destination/.local/bin"
cp "$repository/.chezmoiroot" "$repository/.chezmoiversion" "$checkout/"
cp -R "$repository/home" "$checkout/home"
"${chezmoi[@]}" init --source "$checkout" --promptString 'Git name=Test User,Git email=test@example.invalid'
"${chezmoi[@]}" init

external="$checkout/home/.chezmoiexternal.toml"
tailscale_hook="$checkout/home/.chezmoiscripts/ubuntu/run_onchange_after_install-tailscale.sh.tmpl"
"${chezmoi[@]}" execute-template --file "$tailscale_hook" | shellcheck -
host_hook="$checkout/home/.chezmoiscripts/ubuntu/run_after_setup-host.sh.tmpl"
"${chezmoi[@]}" execute-template --file "$host_hook" | shellcheck -

for source in "$external" "$tailscale_hook" "$host_hook"; do
    test -z "$("${chezmoi[@]}" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file "$source")"
    test -z "$("${chezmoi[@]}" --override-data '{"chezmoi":{"osRelease":{"id":"debian"}}}' execute-template --file "$source")"
done

if "${chezmoi[@]}" --override-data '{"chezmoi":{"arch":"riscv64"}}' execute-template --file "$external" > "$temporary/arch.log" 2>&1; then
    echo 'An unsupported architecture must fail.' >&2
    exit 1
fi
grep -q 'Zellij, Codex, Claude Code and OpenCode require Ubuntu amd64 or arm64' "$temporary/arch.log"
"${chezmoi[@]}" --override-data '{"chezmoi":{"arch":"arm64"}}' execute-template --file "$external" > "$temporary/arm64-external.toml"
grep -Fq '/linux-arm64/claude"' "$temporary/arm64-external.toml"
grep -Fq 'opencode-linux-arm64.tar.gz' "$temporary/arm64-external.toml"

binaries=("$destination/.local/bin/zellij" "$destination/.local/bin/codex" "$destination/.local/bin/claude" "$destination/.local/bin/opencode")
failed_destination="$temporary/failed-external-home"
mkdir -p "$failed_destination"
cp "$external" "$temporary/external.toml"
for tool in zellij codex claude opencode; do
    # Change only this tool's URL so a sibling cannot mask a broken checksum check.
    sed -i "\|^\[\".local/bin/$tool\"\]|,/^$/s|^url = .*|url = \"https://127.0.0.1:1/$tool\"|" "$external"
    if "${chezmoi[@]}" --destination "$failed_destination" apply --exclude scripts > "$temporary/download.log" 2>&1; then
        echo "A failed $tool download must fail apply." >&2
        exit 1
    fi
    grep -Fq "127.0.0.1:1/$tool" "$temporary/download.log" || {
        cat "$temporary/download.log" >&2
        exit 1
    }
    test ! -e "$failed_destination/.local/bin/$tool"

    cp "$temporary/external.toml" "$external"
    printf '#!/bin/sh\necho untrusted\n' > "$temporary/$tool"
    if [[ $tool == claude ]]; then
        replacement="$temporary/$tool"
    else
        tar -czf "$temporary/$tool.tar.gz" -C "$temporary" "$tool"
        replacement="$temporary/$tool.tar.gz"
    fi
    sed -i "\|^\[\".local/bin/$tool\"\]|,/^$/s|^url = .*|url = \"file://$replacement\"|" "$external"
    if "${chezmoi[@]}" --destination "$failed_destination" apply --exclude scripts > "$temporary/checksum.log" 2>&1; then
        echo "A mismatched $tool checksum must fail apply." >&2
        exit 1
    fi
    grep -q 'SHA256 mismatch' "$temporary/checksum.log" || {
        cat "$temporary/checksum.log" >&2
        exit 1
    }
    test ! -e "$failed_destination/.local/bin/$tool"
    cp "$temporary/external.toml" "$external"
    rm -rf "$failed_destination"
    mkdir -p "$failed_destination"
done

# Mock only the disposable host hook; no real sudo or Docker socket enters this container.
export DOTFILES_HOST_STATE="$temporary/host"
mkdir -p "$DOTFILES_HOST_STATE/etc" "$DOTFILES_HOST_STATE/run"
printf 'ID=ubuntu\nVERSION_ID=26.04\n' > "$DOTFILES_HOST_STATE/etc/os-release"
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

# Tailscale exists but must never be invoked; configuration-only apply may download externals.
printf '#!/bin/sh\nexit 1\n' > "$temporary/bin/tailscale"
chmod +x "$temporary/bin/tailscale"
export PATH="$temporary/bin:$PATH"

"${chezmoi[@]}" diff "${config_only[@]}" > /dev/null
"${chezmoi[@]}" apply --dry-run "${config_only[@]}"
test ! -e "$destination/.gitconfig"
"${chezmoi[@]}" apply "${config_only[@]}"
test ! -e "$DOTFILES_HOST_STATE/calls"

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
for binary in "${binaries[@]}"; do
    test ! -e "$binary"
done
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
for relative in .bash_aliases .bashrc .gitconfig .local .local/bin .local/bin/zellij .local/bin/codex .local/bin/claude .local/bin/opencode; do
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
for binary in "${binaries[@]}"; do
    test ! -e "$binary"
done

"${chezmoi[@]}" apply
for path in "$destination/.local/bin" "${binaries[@]}"; do
    test "$(stat -c %a "$path")" = 755
done
sha256sum "${binaries[@]}" > "$temporary/expected-binaries"
zellij_version=$("${binaries[0]}" --version)
[[ $zellij_version == zellij\ * ]]
test "$(HOME="$destination" PATH="$destination/.local/bin:$PATH" bash --noprofile --rcfile "$destination/.bashrc" \
    -ic 'zj --version' 2>"$temporary/bash.log")" = "$zellij_version"
HOME="$destination" CODEX_HOME="$destination/.codex" "${binaries[1]}" --version | grep -E '^codex-cli [0-9]'
HOME="$destination" "${binaries[2]}" --version | grep -E '[0-9]+\.[0-9]+\.[0-9]+'
HOME="$destination" "${binaries[3]}" --version | grep -E '[0-9]+\.[0-9]+\.[0-9]+'
HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply

printf '#!/bin/sh\necho modified\n' > "$temporary/modified-binary"
for binary in "${binaries[@]}"; do
    cp "$temporary/modified-binary" "$binary"
done

HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply "${config_only[@]}"
for binary in "${binaries[@]}"; do
    cmp "$temporary/modified-binary" "$binary"
done

HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply --exclude scripts --force
sha256sum --check --status "$temporary/expected-binaries"

# Isolate PATH for the missing-Tailscale case, including hosts that already have it.
export DOTFILES_TAILSCALE_BIN="$temporary/tailscale-bin"
export DOTFILES_TAILSCALE_LOG="$temporary/tailscale-runs"
mkdir "$DOTFILES_TAILSCALE_BIN"
for command in bash sh cat chmod; do
    ln -s "$(command -v "$command")" "$DOTFILES_TAILSCALE_BIN/$command"
done
cat > "$DOTFILES_TAILSCALE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $* == '--fail --location --silent --show-error https://tailscale.com/install.sh' ]]
echo download >> "$DOTFILES_TAILSCALE_LOG"
cat "$DOTFILES_TAILSCALE_BIN/installer.sh"
[[ ${DOTFILES_TAILSCALE_FAILURE-} != download ]]
EOF
chmod +x "$DOTFILES_TAILSCALE_BIN/curl"
cat > "$DOTFILES_TAILSCALE_BIN/installer.sh" <<'EOF'
#!/bin/sh
set -eu
echo install >> "$DOTFILES_TAILSCALE_LOG"
test "$TRACK" = stable
test -f "$CHEZMOI_DEST_DIR/.gitconfig"
test "${DOTFILES_TAILSCALE_FAILURE-}" != install
printf '#!/bin/sh\ntest "$*" = version\n' > "$DOTFILES_TAILSCALE_BIN/tailscale"
chmod +x "$DOTFILES_TAILSCALE_BIN/tailscale"
EOF
export TRACK=unstable
printf '\n# Exercise a changed hook.\n' >> "$tailscale_hook"
PATH="$DOTFILES_TAILSCALE_BIN" "${chezmoi[@]}" apply "${config_only[@]}"
test ! -e "$DOTFILES_TAILSCALE_LOG"
for failure in download install; do
    if PATH="$DOTFILES_TAILSCALE_BIN" DOTFILES_TAILSCALE_FAILURE="$failure" \
        "${chezmoi[@]}" apply --source-path "$tailscale_hook" --force > "$temporary/tailscale.log" 2>&1; then
        echo 'A failed Tailscale installation must fail apply.' >&2
        exit 1
    fi
    test ! -e "$DOTFILES_TAILSCALE_BIN/tailscale"
done
PATH="$DOTFILES_TAILSCALE_BIN" "${chezmoi[@]}" apply --source-path "$tailscale_hook" --force
PATH="$DOTFILES_TAILSCALE_BIN" "${chezmoi[@]}" apply --source-path "$tailscale_hook"
printf '\n# Exercise an already installed Tailscale.\n' >> "$tailscale_hook"
PATH="$DOTFILES_TAILSCALE_BIN" "${chezmoi[@]}" apply --source-path "$tailscale_hook" --force
printf 'download\ndownload\ninstall\ndownload\ninstall\n' > "$temporary/expected-runs"
cmp "$temporary/expected-runs" "$DOTFILES_TAILSCALE_LOG"
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
