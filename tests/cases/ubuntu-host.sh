#!/usr/bin/env bash
# Sourced by verify-ubuntu.sh with its disposable chezmoi fixture.

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

for failure in 'HOST_FAIL=driver' 'HOST_FAIL=cdi' 'HOST_COMPOSE=2.29.0' \
    'HOST_VERSION=29.1.3' 'HOST_ARCH=riscv64' 'HOST_KERNEL=6.6-microsoft'; do
    if env "$failure" bash "$temporary/host.sh" > "$s/failure.log" 2>&1; then
        echo "Accepted $failure" >&2
        exit 1
    fi
done

for failure in 'HOST_FAIL=apt' 'HOST_FAIL=checksum' 'HOST_DRIVER='; do
    cp "$s/baseline" "$s/packages"
    rm -f "$s/run/reboot-required.pkgs"

    if env "$failure" bash "$temporary/host.sh" > "$s/failure.log" 2>&1; then
        echo "Accepted $failure" >&2
        exit 1
    fi
done

cp "$s/baseline" "$s/packages"
printf 'nvidia-container-toolkit-base\n' >> "$s/packages"
rm -f "$s/run/reboot-required.pkgs"

bash "$temporary/host.sh"
grep -Fxq nvidia-driver-580-server "$s/packages"
diff -r "$s/expected-etc" "$s/etc"

echo 'Ubuntu host: provisioning, retries, CDI, preservation, unsupported platforms and failures passed.'
