#!/usr/bin/env bats
# Tests for the version-input scripts, the Dockerfile and the next.yml workflow.
# curl and docker are stubbed; nothing here touches the network or a registry.
# Needs bats, jq and yq (mikefarah) on PATH.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPTS="$ROOT/scripts"
  WORKFLOW="$ROOT/.github/workflows/next.yml"
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  export CURL_ARGS="$BATS_TEST_TMPDIR/curl.args"
  export CURL_FIXTURE="$BATS_TEST_TMPDIR/curl.out"
  export DOCKER_ARGS="$BATS_TEST_TMPDIR/docker.args"
  export DOCKER_FIXTURE="$BATS_TEST_TMPDIR/docker.out"

  cat >"$STUBS/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CURL_ARGS"
cat "$CURL_FIXTURE"
EOF
  cat >"$STUBS/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DOCKER_ARGS"
case "$1" in
  pull) exit 0 ;;
  inspect) cat "$DOCKER_FIXTURE" ;;
  *) echo "unexpected docker call: $*" >&2; exit 99 ;;
esac
EOF
  chmod +x "$STUBS/curl" "$STUBS/docker"
  PATH="$STUBS:$PATH"
}

# --- resolve-node.sh -------------------------------------------------------

@test "resolve_node_maps_26_to_the_latest_26_patch" {
  # decoy: a v25.x entry that a loose match would pick up
  cat >"$CURL_FIXTURE" <<'EOF'
aaaa  node-v25.9.0-linux-x64.tar.xz
bbbb  node-v26.13.1-linux-arm64.tar.xz
cccc  node-v26.13.1-linux-x64.tar.xz
dddd  node-v260.1.0-linux-x64.tar.xz
EOF
  run "$SCRIPTS/resolve-node.sh" 26
  [ "$status" -eq 0 ]
  [ "$output" = "26.13.1" ]
  grep -q 'latest-v26\.x' "$CURL_ARGS"
}

@test "resolve_node_picks_the_highest_patch_when_several_are_listed" {
  cat >"$CURL_FIXTURE" <<'EOF'
aaaa  node-v26.9.0-linux-x64.tar.xz
bbbb  node-v26.13.1-linux-x64.tar.xz
cccc  node-v26.13.0-linux-x64.tar.xz
EOF
  run "$SCRIPTS/resolve-node.sh" 26
  [ "$status" -eq 0 ]
  [ "$output" = "26.13.1" ]
}

@test "resolve_node_fails_when_the_listing_has_no_such_major" {
  echo "aaaa  node-v25.9.0-linux-x64.tar.xz" >"$CURL_FIXTURE"
  run "$SCRIPTS/resolve-node.sh" 26
  [ "$status" -eq 1 ]
}

@test "exact_version_is_unchanged" {
  : >"$CURL_FIXTURE"
  run "$SCRIPTS/resolve-node.sh" 26.13.1
  [ "$status" -eq 0 ]
  [ "$output" = "26.13.1" ]
  [ ! -e "$CURL_ARGS" ]
}

@test "resolve_node_rejects_anything_that_is_not_a_major_or_an_exact_version" {
  : >"$CURL_FIXTURE"
  for bad in "" "latest" "26.x" "26.13" "v26.13.1" "26; id" "../26"; do
    run "$SCRIPTS/resolve-node.sh" "$bad"
    [ "$status" -ne 0 ]
  done
  [ ! -e "$CURL_ARGS" ]
}

# --- check-tag.sh ----------------------------------------------------------

@test "check_tag_accepts_next_and_the_composition_of_the_inputs" {
  run "$SCRIPTS/check-tag.sh" next 4.0.10 26 4.18.1
  [ "$status" -eq 0 ]
  run "$SCRIPTS/check-tag.sh" ruby-4.0.10-node-26-yarn-4.18.1 4.0.10 26 4.18.1
  [ "$status" -eq 0 ]
  run "$SCRIPTS/check-tag.sh" ruby-4.0.10-node-26.13.1-yarn-4.18.1 4.0.10 26.13.1 4.18.1
  [ "$status" -eq 0 ]
}

@test "check_tag_rejects_a_well_formed_tag_with_other_versions" {
  run "$SCRIPTS/check-tag.sh" ruby-4.0.9-node-26-yarn-4.18.1 4.0.10 26 4.18.1
  [ "$status" -eq 1 ]
  run "$SCRIPTS/check-tag.sh" ruby-4.0.10-node-25-yarn-4.18.1 4.0.10 26 4.18.1
  [ "$status" -eq 1 ]
  run "$SCRIPTS/check-tag.sh" ruby-4.0.10-node-26-yarn-4.18.0 4.0.10 26 4.18.1
  [ "$status" -eq 1 ]
}

