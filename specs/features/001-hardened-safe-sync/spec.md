# Feature 001: Hardened & Safe Git Sync (`v4.0`)

## Problem Statement

The inherited fork of `wei/git-sync` (`v3`) contains critical security and reliability defects:
1. Command injection via `sh -c "/git-sync.sh $*"` in `entrypoint.sh`.
2. Global MITM exposure via `StrictHostKeyChecking no` in `Dockerfile`.
3. Unpinned floating `FROM alpine` base image and stale upstream metadata.
4. Non-POSIX bashisms (`[[ ... ]]`) under `#!/bin/sh`, dead non-exported `GIT_SSH_COMMAND`, and brittle `sed` newline parsing.
5. Unconditional destructive `git push -f` with no `dry_run`, `force-with-lease`, or `fast-forward` safety modes, plus credential leakage if authenticated HTTPS URLs are echoed in logs.
6. Missing repository governance (`LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, automated tests, CI).

## User Stories

- **US-1 (Safe Mirroring):** As a DevOps engineer, I want to mirror branches or tags between two independent Git repositories with `dry_run: true` and `push_mode: force-with-lease` or `fast-forward` so I never accidentally overwrite divergent work.
- **US-2 (Zero Injection & MITM Protection):** As a security reviewer, I want branch names, repo URLs, and SSH keys handled with strict POSIX quoting and verified `known_hosts` so workflows cannot be hijacked.
- **US-3 (Modern SSH Keys & Clean Logs):** As a developer using `ed25519` deploy keys or HTTPS PAT URLs, I want keys loaded reliably and credentials redacted from stdout logs.
- **US-4 (v3 Compatibility):** As an existing user of `git-sync@v3`, I want my existing 4 positional arguments and SSH key env vars to keep working seamlessly.

## Acceptance Criteria (`GIVEN / WHEN / THEN`)

- **AC-1 (Command Injection Resistance):**
  - `GIVEN` a branch name or repo argument containing shell metacharacters (e.g., `main;touch /tmp/pwned` or `$(id)`),
  - `WHEN` `entrypoint.sh` invokes `git-sync.sh`,
  - `THEN` no shell command is executed and the value is treated purely as a literal string argument.
- **AC-2 (Credential Redaction):**
  - `GIVEN` an HTTPS URL containing embedded credentials (`https://user:ghp_secret@github.com/org/repo.git`),
  - `WHEN` `git-sync.sh` logs source and destination targets,
  - `THEN` stdout prints `https://***@github.com/org/repo.git` and NEVER exposes the token.
- **AC-3 (Safe Push Modes):**
  - `GIVEN` a destination branch that has diverged from source,
  - `WHEN` `PUSH_MODE=fast-forward` is set,
  - `THEN` the push fails cleanly with a non-zero exit code without overwriting destination commits.
  - `WHEN` `PUSH_MODE=force` is set (default for v3 compatibility),
  - `THEN` the destination branch is force-updated to match source.
- **AC-4 (Dry Run Mode):**
  - `GIVEN` `DRY_RUN=true`,
  - `WHEN` `git-sync.sh` runs against two bare repositories,
  - `THEN` `git push --dry-run` validates connectivity and refspecs without modifying any refs on the destination repository.
- **AC-5 (Shorthand & Tag Sync):**
  - `GIVEN` shorthand slugs (`org/repo`) or `SYNC_TAGS=true` or `PRUNE=true`,
  - `WHEN` `git-sync.sh` runs,
  - `THEN` shorthand expands to GitHub SSH (when SSH key provided) or HTTPS (otherwise), and optional tags/pruning execute cleanly.
- **AC-6 (Temp Directory Cleanup):**
  - `GIVEN` any successful or failed sync execution,
  - `WHEN` `git-sync.sh` exits,
  - `THEN` the temporary working directory created by `mktemp -d` is removed.
