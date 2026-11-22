# Constitution — `homgorn/git-sync`

This document defines the non-negotiable engineering, security, and maintainability rules for this repository. Every specification, plan, pull request, and AI agent change MUST comply with these invariants.

## 1. Security Invariants (Zero Compromise)

1. **No Command Injection:** Never pass user-controlled arguments through `sh -c`, `eval`, or unquoted word-splitting expansions. Always use `exec /git-sync.sh "$@"` and quote every shell variable (`"$VAR"`).
2. **Strict Host Key Verification:** Never disable SSH host key checking globally (`StrictHostKeyChecking no` is forbidden). Pre-populate `known_hosts` for major Git forges (`github.com`, `gitlab.com`, `bitbucket.org`, `codeberg.org`) and allow custom `known_hosts` input, falling back at most to `accept-new` only when explicitly opted in.
3. **Zero Secret Leakage:** Never print, echo, or log private keys, Personal Access Tokens (PATs), authenticated HTTPS URLs with embedded credentials, or verbose SSH dumps (`ssh -v`) by default. Redact credentials from URLs before logging.
4. **Pinned Supply Chain:** Base Docker images MUST be pinned to an explicit major.minor tag (e.g., `alpine:3.21`), never floating `alpine` / `latest`. GitHub Actions in CI MUST be pinned to full commit SHAs or verified major versions.
5. **Key Format Agnostic:** Support modern `ed25519`, `ecdsa`, and legacy `rsa` SSH private keys without hardcoding RSA-only assumptions.

## 2. Shell & Runtime Standards

1. **Strict POSIX `/bin/sh`:** All scripts targeting Alpine's `/bin/sh` MUST be strictly POSIX-compliant (zero bashisms like `[[ ... ]]` or `source`), use `set -eu`, and pass `shellcheck` with zero warnings.
2. **LF Line Endings:** All `.sh` scripts and `Dockerfile` MUST use LF (`\n`) line endings enforced via `.gitattributes`.
3. **Clean Workspace & Trap Cleanup:** Always clone into an isolated temporary directory (`mktemp -d`) and clean it up via `trap` on exit — never pollute `/root/source` or leave leftover credentials.

## 3. Backward Compatibility & Safety Defaults

1. **v3 Input Compatibility:** Existing inputs (`source_repo`, `source_branch`, `destination_repo`, `destination_branch`, `ssh_private_key`, `source_ssh_private_key`, `destination_ssh_private_key`) MUST continue working without breaking existing workflows.
2. **Explicit Safety Controls:** Provide `push_mode` (`force` for v3 backward compatibility, `force-with-lease`, `fast-forward`), `dry_run` (`false` | `true`), `prune` (`false` | `true`), and `sync_tags` (`false` | `true`).
3. **Scope Discipline:** This repository is a focused, hardened Git mirror/sync tool. Do NOT bloat it with unrelated portfolio databases, fork-farm scripts, or web apps — for syncing GitHub forks with upstream, document and recommend GitHub's native `merge-upstream` API.

## 4. Verification & Spec-Driven Discipline

1. **Spec Before Code:** Every behavioral change starts in `specs/features/<id>-<slug>/{spec.md,plan.md,tasks.md}`.
2. **Automated Proof:** Every change MUST pass automated integration tests (real local bare Git repositories), `shellcheck`, and `hadolint` in CI.