@test "check_tag_rejects_latest_scratch_and_a_path" {
  for bad in latest scratch "../next" "next/../latest" "ghcr.io/x/y:next" "next " " next" "" "NEXT"; do
    run "$SCRIPTS/check-tag.sh" "$bad" 4.0.10 26 4.18.1
    [ "$status" -eq 1 ]
  done
}

@test "check_tag_rejects_versions_that_are_not_plain_versions" {
  nl=$'4.0.10\nFOO=bar'
  run "$SCRIPTS/check-tag.sh" next "$nl" 26 4.18.1
  [ "$status" -eq 1 ]
  run "$SCRIPTS/check-tag.sh" next 4.0.10 "26,FOO=bar" 4.18.1
  [ "$status" -eq 1 ]
  run "$SCRIPTS/check-tag.sh" next 4.0.10 26 "4.18.1 --target x"
  [ "$status" -eq 1 ]
  run "$SCRIPTS/check-tag.sh" next 4.0 26 4.18.1
  [ "$status" -eq 1 ]
  run "$SCRIPTS/check-tag.sh" next 4.0.10 "" 4.18.1
  [ "$status" -eq 1 ]
}

@test "check_tag_needs_exactly_four_arguments" {
  run "$SCRIPTS/check-tag.sh" next 4.0.10 26
  [ "$status" -ne 0 ]
}

# --- compute-tags.sh -------------------------------------------------------

@test "compute_tags_adds_next_only_when_promoting" {
  run "$SCRIPTS/compute-tags.sh" ruby-4.0.10-node-26-yarn-4.18.1 true
  [ "$status" -eq 0 ]
  [ "$output" = $'ruby-4.0.10-node-26-yarn-4.18.1\nnext' ]
  # decoy: false prints the one tag only
  run "$SCRIPTS/compute-tags.sh" ruby-4.0.10-node-26-yarn-4.18.1 false
  [ "$status" -eq 0 ]
  [ "$output" = "ruby-4.0.10-node-26-yarn-4.18.1" ]
}

@test "compute_tags_prints_next_once_when_the_tag_is_next" {
  run "$SCRIPTS/compute-tags.sh" next true
  [ "$output" = "next" ]
  run "$SCRIPTS/compute-tags.sh" next false
  [ "$output" = "next" ]
}

@test "compute_tags_rejects_a_promote_value_that_is_not_true_or_false" {
  run "$SCRIPTS/compute-tags.sh" ruby-4.0.10-node-26-yarn-4.18.1 yes
  [ "$status" -ne 0 ]
  run "$SCRIPTS/compute-tags.sh" ruby-4.0.10-node-26-yarn-4.18.1 ""
  [ "$status" -ne 0 ]
}

# --- read-labels.sh --------------------------------------------------------

@test "read_labels_parses_the_three_labels" {
  cat >"$DOCKER_FIXTURE" <<'EOF'
{"org.occupier.ruby-version":"4.0.10","org.occupier.node-version":"26.13.1","org.occupier.yarn-version":"4.18.1","other":"x"}
EOF
  run "$SCRIPTS/read-labels.sh" ghcr.io/occupier/ruby-node:next
  [ "$status" -eq 0 ]
  [ "$output" = $'ruby_version=4.0.10\nnode_version=26.13.1\nyarn_version=4.18.1' ]
  grep -q 'ghcr.io/occupier/ruby-node:next' "$DOCKER_ARGS"
}

@test "push_build_without_labels_fails_telling_the_operator_to_dispatch_with_inputs" {
  # the published :next has no labels today: null, an empty object, or a partial set
  for fixture in 'null' '{}' '{"org.occupier.ruby-version":"4.0.10"}'; do
    printf '%s\n' "$fixture" >"$DOCKER_FIXTURE"
    run "$SCRIPTS/read-labels.sh" ghcr.io/occupier/ruby-node:next
    [ "$status" -eq 1 ]
    [[ "$output" == *"dispatch"* ]]
    [[ "$output" == *"ruby_version"* ]]
  done
}

@test "read_labels_rejects_an_empty_label_value" {
  echo '{"org.occupier.ruby-version":"4.0.10","org.occupier.node-version":"","org.occupier.yarn-version":"4.18.1"}' >"$DOCKER_FIXTURE"
  run "$SCRIPTS/read-labels.sh" ghcr.io/occupier/ruby-node:next
  [ "$status" -eq 1 ]
}

# --- Dockerfile ------------------------------------------------------------

