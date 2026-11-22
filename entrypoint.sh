#!/bin/sh
set -eu

GIT_SYNC_SCRIPT="${GIT_SYNC_SCRIPT:-/git-sync.sh}"
SSH_DIR="${SSH_DIR:-${HOME}/.ssh}"

write_ssh_key() {
  key_content="$1"
  key_path="$2"

  umask 077
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  # Support both multi-line secrets and single-line keys with literal \n escapes
  case "$key_content" in
    *'
'*)
      printf '%s\n' "$key_content" >"$key_path"
      ;;
    *)
      printf '%s\n' "$key_content" | awk '{ gsub(/\\n/, "\n"); print }' >"$key_path"
      ;;
  esac

  chmod 600 "$key_path"
}

init_known_hosts() {
  umask 077
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  known_hosts_file="${SSH_DIR}/known_hosts"

  if [ -f "/etc/ssh/git_sync_known_hosts" ]; then
    cat "/etc/ssh/git_sync_known_hosts" >>"$known_hosts_file"
  fi

  if [ -n "${SSH_KNOWN_HOSTS:-}" ]; then
    printf '\n%s\n' "$SSH_KNOWN_HOSTS" >>"$known_hosts_file"
  fi

  if [ -f "$known_hosts_file" ]; then
    chmod 600 "$known_hosts_file"
  fi
}

if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  write_ssh_key "$SSH_PRIVATE_KEY" "${SSH_DIR}/shared_key"
fi

if [ -n "${SOURCE_SSH_PRIVATE_KEY:-}" ]; then
  write_ssh_key "$SOURCE_SSH_PRIVATE_KEY" "${SSH_DIR}/source_key"
fi

if [ -n "${DESTINATION_SSH_PRIVATE_KEY:-}" ]; then
  write_ssh_key "$DESTINATION_SSH_PRIVATE_KEY" "${SSH_DIR}/destination_key"
fi

if [ -n "${SSH_PRIVATE_KEY:-}${SOURCE_SSH_PRIVATE_KEY:-}${DESTINATION_SSH_PRIVATE_KEY:-}${SSH_KNOWN_HOSTS:-}" ]; then
  init_known_hosts
fi

export GIT_SYNC_SSH_DIR="$SSH_DIR"

# Pass positional arguments safely without shell re-evaluation (prevents command injection)
exec "$GIT_SYNC_SCRIPT" "$@"
