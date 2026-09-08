#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_file="$(mktemp "${TMPDIR:-/tmp}/homelab-reporting.XXXXXX")"
trap 'rm -f "$output_file"' EXIT

ANSIBLE_ROLES_PATH="$repo_dir/roles" ansible-playbook \
  -i "$repo_dir/tests/fixtures/reporting-inventory.yml" \
  "$repo_dir/tests/reporting.yml" >"$output_file"

grep -F "available: curl, openssl" "$output_file" >/dev/null
if grep -F 'available: \\1, \\1' "$output_file"; then
  echo "APT package names were rendered as regex backreferences." >&2
  exit 1
fi
grep -F "Reboot required on: none." "$output_file" >/dev/null
grep -F "Checked Linux hosts: raspberry-pi.example." "$output_file" >/dev/null
if grep -F "no checked hosts" "$output_file"; then
  echo "A checked Raspberry Pi was omitted from the reboot summary." >&2
  exit 1
fi

echo "Reporting regression checks passed."