@test "dockerfile_redeclares_the_args_after_from" {
  df="$ROOT/Dockerfile"
  from_line=$(grep -n '^FROM ' "$df" | head -1 | cut -d: -f1)
  [ -n "$from_line" ]
  # the one ARG before FROM feeds the base image tag
  first_arg=$(grep -n '^ARG RUBY_VERSION$' "$df" | head -1 | cut -d: -f1)
  [ -n "$first_arg" ]
  [ "$first_arg" -lt "$from_line" ]
  grep -q "^FROM cimg/ruby:\${RUBY_VERSION}\$" "$df"
  for arg in RUBY_VERSION NODE_VERSION YARN_VERSION; do
    # an ARG line with no default that appears after FROM
    line=$(grep -n "^ARG $arg\$" "$df" | tail -1 | cut -d: -f1)
    [ -n "$line" ]
    [ "$line" -gt "$from_line" ]
  done
}

@test "dockerfile_args_have_no_defaults" {
  run grep -E '^ARG (RUBY|NODE|YARN)_VERSION=' "$ROOT/Dockerfile"
  [ "$status" -eq 1 ]
}

@test "dockerfile_labels_carry_the_three_versions_from_the_args" {
  df="$ROOT/Dockerfile"
  grep -q 'org.occupier.ruby-version="\${RUBY_VERSION}"' "$df"
  grep -q 'org.occupier.node-version="\${NODE_VERSION}"' "$df"
  grep -q 'org.occupier.yarn-version="\${YARN_VERSION}"' "$df"
}

@test "dockerfile_keeps_the_corepack_from_npm_step" {
  grep -q 'npm install -g corepack' "$ROOT/Dockerfile"
}

@test "dockerfile_hardcodes_no_version" {
  run grep -E 'cimg/ruby:[0-9]|NODE_VERSION=[0-9]|YARN_VERSION=[0-9]|yarn@[0-9]' "$ROOT/Dockerfile"
  [ "$status" -eq 1 ]
}

# --- next.yml --------------------------------------------------------------

@test "next_yml_job_runs_only_on_the_next_ref" {
  guard="github.ref == 'refs/heads/next'"
  run yq -r '.jobs | length' "$WORKFLOW"
  [ "$output" -ge 1 ]
  # decoy: no job may lack the guard
  run yq -r '.jobs | to_entries | map(select(.value.if != "'"$guard"'")) | length' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "next_yml_dispatch_takes_the_five_inputs" {
  run yq -r '.on.workflow_dispatch.inputs | keys | sort | join(",")' "$WORKFLOW"
  [ "$output" = "node_version,promote,ruby_version,tag,yarn_version" ]
  run yq -r '.on.workflow_dispatch.inputs.promote.type' "$WORKFLOW"
  [ "$output" = "boolean" ]
  run yq -r '.on.workflow_dispatch.inputs.promote.default' "$WORKFLOW"
  [ "$output" = "false" ]
  for i in ruby_version node_version yarn_version tag; do
    run yq -r ".on.workflow_dispatch.inputs.$i.required" "$WORKFLOW"
    [ "$output" = "true" ]
  done
}

@test "next_yml_keeps_the_push_trigger_on_next_and_names_the_run_after_the_tag" {
  run yq -r '.on.push.branches | join(",")' "$WORKFLOW"
  [ "$output" = "next" ]
  run yq -r '.["run-name"]' "$WORKFLOW"
  [ "$output" = 'build ${{ inputs.tag }}' ]
}

@test "next_yml_run_steps_never_interpolate_expressions" {
  # inputs reach the shell only through env, so a crafted input cannot inject a command
  run yq -r '.jobs[].steps[].run // ""' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" != *'${{'* ]]
}

@test "next_yml_checks_the_tag_before_building" {
  run yq -r '.jobs[].steps[].run // ""' "$WORKFLOW"
  [[ "$output" == *"scripts/check-tag.sh"* ]]
  [[ "$output" == *"scripts/resolve-node.sh"* ]]
  [[ "$output" == *"scripts/compute-tags.sh"* ]]
  [[ "$output" == *"scripts/read-labels.sh"* ]]
}

@test "next_yml_passes_the_resolved_versions_as_build_args_and_names_no_private_repo" {
  run yq -r '.jobs[].steps[].with["build-args"] // ""' "$WORKFLOW"
  [[ "$output" == *"RUBY_VERSION="* ]]
  [[ "$output" == *"NODE_VERSION="* ]]
  [[ "$output" == *"YARN_VERSION="* ]]
  run grep -n 'occupier/occupier' "$WORKFLOW"
  [ "$status" -eq 1 ]
}

@test "next_yml_gives_the_token_only_the_permissions_the_push_needs" {
  run yq -r '.permissions | to_entries | map(.key + "=" + .value) | sort | join(",")' "$WORKFLOW"
  [ "$output" = "contents=read,packages=write" ]
}
