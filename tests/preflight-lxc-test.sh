#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_file="$(mktemp "${TMPDIR:-/tmp}/homelab-preflight-lxc.XXXXXX")"
trap 'rm -f "$output_file"' EXIT

ansible-playbook \
  -i "$repo_dir/tests/fixtures/preflight-lxc-inventory.yml" \
  "$repo_dir/tests/preflight-lxc.yml" >"$output_file"

grep -F "Preflight passed. Review the plan before approving apply." \
  "$output_file" >/dev/null

echo "LXC-only preflight regression check passed."
