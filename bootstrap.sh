#!/usr/bin/env bash
# Ubuntu Server bootstrap: install mise from its APT repository, then apply this checkout with chezmoi.
set -euo pipefail

key=$(mktemp)
trap 'rm -f -- "$key"' EXIT
curl --fail --location --silent --show-error https://mise.jdx.dev/gpg-key.pub -o "$key"
if ! gpg --show-keys --with-colons "$key" | grep -q '^fpr:::::::::24853EC9F655CE80B48E6C3A8B81C9D17413A06D:'; then
    echo 'The mise signing key does not match 24853EC9F655CE80B48E6C3A8B81C9D17413A06D.' >&2
    exit 1
fi
sudo gpg --dearmor --yes -o /etc/apt/keyrings/mise.gpg "$key"
printf '%s\n' 'Types: deb' 'URIs: https://mise.jdx.dev/deb' 'Suites: stable' 'Components: main' \
    'Signed-By: /etc/apt/keyrings/mise.gpg' | sudo tee /etc/apt/sources.list.d/mise.sources > /dev/null
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y mise

mise exec chezmoi@latest -- chezmoi init --apply --source "$(cd "$(dirname "$0")" && pwd)" "$@"
