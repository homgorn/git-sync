# Fork Sync vs Git Sync — Choosing the Right Tool

## When to Use `homgorn/git-sync`
- Mirroring between **two independent repositories** (not GitHub forks of each other).
- Cross-forge mirroring (**GitHub ↔ GitLab ↔ Bitbucket ↔ Codeberg ↔ Gitea**).
- Syncing a specific branch or tag set into a release/mirror repository.

## When NOT to Use `homgorn/git-sync` (Syncing GitHub Forks)
If you maintain dozens or hundreds of GitHub forks and want to keep them up to date with their upstream repositories, **do not clone and force-push them**.

Instead, use GitHub's native server-side API:

```sh
gh api --method POST repos/<owner>/<fork-name>/merge-upstream -f branch=main
```

| Criterion | `git-sync` (Clone + Push) | GitHub `merge-upstream` API |
| :--- | :--- | :--- |
| Bandwidth for 1 000 forks | Tens of GB cloned & pushed | **0 MB** (server-side on GitHub) |
| Auth needed | Deploy keys per repo or broad SSH key | Standard `GITHUB_TOKEN` / `gh` CLI |
| Diverged fork safety | Can overwrite local commits if `force` | Returns `409 Conflict` safely without data loss |
| Speed for 1 000 forks | Hours | Minutes (throttled in safe chunks) |
