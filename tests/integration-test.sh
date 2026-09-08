#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id="${PPID}-$$"
image_name="homelab-ansible-integration:${run_id}"
container_name="homelab-ansible-integration-${run_id}"

cleanup() {
  docker image rm "$image_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker build --file "$repo_dir/tests/integration/Dockerfile" \
  --tag "$image_name" "$repo_dir"
docker run --rm --name "$container_name" --network none "$image_name"
