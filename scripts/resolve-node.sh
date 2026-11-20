#!/usr/bin/env bash
# Usage: resolve-node.sh VALUE
# Prints an exact Node version. A major (26) resolves to the latest patch of that
# major from nodejs.org's latest-v<major>.x listing; an exact version (26.13.1) is
# printed unchanged. Anything else exits 1.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: resolve-node.sh VALUE" >&2
  exit 2
fi
value=$1

if [[ $value =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf '%s\n' "$value"
  exit 0
fi

if [[ ! $value =~ ^[0-9]+$ ]]; then
  echo "resolve-node: expected a major (26) or an exact version (26.13.1), got: $value" >&2
  exit 1
fi

listing=$(curl -fsSL --retry 3 "https://nodejs.org/dist/latest-v${value}.x/SHASUMS256.txt")

# Match the linux-x64 tarball of this major only, so a neighbouring major or a
# longer major (26 against 260) in the listing is never picked up.
version=$(
  printf '%s\n' "$listing" |
    grep -oE "node-v${value}\.[0-9]+\.[0-9]+-linux-x64\.tar\.xz" |
    sed -E 's/^node-v//; s/-linux-x64\.tar\.xz$//' |
    sort -t. -k1,1n -k2,2n -k3,3n |
    tail -n 1 || true
)

if [ -z "$version" ]; then
  echo "resolve-node: no Node ${value}.x release found in nodejs.org's latest-v${value}.x listing" >&2
  exit 1
fi
printf '%s\n' "$version"
