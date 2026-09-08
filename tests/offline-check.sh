#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ANSIBLE_HOME="$repo_dir/.ansible"
export ANSIBLE_LOCAL_TEMP="$repo_dir/.ansible/tmp"
export XDG_CACHE_HOME="$repo_dir/.cache"

bash -n "$repo_dir/bin/update-check" "$repo_dir/bin/update-all" \
  "$repo_dir/bin/update-docker" "$repo_dir/bin/lib/update-workflow.sh" \
  "$repo_dir/tests/mock-workflow.sh" "$repo_dir/tests/reporting-test.sh" \
  "$repo_dir/tests/preflight-lxc-test.sh" \
  "$repo_dir/tests/docker-compose-test.sh" \
  "$repo_dir/tests/json-report-test.sh" "$repo_dir/tests/integration-test.sh" \
  "$repo_dir/tests/integration/run.sh" \
  "$repo_dir/tests/mock-bin/ansible-playbook" "$repo_dir/tests/mock-bin/pct"
"$repo_dir/bin/update-check" --help >/dev/null
"$repo_dir/bin/update-docker" --help >/dev/null

# The wrapper must reference external configuration and must not offer an
# in-repository inventory override.
grep -F 'HOMELAB_CONFIG_DIR' "$repo_dir/bin/update-check" >/dev/null
grep -F 'homebrew_update_check_enabled=false' "$repo_dir/bin/update-check" >/dev/null
if grep -F -- '--inventory' "$repo_dir/bin/update-check"; then
  echo "The wrapper must not accept an in-repository inventory path." >&2
  exit 1
fi

# Homebrew accepts one output mode here; --quiet covers formulae and casks.
[[ "$(grep -RFl --include='*.yml' 'brew outdated --quiet' \
  "$repo_dir/playbooks" "$repo_dir/roles" | wc -l | tr -d ' ')" == "2" ]]
if grep -RFn --include='*.yml' -- 'brew outdated --formula --cask' \
  "$repo_dir/playbooks" "$repo_dir/roles"; then
  echo "Mutually exclusive Homebrew outdated flags were found." >&2
  exit 1
fi

# Syntax parsing does not connect to any inventory host.
for playbook in "$repo_dir"/playbooks/*.yml; do
  ANSIBLE_ROLES_PATH="$repo_dir/roles" ansible-playbook \
    -i "$repo_dir/inventory/inventory.example.yml" \
    "$playbook" --syntax-check
done

yamllint "$repo_dir"
ansible-lint "$repo_dir/playbooks" "$repo_dir/roles"
"$repo_dir/tests/mock-workflow.sh"
"$repo_dir/tests/reporting-test.sh"
"$repo_dir/tests/preflight-lxc-test.sh"
"$repo_dir/tests/docker-compose-test.sh"
"$repo_dir/tests/json-report-test.sh"

# Guard the apply implementation against explicitly forbidden command forms.
if grep -RInE --include='*.yml' --include='*.sh' \
  '^[[:space:]]*-[[:space:]]+(dist-upgrade|full-upgrade|autoremove|reboot|shutdown|sudo)$' \
  "$repo_dir/playbooks" "$repo_dir/roles" "$repo_dir/bin"; then
  echo "A forbidden apply command was found." >&2
  exit 1
fi

# Docker lifecycle is intentionally limited to pull and up -d.
if grep -RInE --include='*.yml' \
  'docker.*(compose[[:space:]]+down|system[[:space:]]+prune|volume[[:space:]]+rm|image[[:space:]]+rm|container[[:space:]]+rm|network[[:space:]]+rm)' \
  "$repo_dir/playbooks" "$repo_dir/roles"; then
  echo "A destructive Docker command was found." >&2
  exit 1
fi

# Fail if forbidden private material is tracked.
if git -C "$repo_dir" ls-files | grep -E \
  '(^|/)(inventory\.ya?ml|local\.ya?ml|group_vars/|host_vars/|.*\.vault(\.ya?ml)?|.*vault-password|id_(rsa|ed25519)|.*\.(pem|key))$'; then
  echo "Potential private material is tracked." >&2
  exit 1
fi

# Scan source files, including new and untracked files, for common secret forms.
if grep -RInE \
  --exclude-dir=.git --exclude-dir=.venv --exclude-dir=.ansible --exclude-dir=.cache \
  --exclude='offline-check.sh' \
  '(BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|password[[:space:]]*:[[:space:]]*[^<{[:space:]]+|token[[:space:]]*:[[:space:]]*[^<{[:space:]]+)' \
  "$repo_dir"; then
  echo "Potential secret value found in repository content." >&2
  exit 1
fi

echo "Offline checks passed; no remote connection was attempted."
