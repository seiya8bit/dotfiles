#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Ubuntu verification failed at line $LINENO" >&2' ERR
[[ $(uname -s) == Linux && $EUID != 0 ]] || { echo 'Run as a normal Ubuntu user.' >&2; exit 1; }
repository=$(cd "$(dirname "$0")/.." && pwd)
chezmoi_bin=$(command -v chezmoi)
shellcheck "$repository/tests/"*.sh
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
tailscale_hook="$checkout/home/.chezmoiscripts/run_onchange_after_install-tailscale.sh.tmpl"
"${chezmoi[@]}" execute-template --file "$tailscale_hook" | shellcheck -
host_hook="$checkout/home/.chezmoiscripts/run_after_install-ubuntu-host.sh.tmpl"
"${chezmoi[@]}" execute-template --file "$host_hook" | shellcheck -
for source in "$external" "$tailscale_hook" "$host_hook"; do
    test -z "$("${chezmoi[@]}" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file "$source")"
    test -z "$("${chezmoi[@]}" --override-data '{"chezmoi":{"osRelease":{"id":"debian"}}}' execute-template --file "$source")"
done
for platform in 'amd64 x86_64' 'arm64 aarch64'; do
    read -r arch machine <<< "$platform"
    "${chezmoi[@]}" --override-data "{\"chezmoi\":{\"arch\":\"$arch\"}}" execute-template --file "$external" > "$temporary/$arch.toml"
    for tool in zellij codex; do
        sed -n "\|^\[\".local/bin/$tool\"\]|,/^$/p" "$temporary/$arch.toml" > "$temporary/entry.toml"
        grep -Fxq 'type = "archive-file"' "$temporary/entry.toml"
        grep -Fxq 'executable = true' "$temporary/entry.toml"
        grep -q '^checksum.sha256 = "[a-f0-9]\{64\}"$' "$temporary/entry.toml"
    done
    grep -Fxq "url = \"https://github.com/zellij-org/zellij/releases/download/v0.45.1/zellij-$machine-unknown-linux-musl.tar.gz\"" "$temporary/$arch.toml"
    grep -Fxq "url = \"https://github.com/openai/codex/releases/download/rust-v0.154.0/codex-$machine-unknown-linux-musl.tar.gz\"" "$temporary/$arch.toml"
    grep -Fxq "path = \"codex-$machine-unknown-linux-musl\"" "$temporary/$arch.toml"
done
if "${chezmoi[@]}" --override-data '{"chezmoi":{"arch":"riscv64"}}' execute-template --file "$external" > "$temporary/arch.log" 2>&1; then
    echo 'An unsupported architecture must fail.' >&2; exit 1
fi
grep -q 'Zellij and Codex require Ubuntu amd64 or arm64' "$temporary/arch.log"

binaries=("$destination/.local/bin/zellij" "$destination/.local/bin/codex")
cp "$external" "$temporary/external.toml"
for tool in zellij codex; do
    # Change only this tool's URL so a sibling cannot mask a broken checksum check.
    sed -i "\|^\[\".local/bin/$tool\"\]|,/^$/s|^url = .*|url = \"https://127.0.0.1:1/$tool.tar.gz\"|" "$external"
    if "${chezmoi[@]}" apply --exclude scripts > "$temporary/download.log" 2>&1; then
        echo "A failed $tool download must fail apply." >&2; exit 1
    fi
    grep -Fq "127.0.0.1:1/$tool.tar.gz" "$temporary/download.log"
    for binary in "${binaries[@]}"; do test ! -e "$binary"; done
    cp "$temporary/external.toml" "$external"
    printf '#!/bin/sh\necho untrusted\n' > "$temporary/$tool"
    tar -czf "$temporary/$tool.tar.gz" -C "$temporary" "$tool"
    sed -i "\|^\[\".local/bin/$tool\"\]|,/^$/s|^url = .*|url = \"file://$temporary/$tool.tar.gz\"|" "$external"
    if "${chezmoi[@]}" apply --exclude scripts > "$temporary/checksum.log" 2>&1; then
        echo "A mismatched $tool checksum must fail apply." >&2; exit 1
    fi
    grep -q 'SHA256 mismatch' "$temporary/checksum.log" || { cat "$temporary/checksum.log" >&2; exit 1; }
    for binary in "${binaries[@]}"; do test ! -e "$binary"; done
    cp "$temporary/external.toml" "$external"
