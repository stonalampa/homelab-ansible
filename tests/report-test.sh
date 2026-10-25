#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/homelab-report.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

cat >"$test_dir/failed.json" <<'JSON'
{
  "generated_at": "2030-01-01T00:00:00Z",
  "results": [
    {"target": "ct-example", "type": "LXC", "status": "SUCCESS",
     "reboot_required": "yes", "error": ""},
    {"target": "compose-example", "type": "Docker", "status": "FAILED",
     "reboot_required": "unknown",
     "error": "task=Require every Compose container to be running and healthy; rc=n/a; error=Not running/healthy after up -d (container status health): app running unhealthy"},
    {"target": "ct-stopped", "type": "LXC", "status": "SKIPPED",
     "reboot_required": "unknown", "error": "LXC is not running"}
  ]
}
JSON
cat >"$test_dir/clean.json" <<'JSON'
{"generated_at": "2030-01-01T00:00:00Z", "results": [
  {"target": "ct-example", "type": "LXC", "status": "SUCCESS",
   "reboot_required": "no", "error": ""}]}
JSON

set +e
"$repo_dir/bin/report" "$test_dir/failed.json" >"$test_dir/failed.out"
failed_rc=$?
"$repo_dir/bin/report" --all "$test_dir/clean.json" >"$test_dir/clean.out"
clean_rc=$?
"$repo_dir/bin/report" "$test_dir/missing.json" >/dev/null 2>&1
missing_rc=$?
set -e

[[ "$failed_rc" == "1" && "$clean_rc" == "0" && "$missing_rc" == "2" ]] || {
  echo "Unexpected report exit codes: $failed_rc $clean_rc $missing_rc" >&2
  exit 1
}
grep -F "1 SUCCESS, 1 FAILED, 1 SKIPPED" "$test_dir/failed.out" >/dev/null
grep -F "Reboot required: ct-example" "$test_dir/failed.out" >/dev/null
grep -F "error: Not running/healthy after up -d (container status health): app running unhealthy" \
  "$test_dir/failed.out" >/dev/null
grep -F "error: LXC is not running" "$test_dir/failed.out" >/dev/null
if grep -F $'\033[' "$test_dir/failed.out"; then
  echo "Report used colors while writing to a file." >&2
  exit 1
fi
grep -F "Nothing failed." "$test_dir/clean.out" >/dev/null
grep -E "^  ct-example +LXC +SUCCESS$" "$test_dir/clean.out" >/dev/null

echo "Report summary checks passed."
