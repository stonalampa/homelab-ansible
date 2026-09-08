#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ANSIBLE_HOME=/tmp/ansible-home
export ANSIBLE_LOCAL_TEMP=/tmp/ansible-local
export ANSIBLE_ROLES_PATH="$repo_dir/roles"

python3 "$repo_dir/tests/integration/servers.py" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT

for attempt in 1 2 3 4 5; do
  if python3 -c 'import socket; socket.create_connection(("127.0.0.1", 18081), 1).close()'; then
    break
  fi
  [[ "$attempt" -lt 5 ]] || exit 1
  sleep 1
done

ansible-playbook -i localhost, "$repo_dir/tests/integration/health-checks.yml"
"$repo_dir/tests/docker-compose-test.sh"

echo "Disposable Linux integration checks passed."