done

# Mock only the disposable host hook; no real sudo or Docker socket enters this container.
if command -v sudo >/dev/null; then echo 'Real sudo must not be available.' >&2; exit 1; fi
[[ ! -e /var/run/docker.sock ]]
export DOTFILES_HOST_STATE="$temporary/host"
mkdir -p "$DOTFILES_HOST_STATE/etc" "$DOTFILES_HOST_STATE/run"
printf 'ID=ubuntu\nVERSION_ID=26.04\n' > "$DOTFILES_HOST_STATE/etc/os-release"
cat > "$DOTFILES_HOST_STATE/mock.sh" <<'MOCK'
s=$DOTFILES_HOST_STATE
printf 'run\n' >> "$s/calls"
dpkg-query() { if (( $# == 3 )); then grep -Fxq "$3" "$s/packages" && printf installed; else sed 's/$/ installed/' "$s/packages"; fi; }
dpkg() { if [[ $1 == --print-architecture ]]; then echo "${HOST_ARCH:-amd64}"; else command dpkg "$@"; fi; }
uname() { echo "${HOST_KERNEL:-6.17.0-1-generic}"; }
id() { if [[ $1 == -un ]]; then echo vscode; elif [[ $# == 2 && -e $s/group ]]; then echo 'vscode docker'; else echo vscode; fi; }
lspci() { [[ $* == '-Dnm -d 10de::03xx' ]]; echo "${HOST_GPU-}"; }
ubuntu-drivers() { [[ $* == 'list --gpgpu --recommended' ]]; echo "${HOST_DRIVER-nvidia-driver-580-server linux-modules-nvidia-580-server-generic}"; }
if grep -q '^nvidia-driver-' "$s/packages"; then nvidia-smi() { [[ ! -e $s/run/reboot-required.pkgs && ${HOST_FAIL-} != driver ]]; }; fi
nvidia-ctk() { [[ $* == --version || $* == 'cdi list' ]]; [[ ${HOST_FAIL-} != cdi ]]; echo nvidia.com/gpu=all; }
curl() { [[ $* == '--fail --location --silent --show-error https://'*' --output '* ]]; printf '%s\n' "${HOST_FAIL:-fixture-key}" > "${*: -1}"; }
docker_mock() {
    case "$*" in
        --version|'buildx version') : ;;
        'compose version --short') echo "${HOST_COMPOSE:-2.30.0}" ;;
        *'info --format {{.ServerVersion}}') echo "${HOST_VERSION:-29.2.0}" ;;
        *'info --format {{range .DiscoveredDevices}}{{println .ID}}{{end}}') echo nvidia.com/gpu=all ;;
        *) return 99 ;;
    esac
}
if grep -q '^docker-ce$' "$s/packages"; then docker() { docker_mock "$@"; }; fi
systemctl() {
    local unit=${*: -1}
    case "$1" in
        show) if [[ $2 == --property=Version ]]; then echo 259; else echo '2100-01-01 00:00:00 UTC'; fi ;;
        is-enabled) if [[ $unit == "${HOST_DISABLED-ssh.service}" ]]; then echo disabled; return 1; else echo enabled; fi ;;
        is-active) grep -Fxq "$unit" "$s/active" ;;
        start) echo "$unit" >> "$s/active" ;;
        *) return 99 ;;
    esac
}
sudo() {
    printf '%s\n' "$*" >> "$s/sudo"
    case "$1" in
        docker|systemctl) "$@" ;;
        /usr/sbin/sshd) [[ $* == '/usr/sbin/sshd -G' ]] ;;
        usermod) [[ $* == 'usermod -aG docker vscode' ]]; touch "$s/group" ;;
        mkdir|cp) [[ ${*: -1} == "$s/etc/"* ]]; command "$@" ;;
        apt-get) [[ $* == 'apt-get -o APT::Update::Error-Mode=any update' && ${HOST_FAIL-} != apt ]] ;;
        env)
            [[ $* == 'env DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1 apt-get -y --no-remove --no-upgrade --no-install-recommends -o Dpkg::Options::=--force-confold install -- '* ]]
            shift 12
            printf '%s\n' "$@" >> "$s/packages"
            if [[ $* == *docker-ce* ]]; then docker() { docker_mock "$@"; }; fi
            if [[ $* == *nvidia-driver-* ]]; then echo nvidia-driver > "$s/run/reboot-required.pkgs"; fi ;;
        *) return 99 ;;
    esac
}
MOCK
shellcheck --shell=bash --exclude=SC2329 "$DOTFILES_HOST_STATE/mock.sh"
fixture_sha=$(printf 'fixture-key\n' | sha256sum | cut -d ' ' -f 1)
sed -i "/^set -Eeuo pipefail$/a source \"$DOTFILES_HOST_STATE/mock.sh\"" "$host_hook"
sed -i "s|^etc=/etc$|etc=\"$DOTFILES_HOST_STATE/etc\"|; s|^run=/run$|run=\"$DOTFILES_HOST_STATE/run\"|; s|/usr/bin/nvidia-cdi-hook|$DOTFILES_HOST_STATE/mock.sh|; s|[a-f0-9]\{64\}|$fixture_sha|g" "$host_hook"
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
test "$(stat -c %a "$destination/.gitconfig")" = 644
test "$(stat -c %a "$destination/.bash_aliases")" = 644
for binary in "${binaries[@]}"; do test ! -e "$binary"; done
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
printf '# Unmanaged shell settings\n' > "$destination/.bashrc"
mkdir -p "$destination/.codex" "$destination/.agents/skills/personal"
printf '# Unmanaged Codex settings\n' > "$destination/.codex/config.toml"
printf '{"test":"unmanaged credential fixture"}\n' > "$destination/.codex/auth.json"
printf '# Unmanaged skill\n' > "$destination/.agents/skills/personal/SKILL.md"
cp -R "$destination/.codex" "$temporary/expected-codex"

