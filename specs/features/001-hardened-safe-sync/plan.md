# Technical Plan — Feature 001: Hardened & Safe Git Sync (`v4.0`)

## Architecture Overview

```text
GitHub Action (action.yml) / Docker CLI
        │
        ▼
  entrypoint.sh (POSIX /bin/sh, set -eu)
   ├─ Materializes SSH keys safely (umask 077, printf '%b\n')
   ├─ Populates known_hosts (custom KNOWN_HOSTS + baked forge keys)
   └─ exec /git-sync.sh "$@"   (ZERO shell interpolation!)
        │
        ▼
  git-sync.sh (POSIX /bin/sh, set -eu)
   ├─ Validates inputs & expands GitHub shorthand slugs
   ├─ Redacts embedded HTTPS credentials before logging
   ├─ Creates isolated temp dir + EXIT trap cleanup
   ├─ Clones source (--bare or clean working repo) with optional source SSH key
   ├─ Fetches refs & computes push flags (fast-forward / force-with-lease / force, --dry-run, --prune)
   └─ Pushes refs (+ optional tags) using optional destination SSH key
```

## Input & Environment Contract (`action.yml`)

| Input | Env Var | Default | Description |
| :--- | :--- | :--- | :--- |
| `source_repo` | `$1` | *(required)* | Source repo slug (`owner/repo`), SSH, HTTPS, or local path |
| `source_branch` | `$2` | *(required)* | Source branch or refspec (e.g., `main`, `refs/remotes/source/*`) |
| `destination_repo` | `$3` | *(required)* | Destination repo slug, SSH, HTTPS, or local path |
| `destination_branch` | `$4` | *(required)* | Destination branch or refspec |
| `ssh_private_key` | `SSH_PRIVATE_KEY` | `""` | Shared SSH private key (ed25519/rsa/ecdsa) |
| `source_ssh_private_key` | `SOURCE_SSH_PRIVATE_KEY` | `""` | Source-specific SSH private key (overrides shared key) |
| `destination_ssh_private_key` | `DESTINATION_SSH_PRIVATE_KEY` | `""` | Destination-specific SSH private key (overrides shared key) |
| `ssh_known_hosts` | `SSH_KNOWN_HOSTS` | `""` | Optional extra `known_hosts` entries for self-hosted Git servers |
| `strict_host_key_checking` | `STRICT_HOST_KEY_CHECKING` | `yes` | `yes` (recommended, verifies against known_hosts) or `accept-new` |
| `push_mode` | `PUSH_MODE` | `force` | `force` (v3 compat), `force-with-lease`, or `fast-forward` |
| `dry_run` | `DRY_RUN` | `false` | `true` to validate without pushing changes |
| `prune` | `PRUNE` | `false` | `true` to prune deleted refs when syncing refspecs |
| `sync_tags` | `SYNC_TAGS` | `false` | `true` to also push tags to destination |

## Security Controls

1. **Docker Base Image:** Pin `FROM alpine:3.21` and install `git`, `openssh-client`, `ca-certificates`. Bake verified `known_hosts` fingerprints for `github.com`, `gitlab.com`, `bitbucket.org`, `codeberg.org` at build time via `ssh-keyscan`.
2. **SSH Key Materialization:** Use `umask 077` before creating `~/.ssh`, normalize escaped `\n` newlines safely without corrupting multi-line keys, and pass explicit `-i` + `-o IdentitiesOnly=yes` + `-o StrictHostKeyChecking=<mode>` via `GIT_SSH_COMMAND` (properly exported or passed per `git -c core.sshCommand=...`).
3. **URL Redaction Helper:** `redact_url()` strips `://[^/@]+@` to `://***@` before printing any URL to stdout/stderr.
4. **Local Path Support for Testing:** Treat paths starting with `/`, `./`, `../`, or `file://` as raw Git URLs (do NOT expand them as GitHub shorthand), enabling fast offline integration tests using local bare repos.

## Verification Strategy

- Automated Python test suite (`tests/test_git_sync.py`) invoking `/bin/sh` (`sh.exe` on Windows or `/bin/sh` on Linux CI) against real temporary bare Git repositories:
  1. Fast-forward sync happy path
  2. Divergent branch rejection in `fast-forward` mode
  3. Divergent branch update in `force` mode and safe lease in `force-with-lease` mode
  4. `dry_run=true` leaves destination untouched
  5. `sync_tags=true` transfers annotated & lightweight tags
  6. Credential redaction test (ensures token never appears in stdout/stderr)
  7. Command injection test (metacharacters in branch/repo args do not execute)
  8. GitHub shorthand expansion logic check (SSH vs HTTPS)
- GitHub Actions CI (`.github/workflows/ci.yml`): runs `shellcheck`, `hadolint`, `pytest` / `unittest`, Docker build verification, and SDD file presence gate.
