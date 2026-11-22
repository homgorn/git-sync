# Task Checklist — Feature 001: Hardened & Safe Git Sync (`v4.0`)

- [x] **T-01:** Establish SDD foundation (`specs/constitution.md`, `spec.md`, `plan.md`, `tasks.md`).
- [x] **T-02:** Add repository hygiene & line-ending enforcement (`.gitattributes`, `.gitignore`, `.dockerignore`, `.editorconfig`).
- [x] **T-03:** Harden `entrypoint.sh` (strict POSIX `/bin/sh`, `exec /git-sync.sh "$@"`, safe SSH key & `known_hosts` setup).
- [x] **T-04:** Rewrite `git-sync.sh` (strict POSIX `/bin/sh`, credential redaction, `push_mode`, `dry_run`, `prune`, `sync_tags`, `mktemp -d` cleanup trap, local path support).
- [x] **T-05:** Harden `Dockerfile` (pinned `alpine:3.21`, OCI labels, `known_hosts` via `ssh-keyscan`, remove `StrictHostKeyChecking no`).
- [x] **T-06:** Update `action.yml` with v4 inputs while keeping full v3 backward compatibility.
- [x] **T-07:** Add standard OSS governance files (`LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, GitHub Issue Templates).
- [x] **T-08:** Add CI workflow (`.github/workflows/ci.yml`: ShellCheck, Hadolint, integration tests, Docker build check).
- [x] **T-09:** Write human-first `README.md` + `docs/architecture.md` + `docs/security-audit.md` + `docs/wiki/` source pages.
- [x] **T-10:** Write & run automated integration test suite (`tests/test_git_sync.py`) and verify 100% pass locally.
- [x] **T-11:** Commit cleanly, push to `homgorn/git-sync`, and configure GitHub repo metadata (Description, Homepage `https://refertur.net`, Topics including `refertur-net`, enable Issues & Wiki).
