#!/usr/bin/env bash
# Usage: read-labels.sh IMAGE
# Pulls IMAGE and prints the three version labels it was built with, as
#   ruby_version=...
#   node_version=...
#   yarn_version=...
# Exits 1 when any of the three is missing or empty (an image published before the
# labels existed).
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: read-labels.sh IMAGE" >&2
  exit 2
fi
image=$1

docker pull --quiet "$image" >/dev/null
labels=$(docker inspect "$image" --format '{{json .Config.Labels}}')

ruby=$(jq -r '.["org.occupier.ruby-version"] // empty' <<<"$labels")
node=$(jq -r '.["org.occupier.node-version"] // empty' <<<"$labels")
yarn=$(jq -r '.["org.occupier.yarn-version"] // empty' <<<"$labels")

if [ -z "$ruby" ] || [ -z "$node" ] || [ -z "$yarn" ]; then
  {
    echo "read-labels: $image has no org.occupier.ruby-version, org.occupier.node-version and org.occupier.yarn-version labels."
    echo "To publish the first labelled image, dispatch next.yml on the next ref with explicit inputs (ruby_version, node_version, yarn_version, tag, promote)."
  } >&2
  exit 1
fi

printf 'ruby_version=%s\nnode_version=%s\nyarn_version=%s\n' "$ruby" "$node" "$yarn"
