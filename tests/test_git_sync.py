import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ENTRYPOINT = REPO_ROOT / "entrypoint.sh"
GIT_SYNC = REPO_ROOT / "git-sync.sh"


def find_posix_sh() -> str:
    """Locate a POSIX sh executable (works on Linux, macOS, and Windows Git Bash)."""
    candidates = [
        shutil.which("sh"),
        r"C:\Program Files\Git\bin\sh.exe",
        r"C:\Program Files\Git\usr\bin\sh.exe",
        "/bin/sh",
    ]
    for c in candidates:
        if c and Path(c).exists():
            return c
    raise RuntimeError("No POSIX sh found (install Git for Windows or run on Linux/macOS).")


def to_posix_path(path: Path) -> str:
    s = str(path.resolve())
    if os.name == "nt" and len(s) >= 2 and s[1] == ":":
        drive = s[0].lower()
        rest = s[2:].replace("\\", "/")
        return f"/{drive}{rest}"
    return s.replace("\\", "/")


def run_git(cwd: Path, *args: str) -> str:
    res = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=True,
    )
    return res.stdout.strip()


class TestGitSyncHardened(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sh = find_posix_sh()

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="git_sync_test_"))
        self.src_bare = self.tmp / "source.git"
        self.dst_bare = self.tmp / "dest.git"
        self.work_src = self.tmp / "work_src"
        self.work_dst = self.tmp / "work_dst"
        self.ssh_dir = self.tmp / "ssh"

        run_git(self.tmp, "init", "--bare", "-b", "main", str(self.src_bare))
        run_git(self.tmp, "init", "--bare", "-b", "main", str(self.dst_bare))

        # Seed source repo with commit 1 + tag v1.0.0
        run_git(self.tmp, "clone", str(self.src_bare), str(self.work_src))
        run_git(self.work_src, "config", "user.email", "test@refertur.net")
        run_git(self.work_src, "config", "user.name", "Test Bot")
        (self.work_src / "README.md").write_text("commit 1\n", encoding="utf-8")
        run_git(self.work_src, "add", ".")
        run_git(self.work_src, "commit", "-m", "initial commit")
        run_git(self.work_src, "tag", "v1.0.0")
        run_git(self.work_src, "push", "origin", "main", "--tags")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_sync(self, src_repo, src_branch, dst_repo, dst_branch, extra_env=None):
        env = os.environ.copy()
        env["GIT_SYNC_SCRIPT"] = to_posix_path(GIT_SYNC)
        env["SSH_DIR"] = to_posix_path(self.ssh_dir)
        # Clear any ambient SSH key env vars
        for k in ("SSH_PRIVATE_KEY", "SOURCE_SSH_PRIVATE_KEY", "DESTINATION_SSH_PRIVATE_KEY", "SSH_KNOWN_HOSTS"):
            env.pop(k, None)
        if extra_env:
            env.update(extra_env)

        return subprocess.run(
            [self.sh, to_posix_path(ENTRYPOINT), src_repo, src_branch, dst_repo, dst_branch],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_01_fast_forward_sync_and_tags(self) -> None:
        res = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {"PUSH_MODE": "fast-forward", "SYNC_TAGS": "true"},
        )
        self.assertEqual(res.returncode, 0, msg=f"STDOUT:\n{res.stdout}\nSTDERR:\n{res.stderr}")
        src_sha = run_git(self.src_bare, "rev-parse", "refs/heads/main")
        dst_sha = run_git(self.dst_bare, "rev-parse", "refs/heads/main")
        self.assertEqual(src_sha, dst_sha)
        dst_tags = run_git(self.dst_bare, "tag", "-l")
        self.assertIn("v1.0.0", dst_tags)

    def test_02_dry_run_does_not_modify_destination(self) -> None:
        res = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {"PUSH_MODE": "force", "DRY_RUN": "true"},
        )
        self.assertEqual(res.returncode, 0, msg=f"STDERR:\n{res.stderr}")
        branches = run_git(self.dst_bare, "branch", "-a")
        self.assertEqual(branches, "")

    def test_03_divergent_rejected_in_fast_forward_and_allowed_in_force(self) -> None:
        # First sync main
        res0 = self.run_sync(to_posix_path(self.src_bare), "main", to_posix_path(self.dst_bare), "main")
        self.assertEqual(res0.returncode, 0, msg=res0.stderr)

        # Create divergent commit on destination
        run_git(self.tmp, "clone", str(self.dst_bare), str(self.work_dst))
        run_git(self.work_dst, "config", "user.email", "dst@refertur.net")
        run_git(self.work_dst, "config", "user.name", "Dst Bot")
        (self.work_dst / "dst_only.txt").write_text("divergent\n", encoding="utf-8")
        run_git(self.work_dst, "add", ".")
        run_git(self.work_dst, "commit", "-m", "divergent commit")
        run_git(self.work_dst, "push", "origin", "main")
        divergent_sha = run_git(self.dst_bare, "rev-parse", "refs/heads/main")

        # Advance source independently
        (self.work_src / "src_new.txt").write_text("source advance\n", encoding="utf-8")
        run_git(self.work_src, "add", ".")
        run_git(self.work_src, "commit", "-m", "source commit 2")
        run_git(self.work_src, "push", "origin", "main")
        src_sha = run_git(self.src_bare, "rev-parse", "refs/heads/main")

        # fast-forward MUST fail and leave destination untouched
        res_ff = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {"PUSH_MODE": "fast-forward"},
        )
        self.assertNotEqual(res_ff.returncode, 0)
        self.assertEqual(run_git(self.dst_bare, "rev-parse", "refs/heads/main"), divergent_sha)

        # force-with-lease MUST succeed after fetching destination state
        res_lease = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {"PUSH_MODE": "force-with-lease"},
        )
        self.assertEqual(res_lease.returncode, 0, msg=res_lease.stderr)
        self.assertEqual(run_git(self.dst_bare, "rev-parse", "refs/heads/main"), src_sha)

    def test_04_command_injection_resistance(self) -> None:
        marker = self.tmp / "pwned_marker"
        malicious_branch = f"main; touch '{to_posix_path(marker)}'"
        res = self.run_sync(
            to_posix_path(self.src_bare),
            malicious_branch,
            to_posix_path(self.dst_bare),
            "main",
        )
        self.assertNotEqual(res.returncode, 0)
        self.assertFalse(marker.exists(), "Command injection occurred! Marker file was created.")

    def test_05_credential_redaction_in_logs(self) -> None:
        secret = "ghp_SUPER_SECRET_TOKEN_999"
        # Use an unreachable/invalid HTTPS URL with secret; git clone will fail,
        # but our SOURCE= log line MUST redact the secret.
        fake_url = f"https://user:{secret}@127.0.0.1:1/org/repo.git"
        res = self.run_sync(fake_url, "main", to_posix_path(self.dst_bare), "main")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("https://***@127.0.0.1:1/org/repo.git", res.stdout)
        self.assertNotIn(secret, res.stdout)

    def test_06_ssh_key_materialization_and_invalid_modes(self) -> None:
        # Invalid PUSH_MODE must fail fast
        res_bad = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {"PUSH_MODE": "unsafe-mode"},
        )
        self.assertNotEqual(res_bad.returncode, 0)
        self.assertIn("invalid PUSH_MODE", res_bad.stderr)

        # Invalid STRICT_HOST_KEY_CHECKING=no must be rejected!
        res_mitm = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {"STRICT_HOST_KEY_CHECKING": "no"},
        )
        self.assertNotEqual(res_mitm.returncode, 0)
        self.assertIn("invalid STRICT_HOST_KEY_CHECKING", res_mitm.stderr)

        # Escaped single-line key materializes into multi-line file with chmod 600
        res_key = self.run_sync(
            to_posix_path(self.src_bare),
            "main",
            to_posix_path(self.dst_bare),
            "main",
            {
                "SSH_PRIVATE_KEY": r"LINE1\nLINE2\nLINE3",
                "SSH_KNOWN_HOSTS": "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA",
            },
        )
        self.assertEqual(res_key.returncode, 0, msg=res_key.stderr)
        key_text = (self.ssh_dir / "shared_key").read_text(encoding="utf-8")
        self.assertEqual(key_text.splitlines(), ["LINE1", "LINE2", "LINE3"])
        kh_text = (self.ssh_dir / "known_hosts").read_text(encoding="utf-8")
        self.assertIn("github.com ssh-ed25519", kh_text)


if __name__ == "__main__":
    unittest.main()
