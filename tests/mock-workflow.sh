#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/homelab-ansible-mock.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/config/group_vars"
touch "$test_dir/config/inventory.yml" "$test_dir/config/group_vars/local.yml"

run_case() {
  local scenario="$1"
  local expected_rc="$2"
  local expected_text="$3"
  local output_file="$test_dir/${scenario}.out"
  local log_file="$test_dir/${scenario}.log"
  local actual_rc

  set +e
  printf 'APPLY\n' | env \
    HOMELAB_CONFIG_DIR="$test_dir/config" \
    MOCK_SCENARIO="$scenario" \
    MOCK_LOG="$log_file" \
    PATH="$repo_dir/tests/mock-bin:$PATH" \
    "$repo_dir/bin/update-all" >"$output_file" 2>&1
  actual_rc=$?
  set -e

  [[ "$actual_rc" -eq "$expected_rc" ]] || {
    echo "$scenario: expected rc=$expected_rc, got rc=$actual_rc" >&2
    return 1
  }
  grep -F "$expected_text" "$output_file" >/dev/null
}

run_case success 0 "localhost | Homebrew | SUCCESS | no"
run_case unavailable-host 4 "apply was not started"
[[ "$(wc -l <"$test_dir/unavailable-host.log" | tr -d ' ')" == "1" ]]
run_case stopped-lxc 0 "ct-example | LXC | SKIPPED | unknown"
run_case partial-failure 1 "ct-example | LXC | FAILED | unknown"

docker_output="$test_dir/docker-entrypoint.out"
printf 'APPLY\n' | env \
  HOMELAB_CONFIG_DIR="$test_dir/config" \
  MOCK_SCENARIO=success \
  MOCK_LOG="$test_dir/docker-entrypoint.log" \
  PATH="$repo_dir/tests/mock-bin:$PATH" \
  "$repo_dir/bin/update-docker" --limit docker >"$docker_output" 2>&1
grep -F "compose-example | Docker | SUCCESS | no" "$docker_output" >/dev/null
grep -F '/playbooks/update-docker.yml' "$test_dir/docker-entrypoint.log" >/dev/null

echo "Mock workflow checks passed."
