# Security & Reliability Audit (`v3` → `v4`)

Audit of the inherited `wei/git-sync@v3` codebase and exact remediations shipped in `homgorn/git-sync@v4.0.0`.

| # | Severity | Original Defect (`v3`) | Impact | Remediation (`v4`) |
| :---: | :---: | :--- | :--- | :--- |
| 1 | **Critical** | `sh -c "/git-sync.sh $*"` in `entrypoint.sh` | Arbitrary command injection via branch/repo inputs | Replaced with `exec "$GIT_SYNC_SCRIPT" "$@"` (tested in `test_command_injection_resistance`) |
| 2 | **High** | `StrictHostKeyChecking no` in `Dockerfile` | Man-in-the-middle (MITM) credential/code interception | Removed; baked `known_hosts` via `ssh-keyscan` + `ssh_known_hosts` input + `STRICT_HOST_KEY_CHECKING=yes` |
| 3 | **High** | `echo "SOURCE=$SOURCE_REPO..."` unredacted | Leaks embedded HTTPS PATs (`https://user:token@...`) in CI logs | Added `redact_url()` masking credentials as `https://***@...` |
| 4 | **Medium** | Floating `FROM alpine` + stale labels | Non-reproducible supply chain builds | Pinned `FROM alpine:3.21`, added `ca-certificates` and OCI labels |
| 5 | **Medium** | Bashisms (`[[ ... ]]`) under `#!/bin/sh`, unexported dead `GIT_SSH_COMMAND="ssh -v"`, hardcoded `id_rsa` | Portability failures, dead code, RSA-only key naming | Strict POSIX `/bin/sh`, `set -eu`, ShellCheck clean, key-type agnostic (`shared_key` / `source_key` / `destination_key`) |
| 6 | **Medium** | Unconditional `git push -f`, fixed `/root/source`, no `LICENSE` file | Accidental history destruction, leftover artifacts, ambiguous OSS rights | Added `push_mode` (`fast-forward` / `force-with-lease` / `force`), `dry_run`, `prune`, `sync_tags`, `mktemp -d` trap cleanup, `LICENSE` (MIT) |
