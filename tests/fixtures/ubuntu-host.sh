#!/usr/bin/env bash
s=$DOTFILES_HOST_STATE
touch "$s/calls"

dpkg-query() {
    if (( $# == 3 )); then
        grep -Fxq "$3" "$s/packages" && printf installed
    else
        sed 's/$/ installed/' "$s/packages"
    fi
}

dpkg() {
    if [[ $1 == --print-architecture && -n ${HOST_ARCH-} ]]; then
        echo "$HOST_ARCH"
    else
        command dpkg "$@"
    fi
}

uname() {
    echo "${HOST_KERNEL:-6.17.0-1-generic}"
}

id() {
    if [[ $# == 2 && -e $s/group ]]; then
        echo 'vscode docker'
    else
        echo vscode
    fi
}

lspci() {
    echo "${HOST_GPU-}"
}

ubuntu-drivers() {
    echo "${HOST_DRIVER-nvidia-driver-580-server linux-modules-nvidia-580-server-generic}"
}

if grep -q '^nvidia-driver-' "$s/packages"; then
    nvidia-smi() {
        [[ ! -e $s/run/reboot-required.pkgs && ${HOST_FAIL-} != driver ]]
    }
fi

nvidia-ctk() {
    case "$*" in
        'cdi generate --mode=nvml --output=')
            [[ ${HOST_FAIL-} != cdi-generate ]]
            ;;
        'cdi list')
            echo "${HOST_CDI-nvidia.com/gpu=all}"
            ;;
        *)
            return 99
            ;;
    esac
}

curl() {
    printf '%s\n' "${HOST_KEY-fixture-key}" > "${*: -1}"
}

docker_mock() {
    case "$*" in
        --version|'buildx version')
            :
            ;;
        'compose version --short')
            echo "${HOST_COMPOSE:-2.30.0}"
            ;;
        '--host unix:///run/docker.sock info --format {{.ServerVersion}}')
            echo "${HOST_VERSION:-29.2.0}"
            ;;
        '--host unix:///run/docker.sock info --format {{range .DiscoveredDevices}}{{println .ID}}{{end}}')
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
            echo "${HOST_STARTED-2100-01-01 00:00:00 UTC}"
            ;;
        is-enabled)
            if [[ $unit == "${HOST_DISABLED-ssh.service}" ]]; then
                echo "${HOST_SERVICE_STATE-disabled}"
                return 1
            fi
            echo enabled
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

    if [[ ( $1 == apt-get && ${HOST_FAIL-} == apt-update ) || ( $1 == env && ${HOST_FAIL-} == apt-install ) ]]; then
        echo "Mock APT ${HOST_FAIL#apt-} failure." >&2
        return 37
    fi

    case "$1" in
        docker|systemctl)
            "$@"
            ;;
        /usr/sbin/sshd)
            [[ $* == '/usr/sbin/sshd -G' ]]
            ;;
        usermod)
            [[ $* == 'usermod -aG docker vscode' ]] || return 99
            touch "$s/group"
            ;;
        mkdir|cp)
            [[ ${*: -1} == "$s/etc/"* ]] || return 99
            command "$@"
            ;;
        apt-get)
            [[ $* == 'apt-get -o APT::Update::Error-Mode=any update' ]]
            ;;
        env)
            local option
            for option in DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1 apt-get \
                --no-remove --no-upgrade --no-install-recommends Dpkg::Options::=--force-confold; do
                [[ " $* " == *" $option "* ]] || return 99
            done
            [[ $* == *' install -- '* ]] || return 99
            while [[ $1 != -- ]]; do shift; done
            shift
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