# Reject every managed file and ancestor collision before writing any configuration.
mkdir "$temporary/link-target"
for relative in .bash_aliases .gitconfig .local .local/bin .local/bin/zellij .local/bin/codex; do
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
            echo "Accepted $kind at $relative." >&2; exit 1
        fi
        grep -q 'must be a regular' "$temporary/conflict.log"
        if [[ $relative == .local && $kind == link ]]; then
            if "${chezmoi[@]}" --destination "$temporary/conflict-home" apply --force "${config_only[@]}" > "$temporary/conflict.log" 2>&1; then
                echo 'Configuration-only apply accepted a managed path collision.' >&2; exit 1
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
for binary in "${binaries[@]}"; do test ! -e "$binary"; done
"${chezmoi[@]}" apply
for path in "$destination/.local/bin" "${binaries[@]}"; do test "$(stat -c %a "$path")" = 755; done
test "$("${binaries[0]}" --version)" = 'zellij 0.45.1'
test "$(HOME="$destination" PATH="$destination/.local/bin:$PATH" bash --noprofile --rcfile /etc/skel/.bashrc \
    -ic 'zj --version' 2>"$temporary/bash.log")" = 'zellij 0.45.1'
test "$(HOME="$destination" CODEX_HOME="$destination/.codex" "${binaries[1]}" --version)" = 'codex-cli 0.154.0'
HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply
printf '#!/bin/sh\necho modified\n' > "$temporary/modified-binary"
for binary in "${binaries[@]}"; do cp "$temporary/modified-binary" "$binary"; done
HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply "${config_only[@]}"
for binary in "${binaries[@]}"; do cmp "$temporary/modified-binary" "$binary"; done
HTTPS_PROXY=http://127.0.0.1:1 "${chezmoi[@]}" apply --exclude scripts --force
test "$("${binaries[0]}" --version)" = 'zellij 0.45.1'
test "$(HOME="$destination" CODEX_HOME="$destination/.codex" "${binaries[1]}" --version)" = 'codex-cli 0.154.0'

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
        echo 'A failed Tailscale installation must fail apply.' >&2; exit 1
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
grep -qx '# Unmanaged shell settings' "$destination/.bashrc"
cmp "$temporary/expected-codex/config.toml" "$destination/.codex/config.toml"
cmp "$temporary/expected-codex/auth.json" "$destination/.codex/auth.json"
grep -qx '# Unmanaged skill' "$destination/.agents/skills/personal/SKILL.md"
echo 'Ubuntu: identity, configuration, externals, retries, conflicts and preservation passed.'

