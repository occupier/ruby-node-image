#!/usr/bin/env bash
# Usage: compute-tags.sh TAG PROMOTE
# Prints the tags to push, one per line: TAG, plus `next` only when PROMOTE is true.
# PROMOTE must be the string true or false.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: compute-tags.sh TAG PROMOTE" >&2
  exit 2
fi
tag=$1 promote=$2

case "$promote" in
  true | false) ;;
  *)
    echo "compute-tags: PROMOTE must be true or false" >&2
    exit 2
    ;;
esac

printf '%s\n' "$tag"
if [ "$promote" = "true" ] && [ "$tag" != "next" ]; then
  printf 'next\n'
fi
