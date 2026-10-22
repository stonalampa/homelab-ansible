#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/homelab-cleanup-mock.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

run_case() {
  local scenario="$1"
  local expected_status="$2"
  local log_file="$test_dir/${scenario}.log"

  DOCKER_MOCK_BIN="$repo_dir/tests/mock-bin" \
  DOCKER_MOCK_LOG="$log_file" \
  DOCKER_MOCK_SCENARIO="$scenario" \
  ANSIBLE_ROLES_PATH="$repo_dir/roles" \
    ansible-playbook \
      -i "$repo_dir/tests/fixtures/docker-compose-inventory.yml" \
      --extra-vars "expected_status=$expected_status" \
      "$repo_dir/tests/docker-cleanup.yml" >/dev/null
}

run_case success SUCCESS
grep -Fx "exec 903 -- docker image prune --force" "$test_dir/success.log" >/dev/null
if grep -F "904" "$test_dir/success.log"; then
  echo "An LXC without a Compose project was touched." >&2
  exit 1
fi

run_case skipped SKIPPED
if grep -F "prune" "$test_dir/skipped.log"; then
  echo "A stopped LXC reached the prune command." >&2
  exit 1
fi

run_case prune-failed FAILED
if grep -F "df --output=pcent" "$test_dir/prune-failed.log"; then
  echo "Disk usage was read after a failed prune." >&2
  exit 1
fi

echo "Docker image prune role mock checks passed."
