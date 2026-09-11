#!/usr/bin/env bash
s=$DOTFILES_HOST_STATE
printf 'run\n' >> "$s/calls"

dpkg-query() {
    if (( $# == 3 )); then
        grep -Fxq "$3" "$s/packages" && printf installed
    else
        sed 's/$/ installed/' "$s/packages"
    fi
}

dpkg() {
    if [[ $1 == --print-architecture ]]; then
        echo "${HOST_ARCH:-amd64}"
    else
        command dpkg "$@"
    fi
}

uname() {
    echo "${HOST_KERNEL:-6.17.0-1-generic}"
}

id() {
    if [[ $1 == -un ]]; then
        echo vscode
    elif [[ $# == 2 && -e $s/group ]]; then
        echo 'vscode docker'
    else
        echo vscode
    fi
}

lspci() {
    [[ $* == '-Dnm -d 10de::03xx' ]]
    echo "${HOST_GPU-}"
}

ubuntu-drivers() {
    [[ $* == 'list --gpgpu --recommended' ]]
    echo "${HOST_DRIVER-nvidia-driver-580-server linux-modules-nvidia-580-server-generic}"
}

if grep -q '^nvidia-driver-' "$s/packages"; then
    nvidia-smi() {
        [[ ! -e $s/run/reboot-required.pkgs && ${HOST_FAIL-} != driver ]]
    }
fi

nvidia-ctk() {
    [[ $* == --version || $* == 'cdi list' ]]
    [[ ${HOST_FAIL-} != cdi ]]
    echo nvidia.com/gpu=all
}

curl() {
    [[ $* == '--fail --location --silent --show-error https://'*' --output '* ]]
    printf '%s\n' "${HOST_FAIL:-fixture-key}" > "${*: -1}"
}

docker_mock() {
    case "$*" in
        --version|'buildx version')
            :
            ;;
        'compose version --short')
            echo "${HOST_COMPOSE:-2.30.0}"
            ;;
        *'info --format {{.ServerVersion}}')
            echo "${HOST_VERSION:-29.2.0}"
            ;;
        *'info --format {{range .DiscoveredDevices}}{{println .ID}}{{end}}')
            echo nvidia.com/gpu=all
            ;;
        *)
            return 99
            ;;
    esac
}

if grep -q '^docker-ce$' "$s/packages"; then
    docker() {
        docker_mock "$@"
    }
fi

systemctl() {
    local unit=${*: -1}

    case "$1" in
        show)
            if [[ $2 == --property=Version ]]; then
                echo 259
            else
                echo '2100-01-01 00:00:00 UTC'
            fi
            ;;
        is-enabled)
            if [[ $unit == "${HOST_DISABLED-ssh.service}" ]]; then
                echo disabled
                return 1
            else
                echo enabled
            fi
            ;;
        is-active)
            grep -Fxq "$unit" "$s/active"
            ;;
        start)
            echo "$unit" >> "$s/active"
            ;;
        *)
            return 99
            ;;
    esac
}

sudo() {
    printf '%s\n' "$*" >> "$s/sudo"

    case "$1" in
        docker|systemctl)
            "$@"
            ;;
        /usr/sbin/sshd)
            [[ $* == '/usr/sbin/sshd -G' ]]
            ;;
        usermod)
            [[ $* == 'usermod -aG docker vscode' ]]
            touch "$s/group"
            ;;
        mkdir|cp)
            [[ ${*: -1} == "$s/etc/"* ]]
            command "$@"
            ;;
        apt-get)
            [[ $* == 'apt-get -o APT::Update::Error-Mode=any update' && ${HOST_FAIL-} != apt ]]
            ;;
        env)
            [[ $* == 'env DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1 apt-get -y --no-remove --no-upgrade --no-install-recommends -o Dpkg::Options::=--force-confold install -- '* ]]
            shift 12
            printf '%s\n' "$@" >> "$s/packages"

            if [[ $* == *docker-ce* ]]; then
                docker() {
                    docker_mock "$@"
                }
            fi
            if [[ $* == *nvidia-driver-* ]]; then
                echo nvidia-driver > "$s/run/reboot-required.pkgs"
            fi
            ;;
        *)
            return 99
            ;;
    esac
}
