# Architecture — `homgorn/git-sync`

## Execution Flow

```mermaid
flowchart TD
    A["GitHub Action / Docker CLI"] --> B["entrypoint.sh\n(POSIX /bin/sh, set -eu)"]
    B --> C["SSH Materializer\n- umask 077, chmod 600\n- shared / source / dest keys\n- baked + custom known_hosts"]
    C --> D["exec git-sync.sh '$@'\n(zero shell re-evaluation)"]
    D --> E["Input Validation & URL Expansion\n- redact credentials before logging\n- validate push_mode / dry_run / prune"]
    E --> F["Isolated Temp Dir (mktemp -d)\n+ EXIT trap cleanup"]
    F --> G["Clone Source + Fetch All Refs & Tags"]
    G --> H{"push_mode?"}
    H -->|fast-forward| I["git push (non-destructive)"]
    H -->|force-with-lease| J["git fetch destination\n+ git push --force-with-lease"]
    H -->|force| K["git push --force"]
    I & J & K --> L["Optional: sync_tags (--tags) & --dry-run / --prune"]
    L --> M["EXIT trap removes temp dir"]
```

## Design Principles

1. **Zero external runtime dependencies beyond `git` and `openssh-client`:** Small Alpine `3.21` footprint, fast cold-start in GitHub Actions.
2. **Strict POSIX `/bin/sh`:** Works identically in BusyBox `ash` (Alpine), `dash` (Debian/Ubuntu), and Git Bash (Windows CI/dev).
3. **Defense in depth:**
   - Positional argument forwarding (`exec ... "$@"`) eliminates command injection.
   - `IdentitiesOnly=yes` prevents SSH agent/default key cross-contamination between source and destination.
   - `BatchMode=yes` guarantees non-interactive fast failure instead of hanging CI runners on passphrase prompts.
   - `redact_url()` prevents HTTPS PAT leakage in runner logs.
