FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl git shellcheck=0.11.0-2 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash vscode

RUN <<'EOF'
set -eu
arch=$(dpkg --print-architecture)
case "$arch" in
    amd64) sha=9f97d32caca166e5c92160ec3a9325519809c38963121cef38173142065c981f ;;
    arm64) sha=75508ef41216b6d64f3145986b751729d7f92d09c6bad77d51cf2895ab35a508 ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

curl --fail --location --silent --show-error \
    "https://github.com/twpayne/chezmoi/releases/download/v2.72.1/chezmoi_2.72.1_linux_${arch}.tar.gz" \
    --output /tmp/chezmoi.tar.gz
printf '%s  /tmp/chezmoi.tar.gz\n' "$sha" | sha256sum --check --status
tar -xzf /tmp/chezmoi.tar.gz -C /usr/local/bin chezmoi
rm /tmp/chezmoi.tar.gz
EOF

USER vscode
WORKDIR /workspaces/dotfiles
