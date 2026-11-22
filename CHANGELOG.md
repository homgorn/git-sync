# Changelog

All notable changes to this project are documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [4.0.0] - 2026-11-22

### Security
- **Fixed command injection** in `entrypoint.sh` (`sh -c "/git-sync.sh $*"` replaced with `exec "$GIT_SYNC_SCRIPT" "$@"`).
- **Removed global `StrictHostKeyChecking no`** from `Dockerfile`; pre-baked `known_hosts` for GitHub, GitLab, Bitbucket, and Codeberg plus optional `ssh_known_hosts` input.
- **Redacted embedded HTTPS credentials** from log output (`https://***@...`).
- **Pinned Docker base image** to `alpine:3.21` and installed `ca-certificates`.

### Added
- **Spec-Driven Development (SDD)** foundation (`specs/constitution.md`, `specs/features/001-hardened-safe-sync/`).
- Safe push modes via `push_mode` (`force` | `force-with-lease` | `fast-forward`), `dry_run`, `prune`, and `sync_tags`.
- Full support for `ed25519`, `ecdsa`, and `rsa` SSH keys via isolated `umask 077` files and `IdentitiesOnly=yes`.
- Isolated temporary working directory (`mktemp -d`) with `EXIT` trap cleanup.
- Offline integration test suite (`tests/test_git_sync.py`) and GitHub Actions CI (`shellcheck`, `hadolint`, integration tests, Docker build check).
- Repository governance (`LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, Issue Templates, `docs/`, `docs/wiki/`).

### Changed
- Rewrote `entrypoint.sh` and `git-sync.sh` as strict POSIX `/bin/sh` (removed bashisms and dead non-exported `GIT_SSH_COMMAND`).
- Rewrote `README.md` for humans with clear safety warnings and a guide on when to use GitHub's native `merge-upstream` fork sync API instead.

## [3.x] - Upstream `wei/git-sync`
- Original force-push Docker GitHub Action by Wei He.