# Reuse the command mocks for direct hook checks after testing normal apply and preview.
"${chezmoi[@]}" execute-template --file "$host_hook" > "$temporary/host.sh"
s=$DOTFILES_HOST_STATE
cp "$s/packages" "$s/baseline"
: > "$s/sudo"
for gpu in '' 'NVIDIA display-class PCI device'; do
    export HOST_GPU=$gpu
    : > "$s/packages"
    rm -f "$s/group"
    bash "$temporary/host.sh"
    grep -Fxq docker-ce "$s/packages"
    test "$(grep -c '^usermod ' "$s/sudo")" = 1
    cp "$s/sudo" "$s/expected-sudo"
    bash "$temporary/host.sh"
    # A repeated apply performs only the read-only SSH check while awaiting reboot.
    tail -n +$(( $(wc -l < "$s/expected-sudo") + 1 )) "$s/sudo" > "$s/repeated"
    test "$(cat "$s/repeated")" = '/usr/sbin/sshd -G'
    : > "$s/sudo"
done
rm "$s/run/reboot-required.pkgs"
mkdir -p "$s/etc/docker" "$s/etc/ssh"
printf '{"default-runtime":"runc","debug":true}\n' > "$s/etc/docker/daemon.json"
printf '# Existing SSH configuration\n' > "$s/etc/ssh/sshd_config"
cp -a "$s/etc" "$s/expected-etc"
bash "$temporary/host.sh"
diff -r "$s/expected-etc" "$s/etc"
for failure in 'HOST_FAIL=driver' 'HOST_FAIL=cdi' 'HOST_COMPOSE=2.29.0' 'HOST_VERSION=29.1.3' 'HOST_ARCH=riscv64' 'HOST_KERNEL=6.6-microsoft'; do
    if env "$failure" bash "$temporary/host.sh" > "$s/failure.log" 2>&1; then echo "Accepted $failure" >&2; exit 1; fi
done
for failure in 'HOST_FAIL=apt' 'HOST_FAIL=checksum' 'HOST_DRIVER='; do
    cp "$s/baseline" "$s/packages"
    rm -f "$s/run/reboot-required.pkgs"
    if env "$failure" bash "$temporary/host.sh" > "$s/failure.log" 2>&1; then echo "Accepted $failure" >&2; exit 1; fi
done
cp "$s/baseline" "$s/packages"
printf 'nvidia-container-toolkit-base\n' >> "$s/packages"
rm -f "$s/run/reboot-required.pkgs"
bash "$temporary/host.sh"
grep -Fxq nvidia-driver-580-server "$s/packages"
diff -r "$s/expected-etc" "$s/etc"
echo 'Ubuntu host: provisioning, retries, CDI, preservation, unsupported platforms and failures passed.'
