# Git Sync (`v4` — Hardened SDD Edition)

[![CI](https://github.com/homgorn/git-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/homgorn/git-sync/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Spec-Driven](https://img.shields.io/badge/Methodology-SDD-brightgreen.svg)](specs/constitution.md)
[![Part of refertur.net](https://img.shields.io/badge/Ecosystem-refertur.net-orange.svg)](https://refertur.net)

**Mirror branches and tags between two independent Git repositories** (GitHub, GitLab, Bitbucket, Codeberg, or self-hosted Git) — hardened against command injection, MITM attacks, and accidental force-push disasters.

> **Important: Syncing GitHub Forks?**
> Do **not** use a clone-and-push action to sync GitHub forks with their upstream! GitHub provides a native server-side endpoint (`POST /repos/{owner}/{repo}/merge-upstream`) that syncs forks in 1 API call with zero bandwidth. Use `git-sync` when syncing **two independent repositories** or mirroring across different Git hosts. See [Fork Sync vs Git Sync](docs/wiki/Fork-Sync-vs-Git-Sync.md).

---

## Why `v4`? (What Changed from `wei/git-sync@v3`)

The original `wei/git-sync` has been unmaintained for years and carries serious CI/CD security issues. This hardened edition fixes all of them while staying **100% backward-compatible** with `v3` inputs:

| Area | Legacy `v3` | Hardened `v4` |
| :--- | :--- | :--- |
| **Command execution** | `sh -c "/git-sync.sh $*"` (command injection risk) | `exec "$GIT_SYNC_SCRIPT" "$@"` (zero shell interpolation) |
| **SSH host verification** | `StrictHostKeyChecking no` (MITM vulnerable) | Pre-baked `known_hosts` + custom `ssh_known_hosts` input |
| **Push safety** | Unconditional `git push -f` only | `push_mode`: `fast-forward`, `force-with-lease`, or `force` + `dry_run` |
| **Secrets in logs** | Echoed full authenticated HTTPS URLs | Automatic credential redaction (`https://***@...`) |
| **SSH keys** | Hardcoded `id_rsa` + brittle `sed` | Works with `ed25519`, `ecdsa`, `rsa` (`umask 077`, `IdentitiesOnly=yes`) |
| **Docker & Shell** | Floating `FROM alpine`, bashisms in `/bin/sh` | Pinned `alpine:3.21`, strict POSIX `/bin/sh`, ShellCheck + Hadolint + tests |

Full technical audit: [docs/security-audit.md](docs/security-audit.md).

---

## Quick Start (30 Seconds)

Always test a new sync pipeline with `dry_run: true` and `push_mode: fast-forward` (or `force-with-lease`) first.

```yaml
# .github/workflows/git-sync.yml
name: Mirror Repository

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 3 * * 1' # Weekly on Monday 03:00 UTC
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Sync to mirror
        uses: homgorn/git-sync@master # Pin to a full commit SHA in production!
        with:
          source_repo: "source-org/source-repo"
          source_branch: "main"
          destination_repo: "git@gitlab.com:dest-org/dest-repo.git"
          destination_branch: "main"
          destination_ssh_private_key: ${{ secrets.DEST_DEPLOY_KEY }}
          push_mode: "force-with-lease"
          sync_tags: "true"
          dry_run: "false"
```

---

## Inputs Reference

| Input | Required | Default | Description |
| :--- | :---: | :---: | :--- |
| `source_repo` | Yes | — | Source GitHub slug (`owner/repo`) or full SSH/HTTPS URL |
| `source_branch` | Yes | — | Source branch or refspec (`main`, `refs/remotes/source/*`, `refs/tags/*`) |
| `destination_repo` | Yes | — | Destination GitHub slug (`owner/repo`) or full SSH/HTTPS URL |
| `destination_branch` | Yes | — | Destination branch or refspec (`main`, `refs/heads/*`, `refs/tags/*`) |
| `ssh_private_key` | No | `""` | Shared SSH private key (`ed25519`/`ecdsa`/`rsa`) for both repos |
| `source_ssh_private_key` | No | `""` | Source-only SSH key (overrides `ssh_private_key`) |
| `destination_ssh_private_key` | No | `""` | Destination-only SSH key (overrides `ssh_private_key`) |
| `ssh_known_hosts` | No | `""` | Extra `known_hosts` lines for self-hosted Git servers |
| `strict_host_key_checking` | No | `yes` | `yes` (verify against `known_hosts`) or `accept-new` |
| `push_mode` | No | `force` | `fast-forward` (safest), `force-with-lease`, or `force` (v3 compat) |
| `dry_run` | No | `false` | `true` runs `git push --dry-run` without changing destination |
| `prune` | No | `false` | `true` removes destination refs deleted in source |
| `sync_tags` | No | `false` | `true` also pushes all tags (`refs/tags/*`) |

---

## Common Recipes

### Sync All Branches & Tags Safely (Dry-Run First)
```yaml
with:
  source_repo: "source-org/repo"
  source_branch: "refs/remotes/source/*"
  destination_repo: "dest-org/repo"
  destination_branch: "refs/heads/*"
  push_mode: "force-with-lease"
  prune: "true"
  sync_tags: "true"
  dry_run: "true" # Flip to "false" after verifying logs
```

### Generate Modern `ed25519` Deploy Keys
```sh
ssh-keygen -t ed25519 -C "git-sync-deploy-key" -f ./git_sync_key -N ""
```
1. Add `git_sync_key.pub` to destination repo → **Settings → Deploy keys** (check **Allow write access**).
2. Add `git_sync_key` (private key) to workflow repo → **Settings → Secrets → Actions** as `DESTINATION_SSH_PRIVATE_KEY`.

### Run Locally via Docker
```sh
docker build -t git-sync:local .
docker run --rm \
  -e "PUSH_MODE=fast-forward" \
  -e "DRY_RUN=true" \
  -e "SSH_PRIVATE_KEY=$(cat ~/.ssh/id_ed25519)" \
  git-sync:local \
  "source-org/repo" "main" "dest-org/repo" "main"
```

More recipes (GitLab, Codeberg, self-hosted Gitea): [docs/wiki/Recipes.md](docs/wiki/Recipes.md).

---

## Spec-Driven Development (SDD) Structure

This repository is maintained via Spec-Driven Development — intent is versioned before code:

```text
├── specs/
│   ├── constitution.md                       # Non-negotiable security & POSIX invariants
│   └── features/001-hardened-safe-sync/      # Spec, technical plan, traceable tasks
├── docs/
│   ├── architecture.md                       # Execution flow & security model
│   ├── security-audit.md                     # v3 → v4 vulnerability remediation report
│   └── wiki/                                 # Syncable GitHub Wiki documentation
├── tests/test_git_sync.py                    # Real bare-repo integration tests
├── entrypoint.sh & git-sync.sh               # Strict POSIX /bin/sh runtime
├── Dockerfile & action.yml                   # Pinned Alpine container & Action contract
└── .github/workflows/ci.yml                  # ShellCheck + Hadolint + Tests + Docker
```

Run the offline integration test suite locally:
```sh
python -m unittest discover -s tests -v
```

---

## Security & Attribution

- See [SECURITY.md](SECURITY.md) for SHA-pinning guidelines and vulnerability reporting.
- See [CHANGELOG.md](CHANGELOG.md) for release history.
- Original `v3` Action created by [Wei He](https://github.com/wei). Hardened `v4` SDD edition maintained by **Leinid D** ([homgorn](https://github.com/homgorn) / [refertur.net](https://refertur.net)).
- Licensed under the [MIT License](LICENSE).
