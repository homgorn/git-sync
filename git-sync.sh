#!/bin/sh
set -eu

if [ "$#" -lt 4 ]; then
  echo "Usage: git-sync.sh <source_repo> <source_branch> <destination_repo> <destination_branch>" >&2
  exit 1
fi

SOURCE_REPO="$1"
SOURCE_BRANCH="$2"
DESTINATION_REPO="$3"
DESTINATION_BRANCH="$4"

SSH_DIR="${GIT_SYNC_SSH_DIR:-${HOME}/.ssh}"
PUSH_MODE="${PUSH_MODE:-force}"
DRY_RUN="${DRY_RUN:-false}"
PRUNE="${PRUNE:-false}"
SYNC_TAGS="${SYNC_TAGS:-false}"
STRICT_HOST_KEY_CHECKING="${STRICT_HOST_KEY_CHECKING:-yes}"

# Validate configuration inputs
case "$PUSH_MODE" in
  force|force-with-lease|fast-forward) ;;
  *)
    echo "Error: invalid PUSH_MODE '$PUSH_MODE' (expected: force | force-with-lease | fast-forward)" >&2
    exit 1
    ;;
esac

case "$STRICT_HOST_KEY_CHECKING" in
  yes|accept-new) ;;
  *)
    echo "Error: invalid STRICT_HOST_KEY_CHECKING '$STRICT_HOST_KEY_CHECKING' (expected: yes | accept-new)" >&2
    exit 1
    ;;
esac

case "$DRY_RUN" in
  true|false) ;;
  *)
    echo "Error: invalid DRY_RUN '$DRY_RUN' (expected: true | false)" >&2
    exit 1
    ;;
esac

case "$PRUNE" in
  true|false) ;;
  *)
    echo "Error: invalid PRUNE '$PRUNE' (expected: true | false)" >&2
    exit 1
    ;;
esac

case "$SYNC_TAGS" in
  true|false) ;;
  *)
    echo "Error: invalid SYNC_TAGS '$SYNC_TAGS' (expected: true | false)" >&2
    exit 1
    ;;
esac

redact_url() {
  printf '%s' "$1" | sed 's|://[^/@]*@|://***@|g'
}

expand_repo_url() {
  repo="$1"
  use_ssh="$2"

  # Leave local paths, file:// URLs, full URLs, SCP-style SSH URLs, and .git URLs untouched
  case "$repo" in
    /*|./*|../*|file://*|*://*|*@*|[A-Za-z]:/*|[A-Za-z]:\\*|*.git|*.git/)
      printf '%s' "$repo"
      return 0
      ;;
  esac

  if [ "$use_ssh" = "true" ]; then
    printf 'git@github.com:%s.git' "$repo"
  else
    printf 'https://github.com/%s.git' "$repo"
  fi
}

build_ssh_command() {
  key_file="$1"
  cmd="ssh -o BatchMode=yes -o StrictHostKeyChecking=${STRICT_HOST_KEY_CHECKING}"

  if [ -f "${SSH_DIR}/known_hosts" ]; then
    cmd="${cmd} -o UserKnownHostsFile=${SSH_DIR}/known_hosts"
  fi

  if [ -n "$key_file" ] && [ -f "$key_file" ]; then
    cmd="${cmd} -o IdentitiesOnly=yes -i ${key_file}"
  fi

  printf '%s' "$cmd"
}

SOURCE_KEY=""
if [ -f "${SSH_DIR}/source_key" ]; then
  SOURCE_KEY="${SSH_DIR}/source_key"
elif [ -f "${SSH_DIR}/shared_key" ]; then
  SOURCE_KEY="${SSH_DIR}/shared_key"
fi

DEST_KEY=""
if [ -f "${SSH_DIR}/destination_key" ]; then
  DEST_KEY="${SSH_DIR}/destination_key"
elif [ -f "${SSH_DIR}/shared_key" ]; then
  DEST_KEY="${SSH_DIR}/shared_key"
fi

USE_SOURCE_SSH="false"
if [ -n "$SOURCE_KEY" ] || [ -n "${SSH_PRIVATE_KEY:-}${SOURCE_SSH_PRIVATE_KEY:-}" ]; then
  USE_SOURCE_SSH="true"
fi

USE_DEST_SSH="false"
if [ -n "$DEST_KEY" ] || [ -n "${SSH_PRIVATE_KEY:-}${DESTINATION_SSH_PRIVATE_KEY:-}" ]; then
  USE_DEST_SSH="true"
fi

SOURCE_REPO="$(expand_repo_url "$SOURCE_REPO" "$USE_SOURCE_SSH")"
DESTINATION_REPO="$(expand_repo_url "$DESTINATION_REPO" "$USE_DEST_SSH")"

SAFE_SOURCE_LOG="$(redact_url "$SOURCE_REPO")"
SAFE_DEST_LOG="$(redact_url "$DESTINATION_REPO")"

echo "SOURCE=${SAFE_SOURCE_LOG} (${SOURCE_BRANCH})"
echo "DESTINATION=${SAFE_DEST_LOG} (${DESTINATION_BRANCH})"
echo "MODE=push_mode:${PUSH_MODE} dry_run:${DRY_RUN} prune:${PRUNE} sync_tags:${SYNC_TAGS}"

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

SOURCE_SSH_CMD="$(build_ssh_command "$SOURCE_KEY")"
DEST_SSH_CMD="$(build_ssh_command "$DEST_KEY")"

git -c "core.sshCommand=${SOURCE_SSH_CMD}" clone "$SOURCE_REPO" "${WORK_DIR}/repo" --origin source
cd "${WORK_DIR}/repo"

git remote add destination "$DESTINATION_REPO"

# Fetch all source heads and tags so local refs, refs/remotes/source/*, and refs/tags/* all resolve
git -c "core.sshCommand=${SOURCE_SSH_CMD}" fetch source '+refs/heads/*:refs/heads/*' --tags --update-head-ok

git --no-pager branch -a -vv

git config --local core.sshCommand "$DEST_SSH_CMD"

# Fetch destination refs when using force-with-lease so Git has an expected ref state
if [ "$PUSH_MODE" = "force-with-lease" ]; then
  git fetch destination || true
fi

# Build push arguments safely via positional parameters
set -- push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}"

case "$PUSH_MODE" in
  force)
    set -- "$@" --force
    ;;
  force-with-lease)
    set -- "$@" --force-with-lease
    ;;
  fast-forward)
    ;;
esac

if [ "$PRUNE" = "true" ]; then
  set -- "$@" --prune
fi

if [ "$DRY_RUN" = "true" ]; then
  set -- "$@" --dry-run
fi

git "$@"

if [ "$SYNC_TAGS" = "true" ]; then
  set -- push destination 'refs/tags/*:refs/tags/*'
  case "$PUSH_MODE" in
    force)
      set -- "$@" --force
      ;;
    force-with-lease)
      set -- "$@" --force-with-lease
      ;;
    fast-forward)
      ;;
  esac
  if [ "$DRY_RUN" = "true" ]; then
    set -- "$@" --dry-run
  fi
  git "$@"
fi
