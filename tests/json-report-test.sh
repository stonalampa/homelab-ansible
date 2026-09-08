#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
report_file="$(mktemp "${TMPDIR:-/tmp}/homelab-report.XXXXXX")"
trap 'rm -f "$report_file"' EXIT

REPORT_TEST_PATH="$report_file" ansible-playbook \
  -i localhost, "$repo_dir/tests/json-report.yml" >/dev/null

python3 - "$report_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as report:
    data = json.load(report)

assert data["generated_at"] == "2030-01-01T00:00:00Z"
assert set(data["results"][0]) == {
    "target", "type", "status", "reboot_required", "error"
}
assert "ansible" not in json.dumps(data).lower()
PY

echo "Machine-readable report check passed."
