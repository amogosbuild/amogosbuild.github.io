#!/bin/sh
set -eu
if [ "$(id -u)" != 0 ]; then
    printf '%s\n' 'Run this script as root after reviewing it.' >&2
    exit 1
fi
command -v curl >/dev/null
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl --fail --location --proto '=https' --tlsv1.2 --output "$temporary/keyring.deb" 'https://amogosbuild.github.io/amogos-debian/pool/main/a/amogos-archive-keyring/amogos-archive-keyring_2.0.0-1_all.deb'
printf '%s  %s\n' '4897fcf13828e666095d502eadb0f73975efc0c7d751764625623e32d00a703d' "$temporary/keyring.deb" | sha256sum -c -
apt-get install --no-install-recommends -y "$temporary/keyring.deb"
apt-get -o APT::Update::Error-Mode=any update
apt-get install --no-install-recommends -y amogos-update
