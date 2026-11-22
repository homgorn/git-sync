# Contributing to `homgorn/git-sync`

This repository follows **Spec-Driven Development (SDD)**.

## Workflow

1. Read [`specs/constitution.md`](specs/constitution.md) first — all PRs must respect every security and POSIX invariant.
2. For any new feature or behavioral change, add or update a spec under `specs/features/<nnn>-<name>/{spec.md,plan.md,tasks.md}` **before** editing code.
3. Keep all shell scripts strictly POSIX `/bin/sh` (`set -eu`, LF line endings, zero ShellCheck warnings).
4. Add or update integration tests in `tests/test_git_sync.py`.
5. Run checks locally:
   ```sh
   python -m unittest discover -s tests -v
   ```
6. Open a Pull Request referencing the spec and checklist items.
