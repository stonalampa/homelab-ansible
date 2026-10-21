#!/usr/bin/env bash

run_update_workflow() {
  local apply_playbook="$1"
  local default_limit="$2"
  local apply_description="$3"
  local manages_homebrew="$4"
  shift 4

  local config_dir="${HOMELAB_CONFIG_DIR:-${HOME}/.config/homelab-ansible}"
  local inventory_file="${config_dir}/inventory.yml"
  local local_vars_file="${config_dir}/group_vars/local.yml"
  local workflow_limit="$default_limit"
  local confirmation
  local preflight_rc
  local apply_rc
  local post_homebrew_rc=0
  local report_dir
  local report_generated_at
  local report_file
  local -a common_args
  local -a apply_args

  while (($#)); do
    case "$1" in
      --limit)
        [[ $# -ge 2 ]] || { update_workflow_usage >&2; return 2; }
        workflow_limit="$2"
        shift 2
        ;;
      -h|--help)
        update_workflow_usage
        return 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        update_workflow_usage >&2
        return 2
        ;;
    esac
  done

  [[ "$workflow_limit" =~ ^[A-Za-z0-9_.:-]+$ ]] || {
    echo "Invalid --limit value: $workflow_limit" >&2
    return 2
  }
  [[ -f "$inventory_file" ]] || {
    echo "External inventory not found: $inventory_file" >&2
    return 2
  }
  [[ -f "$local_vars_file" ]] || {
    echo "External local variables not found: $local_vars_file" >&2
    return 2
  }

  common_args=(
    -i "$inventory_file"
    --extra-vars "@$local_vars_file"
    --extra-vars "{\"workflow_limit\":\"$workflow_limit\"}"
  )

  echo "Running read-only preflight for target: $workflow_limit"
  ANSIBLE_ROLES_PATH="${repo_dir}/roles" ansible-playbook \
    "${common_args[@]}" "$repo_dir/playbooks/preflight.yml"
  preflight_rc=$?
  if ((preflight_rc != 0)); then
    echo "Preflight failed; apply was not started." >&2
    return "$preflight_rc"
  fi

  echo
  echo "$apply_description"
  echo "No VM, major upgrade, or reboot operation will run."
  echo "Proxmox apply includes apt-get autoremove for orphaned packages."
  read -r -p "Type APPLY to continue: " confirmation
  if [[ "$confirmation" != "APPLY" ]]; then
    echo "Apply cancelled; no update command was run."
    return 2
  fi

  if [[ "$manages_homebrew" == true \
        && "$workflow_limit" =~ ^(all|localhost|homebrew)$ ]]; then
    echo "Authorizing privileged Homebrew cask maintenance."
    sudo -v || {
      echo "Sudo authorization failed; apply was not started." >&2
      return 2
    }
  fi

  report_dir="${repo_dir}/reports"
  report_generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  report_file="${report_dir}/update-${report_generated_at//:/-}.json"
  mkdir -p "$report_dir"
  apply_args=(
    "${common_args[@]}"
    --extra-vars "{\"update_report_generated_at\":\"$report_generated_at\"}"
    --extra-vars "{\"update_report_path\":\"$report_file\"}"
  )

  ANSIBLE_ROLES_PATH="${repo_dir}/roles" ansible-playbook \
    "${apply_args[@]}" "$repo_dir/playbooks/$apply_playbook"
  apply_rc=$?

  if [[ "$manages_homebrew" == true \
        && "$workflow_limit" =~ ^(all|localhost|homebrew)$ ]]; then
    echo "Updating the Ansible runtime after the playbook has exited."
    HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade ansible python@3.14 || post_homebrew_rc=$?
    brew cleanup || post_homebrew_rc=$?
  fi

  ((apply_rc != 0)) && return "$apply_rc"
  return "$post_homebrew_rc"
}

