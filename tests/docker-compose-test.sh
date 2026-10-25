#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/homelab-docker-mock.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

run_case() {
  local scenario="$1"
  local expected_status="$2"
  local expected_error="${3:-}"
  local log_file="$test_dir/${scenario}.log"

  DOCKER_MOCK_BIN="$repo_dir/tests/mock-bin" \
  DOCKER_MOCK_LOG="$log_file" \
  DOCKER_MOCK_SCENARIO="$scenario" \
  ANSIBLE_ROLES_PATH="$repo_dir/roles" \
    ansible-playbook \
      -i "$repo_dir/tests/fixtures/docker-compose-inventory.yml" \
      --extra-vars "expected_status=$expected_status" \
      --extra-vars "{\"expected_error\":\"$expected_error\"}" \
      "$repo_dir/tests/docker-compose.yml" >/dev/null
}

run_case success SUCCESS
grep -F "docker compose --project-directory /srv/example-stack pull" \
  "$test_dir/success.log" >/dev/null
grep -F "docker compose --project-directory /srv/example-stack up -d" \
  "$test_dir/success.log" >/dev/null

run_case success-v1 SUCCESS
grep -F "docker-compose --project-directory /srv/example-stack pull" \
  "$test_dir/success-v1.log" >/dev/null
grep -F "docker-compose --project-directory /srv/example-stack up -d" \
  "$test_dir/success-v1.log" >/dev/null

run_case skipped SKIPPED
if grep -Eq ' (pull|up -d)$' "$test_dir/skipped.log"; then
  echo "A skipped Compose project reached an apply command." >&2
  exit 1
fi

run_case failed FAILED
grep -F "docker compose --project-directory /srv/example-stack pull" \
  "$test_dir/failed.log" >/dev/null
if grep -F "docker compose --project-directory /srv/example-stack up -d" \
  "$test_dir/failed.log"; then
  echo "Compose up ran after a failed pull." >&2
  exit 1
fi

run_case unhealthy FAILED "mock-app running unhealthy"
grep -F "docker compose --project-directory /srv/example-stack ps -q" \
  "$test_dir/unhealthy.log" >/dev/null
grep -F "docker inspect --format {{.Name}} {{.State.Status}}" \
  "$test_dir/unhealthy.log" | grep -F "mock-container-id" >/dev/null

run_case restarting FAILED "mock-app restarting none"
grep -F "docker compose --project-directory /srv/example-stack ps -q" \
  "$test_dir/restarting.log" >/dev/null

# A healthcheck still in its start period is polled again, not failed.
run_case starting SUCCESS
[[ "$(grep -c ' docker inspect ' "$test_dir/starting.log")" == "2" ]]

echo "Docker Compose role mock checks passed."
