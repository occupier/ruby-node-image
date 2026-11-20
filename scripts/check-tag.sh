#!/usr/bin/env bash
# Usage: check-tag.sh TAG RUBY NODE YARN
# Exits 0 when TAG is `next` or exactly ruby-RUBY-node-NODE-yarn-YARN, and the three
# versions are plain versions. Anything else exits 1. This bounds the tag name only:
# whoever dispatches the build also chooses the versions.
#   RUBY, YARN: x.y.z    NODE: a major (26) or x.y.z
set -euo pipefail

if [ $# -ne 4 ]; then
  echo "usage: check-tag.sh TAG RUBY NODE YARN" >&2
  exit 2
fi
tag=$1 ruby=$2 node=$3 yarn=$4

fail() {
  echo "check-tag: $1" >&2
  exit 1
}

# Versions end up in build arguments, so refuse anything that is not a plain version
# (a newline or a comma in a value could add a second build argument).
[[ $ruby =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "ruby version is not x.y.z"
[[ $node =~ ^[0-9]+(\.[0-9]+\.[0-9]+)?$ ]] || fail "node version is not a major or x.y.z"
[[ $yarn =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "yarn version is not x.y.z"

if [ "$tag" = "next" ] || [ "$tag" = "ruby-${ruby}-node-${node}-yarn-${yarn}" ]; then
  exit 0
fi
fail "tag must be next or ruby-${ruby}-node-${node}-yarn-${yarn}"
