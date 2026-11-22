# Production Sync Recipes

## 1. Safe Fast-Forward Mirror (Never Overwrites History)
```yaml
- uses: homgorn/git-sync@master
  with:
    source_repo: "org/upstream-mirror"
    source_branch: "main"
    destination_repo: "org/downstream-repo"
    destination_branch: "main"
    ssh_private_key: ${{ secrets.DEPLOY_KEY }}
    push_mode: "fast-forward"
```

## 2. GitHub → GitLab / Codeberg Mirror (With Tags & Prune)
```yaml
- uses: homgorn/git-sync@master
  with:
    source_repo: "homgorn/my-project"
    source_branch: "refs/remotes/source/*"
    destination_repo: "git@codeberg.org:homgorn/my-project.git"
    destination_branch: "refs/heads/*"
    destination_ssh_private_key: ${{ secrets.CODEBERG_DEPLOY_KEY }}
    push_mode: "force-with-lease"
    prune: "true"
    sync_tags: "true"
```

## 3. Self-Hosted Git Server (Custom `known_hosts`)
```yaml
- uses: homgorn/git-sync@master
  with:
    source_repo: "git@git.internal.company:team/app.git"
    source_branch: "main"
    destination_repo: "org/public-mirror"
    destination_branch: "main"
    source_ssh_private_key: ${{ secrets.INTERNAL_KEY }}
    destination_ssh_private_key: ${{ secrets.GITHUB_KEY }}
    ssh_known_hosts: ${{ secrets.INTERNAL_KNOWN_HOSTS }}
    strict_host_key_checking: "yes"
```
Generate `INTERNAL_KNOWN_HOSTS` once via:
```sh
ssh-keyscan -t ed25519 git.internal.company
```
