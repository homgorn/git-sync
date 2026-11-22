# Security Policy

## Supported Versions

| Version | Supported | Notes |
| :--- | :---: | :--- |
| `v4.x` (`master`) | Yes | Hardened SDD release (command-injection fix, pinned Alpine, `known_hosts`, safe push modes) |
| `v3.x` (upstream `wei/git-sync`) | No | Unmaintained upstream with command injection and `StrictHostKeyChecking no` |

## Security Best Practices When Using This Action

1. **Pin by full commit SHA**, not mutable tags:
   ```yaml
   uses: homgorn/git-sync@<full-40-char-commit-sha>
   ```
2. **Use `ed25519` deploy keys** with least privilege (read-only on source, write on destination).
3. **Prefer `push_mode: fast-forward` or `force-with-lease`** unless you intentionally want a destructive mirror (`force`).
4. **Always test new workflows with `dry_run: true`** first.
5. **Never hardcode PATs in workflow YAML** — pass them via `${{ secrets.* }}`. Even though `git-sync` redacts `https://user:token@...` in its own log output, GitHub Actions runner masks secrets only when stored in Secrets.

## Reporting a Vulnerability

Please report security vulnerabilities privately via email to **refertur.net@gmail.com** or via GitHub Private Vulnerability Reporting rather than opening a public issue. We aim to acknowledge reports within 48 hours.
