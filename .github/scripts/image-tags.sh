#!/usr/bin/env bash
# Print the image tags to push, one per line, for the Dockerfile in the current directory.
#
# Usage: image-tags.sh <floating-tag> [prefix]
#
#   floating-tag  the moving tag for this branch (latest or next)
#   prefix        optional prefix for the version tags (for example "next-")
#
# Tags printed:
#   <floating-tag>                                 moves with every build
#   <prefix>ruby-<ruby>-node-<node>                moves with weekly rebuilds of the same versions
#   <prefix>ruby-<ruby>-node-<node>-<date>-<run>   immutable, one per workflow run (pin to this)
#   <prefix>sha-<short>                            the commit, moves only if the commit is rebuilt
set -euo pipefail

floating="${1:?floating tag required}"
prefix="${2:-}"

ruby_version="$(sed -nE 's#^FROM cimg/ruby:([0-9][0-9.]*).*#\1#p' Dockerfile)"
node_version="$(sed -nE 's#^ENV NODE_VERSION=([0-9][0-9.]*).*#\1#p' Dockerfile)"

if [[ -z "$ruby_version" || -z "$node_version" ]]; then
  echo "could not read the Ruby and Node versions from the Dockerfile" >&2
  exit 1
fi

version_tag="${prefix}ruby-${ruby_version}-node-${node_version}"
date_stamp="$(date -u +%Y%m%d)"

echo "ghcr.io/occupier/ruby-node:${floating}"
echo "ghcr.io/occupier/ruby-node:${version_tag}"
echo "ghcr.io/occupier/ruby-node:${version_tag}-${date_stamp}-${GITHUB_RUN_NUMBER:-0}"
echo "ghcr.io/occupier/ruby-node:${prefix}sha-${GITHUB_SHA:0:7}"
