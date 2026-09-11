#!/usr/bin/env bash
# Sourced by verify-ubuntu.sh with its disposable chezmoi fixture.

"${chezmoi[@]}" execute-template --file "$host_hook" > "$temporary/host.sh"
s=$DOTFILES_HOST_STATE
cp "$s/packages" "$s/baseline"

expect_host_failure() {
    local message=$1
    shift
    if env "$@" bash "$temporary/host.sh" > "$s/failure.log" 2>&1; then
        echo "Expected failure: $*" >&2
        exit 1
    fi
    grep -Fq "$message" "$s/failure.log"
}

# Conflicts must stop setup before any privileged action.
printf 'containerd\n' > "$s/packages"
: > "$s/sudo"
expect_host_failure 'Conflicting or incomplete container packages exist'
test ! -s "$s/sudo"

for gpu in '' 'NVIDIA display-class PCI device'; do
    export HOST_GPU=$gpu
    : > "$s/packages"
    : > "$s/active"
    : > "$s/sudo"
    rm -f "$s/group"

    bash "$temporary/host.sh"
    grep -Fxq zoxide "$s/packages"
    grep -Fxq docker-ce "$s/packages"
    test "$(grep -c '^usermod ' "$s/sudo")" = 1
    grep -Fxq docker.service "$s/active"
    grep -Fxq ssh.socket "$s/active"
    if [[ -n $gpu ]]; then
        grep -Fxq nvidia-cdi-refresh.path "$s/active"
    else
        ! grep -q '^nvidia-' "$s/packages"
    fi

    : > "$s/sudo"
    bash "$temporary/host.sh"

    # A repeated apply performs only the read-only SSH check while awaiting reboot.
    test "$(cat "$s/sudo")" = '/usr/sbin/sshd -G'
done

rm "$s/run/reboot-required.pkgs"
mkdir -p "$s/etc/docker" "$s/etc/ssh"
printf '{"default-runtime":"runc","debug":true}\n' > "$s/etc/docker/daemon.json"
printf '# Existing SSH configuration\n' > "$s/etc/ssh/sshd_config"
cp -a "$s/etc" "$s/expected-etc"

bash "$temporary/host.sh"
diff -r "$s/expected-etc" "$s/etc"

printf 'NVRM version: 580.0\n' > "$s/nvidia-version"
expect_host_failure 'Existing NVIDIA driver could not be verified' HOST_FAIL=driver
expect_host_failure 'CDI device missing' HOST_CDI=
expect_host_failure 'Compose 2.30+' HOST_COMPOSE=2.29.0
expect_host_failure 'requires Docker 29.2+' HOST_VERSION=29.1.3
expect_host_failure 'Ubuntu Server 26.04 LTS amd64 or arm64' HOST_ARCH=riscv64
expect_host_failure 'WSL and Jetson/L4T' HOST_KERNEL=6.6-microsoft

# A headless installation can have a loaded driver without nvidia-smi.
cp "$s/packages" "$s/full-driver-packages"
sed -i 's/^nvidia-driver-/nvidia-headless-no-dkms-/' "$s/packages"
cp "$s/packages" "$s/headless-packages"
bash "$temporary/host.sh"
bash "$temporary/host.sh"
cmp "$s/headless-packages" "$s/packages"
diff -r "$s/expected-etc" "$s/etc"
expect_host_failure 'NVIDIA CDI generation failed' HOST_FAIL=cdi-generate
expect_host_failure 'CDI device missing' HOST_CDI=

rm "$s/nvidia-version"
expect_host_failure 'Existing NVIDIA driver could not be verified'
printf 'nvidia-headless-no-dkms\n' > "$s/run/reboot-required.pkgs"
bash "$temporary/host.sh" > "$s/reboot.log"
grep -Fq 'Manual action: reboot' "$s/reboot.log"
cmp "$s/headless-packages" "$s/packages"
rm "$s/run/reboot-required.pkgs"
cp "$s/full-driver-packages" "$s/packages"

for state in disabled masked; do
    sed -i '/^docker.service$/d' "$s/active"
    : > "$s/sudo"
    HOST_GPU= HOST_DISABLED=docker.service HOST_SERVICE_STATE=$state bash "$temporary/host.sh"
    test "$(cat "$s/sudo")" = '/usr/sbin/sshd -G'
done
printf 'docker.service\n' >> "$s/active"

HOST_STARTED='1970-01-01 00:00:00 UTC' bash "$temporary/host.sh" > "$s/restart.log"
grep -Fq 'Manual action: restart Docker' "$s/restart.log"

for failure in apt-update apt-install; do
    cp "$s/baseline" "$s/packages"
    expect_host_failure "Mock APT ${failure#apt-} failure." "HOST_FAIL=$failure"
    cmp "$s/baseline" "$s/packages"
done
expect_host_failure 'No unambiguous recommended driver' HOST_DRIVER=
expect_host_failure 'Ubuntu host setup failed' HOST_KEY=corrupted

cp "$s/baseline" "$s/packages"
printf 'nvidia-container-toolkit-base\n' >> "$s/packages"
rm -f "$s/run/reboot-required.pkgs"

bash "$temporary/host.sh"
grep -Fxq nvidia-driver-580-server "$s/packages"
diff -r "$s/expected-etc" "$s/etc"

echo 'Ubuntu host: provisioning, retries, CDI, preservation, unsupported platforms and failures passed.'
