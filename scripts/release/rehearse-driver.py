#!/usr/bin/env python3
"""rehearse-driver.py (v3) — full-dress, zero-network rehearsal for the
manifest-driven replay-driver.

Simulates the GitHub half of the replay (PR create/merge/branch-delete) as
git operations on a LOCAL bare repo, so the driver runs its real code path —
manifest validation, per-commit tree carving, forbidden sweeps, bootstrap,
journal, resume — with only API/transport swapped out. Asserts:

  1. final bare-repo main tree == pinned anchor tree (byte parity)
  2. every commit (bootstrap + authored + merges) carries the persona
     identity and UTC timezone
  3. journal events: run-start, bootstrap, N x merged, verified
  4. after a forced crash at PR#5, --resume converges to identical trees
  5. a poisoned manifest title containing a live forbidden token is refused
  6. crash right after bootstrap push (pre-save_state): resume ADOPTS the
     content-pinned bootstrap commit

Run: python3 scripts/release/rehearse-driver.py
Safe: touches only mktemp sandboxes + the driver's own patched state dir.
No ssh, no api.github.com, no sops.
"""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
from pathlib import Path

REPO_ROOT = Path(os.environ.get("REPLAY_REPO_ROOT",
                                Path.home() / "nix-config"))
DRIVER = REPO_ROOT / "scripts" / "release" / "replay-driver.py"
MANIFEST = Path(os.environ.get(
    "REPLAY_MANIFEST",
    str(Path.home() / "nix-config-private" / "replay-3-manifest.json")))

# FakeGH must persist across the crash/resume boundary exactly like real
# GitHub does: the PR created before the crash is still OPEN on resume,
# and the driver MUST find it via GET (not POST a duplicate).
_GH_REGISTRY = {}


def load_driver():
    spec = importlib.util.spec_from_file_location("replay_driver", DRIVER)
    m = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(m)
    return m


def run_git(repo, *args, env_extra=None, check=True):
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    r = subprocess.run(["git", "-C", str(repo)] + list(args),
                       capture_output=True, text=True, env=env)
    if check and r.returncode != 0:
        raise AssertionError("git %s failed: %s" % (" ".join(args), r.stderr))
    return r.stdout.strip()


class FakeGH:
    """GitHub API stand-in: PR lifecycle == refs + merge commits in `bare`."""

    def __init__(self, bare, crash_at_merge=None, crash_at_repo_info=False):
        self.bare = Path(bare)
        self.next_pr = 1
        self.prs = {}
        self.merged = set()
        self.merges = 0
        self.crash_at_merge = crash_at_merge
        self.crash_at_repo_info = crash_at_repo_info
        self.last_run_log = []

    def call(self, method, path, payload=None, expect=(200, 201, 204),
             retry_codes=(), retries=5, delay=6):
        api_base = path.split("?")[0]
        parts = api_base.split("/")
        owner_repo = "/".join(parts[2:4])
        assert owner_repo == "scrawny7275/nix-config", path
        now = "%d +0000" % int(time.time())
        env = {
            "GIT_AUTHOR_NAME": "scrawny7275",
            "GIT_AUTHOR_EMAIL":
                "283480047+scrawny7275@users.noreply.github.com",
            "GIT_COMMITTER_NAME": "scrawny7275",
            "GIT_COMMITTER_EMAIL":
                "283480047+scrawny7275@users.noreply.github.com",
            "GIT_AUTHOR_DATE": now,
            "GIT_COMMITTER_DATE": now,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
        }
        if method == "GET" and "/pulls" in api_base:
            q = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            head = q.get("head", [""])[0]
            branch = urllib.parse.unquote(
                head.split(":", 1)[1] if ":" in head else head)
            openp = [dict(p, number=n) for n, p in self.prs.items()
                     if p.get("head") == branch and n not in self.merged]
            return openp, 200
        if method == "GET" and api_base == "/repos/%s/%s" \
                % ("scrawny7275", "nix-config"):
            if self.crash_at_repo_info:
                self.crash_at_repo_info = False     # crash once, then heal
                raise SystemExit("SIMULATED CRASH at repo-info probe")
            return {"default_branch": "main", "private": True}, 200
        if method == "POST" and api_base.endswith("/pulls"):
            n = self.next_pr
            self.next_pr += 1
            self.prs[n] = dict(payload)
            return {"number": n}, 201
        if method == "PUT" and "/merge" in api_base:
            prn = int(api_base.split("/pulls/")[1].split("/")[0])
            if self.crash_at_merge is not None and prn == self.crash_at_merge:
                self.crash_at_merge = None        # crash once, then heal
                raise SystemExit("SIMULATED CRASH at merge #%d" % prn)
            pr = self.prs[prn]
            branch = pr["head"]
            main_tip = run_git(self.bare, "rev-parse", "refs/heads/main")
            tree = run_git(self.bare, "rev-parse",
                           "%s^{tree}" % ("refs/heads/" + branch))
            # GitHub default merge title when the API call omits commit_title:
            # "Merge pull request #N from owner/branch" (PR title as body).
            title = payload.get("commit_title") or (
                "Merge pull request #%d from scrawny7275/%s" % (prn, branch))
            mc = subprocess.run(
                ["git", "-C", str(self.bare), "commit-tree", tree,
                 "-p", main_tip, "-p", "refs/heads/" + branch,
                 "-m", title],
                env={**os.environ, **env}, capture_output=True, text=True,
                check=True).stdout.strip()
            run_git(self.bare, "update-ref", "refs/heads/main", mc)
            self.merges += 1
            self.merged.add(prn)
            self.last_run_log.append(mc)
            return {"sha": mc}, 200
        if method == "DELETE":
            ref = urllib.parse.unquote(path.split("/git/")[1])
            run_git(self.bare, "update-ref", "-d", ref)
            return None, 204
        raise AssertionError("unexpected FakeGH call: %s %s" % (method, path))


def fake_gh_factory(bare, crash_at_merge=None, crash_at_repo_info=False):
    key = str(bare)
    gh = _GH_REGISTRY.get(key)
    if gh is None:
        gh = FakeGH(bare)
        _GH_REGISTRY[key] = gh
    if crash_at_merge is not None:
        gh.crash_at_merge = crash_at_merge
    if crash_at_repo_info:
        gh.crash_at_repo_info = True
    return gh


def drive(m, argv, env_updates):
    """Run driver.main() in-process with patched global surfaces."""
    old_argv, old_env = sys.argv[:], dict(os.environ)
    try:
        sys.argv = ["replay-driver"] + list(argv)
        os.environ.update(env_updates)
        m.main()
    finally:
        sys.argv = old_argv
        os.environ.clear()
        os.environ.update(old_env)


def assert_commits_clean(bare, label):
    fmt = "%an <%ae>|%cn <%ce>|%aI|%cI"
    want_ident = ("scrawny7275 "
                  "<283480047+scrawny7275@users.noreply.github.com>")
    out = run_git(bare, "log", "--format=" + fmt, "refs/heads/main")
    bad = []
    for l in out.splitlines():
        parts = l.split("|")
        if len(parts) != 4:
            bad.append(l)
            continue
        an, cn, ad, cd = parts
        utc = lambda d: d.endswith("+00:00") or d.endswith("Z")
        if an != want_ident or cn != want_ident \
                or not utc(ad) or not utc(cd):
            bad.append(l)
    assert not bad, "[%s] non-persona/non-UTC commits:\n%s" % (label, bad[:3])
    print("  [%s] identity/tz gate: %d commits OK"
          % (label, len(out.splitlines())))


def journal_events(state_dir):
    evs = []
    for line in (Path(state_dir) / "run.jsonl").read_text().splitlines():
        evs.append(json.loads(line)["event"])
    return evs


def manifest_counts():
    m = json.loads(MANIFEST.read_text())
    units = m["units"]
    return (len(units),
            sum(len(u["commits"]) for u in units),
            1 + sum(len(u["commits"]) for u in units) + len(units))


def run_once(scratch, crash_at_merge=None, resume=False,
             crash_at_repo_info=False):
    fresh = not resume
    m = load_driver()
    bare = scratch / "remote.git"
    mirror = scratch / "mirror"
    state = scratch / "state"

    if fresh:
        bare.mkdir(parents=True)
        run_git(scratch, "init", "--bare", str(bare.name))
        _GH_REGISTRY.pop(str(bare), None)

    # Patch driver surfaces at the instance, not the file.
    m.SSH_URL = "file://" + str(bare)
    m.OWNER, m.REPO = "scrawny7275", "nix-config"
    m.STATE_DIR = state
    m.STATE_FILE = state / "state.json"
    m.RUN_LOG = state / "run.jsonl"
    m.ANCHOR_PATH = Path("/tmp/replay2-anchor.txt")
    m.GH = lambda pat: fake_gh_factory(bare, crash_at_merge,
                                       crash_at_repo_info)
    m.time.sleep = lambda *_: None  # type: ignore[attr-defined]

    state.mkdir(parents=True, exist_ok=True)
    env = {
        "REPLAY_PAT": "github_pat_rehearsal",
        "REPLAY_SRC_URL": str(REPO_ROOT),
        "REPLAY_MIRROR": str(mirror),
        "REPLAY_MANIFEST": str(MANIFEST),
    }

    if fresh:
        drive(m, ["--setup"], env)

    argv = ["--resume"] if resume else []
    drive(m, argv, env)

    anchor_commit, anchor_tree = m.ANCHOR_PATH.read_text().split()
    tip_tree = run_git(bare, "rev-parse", "refs/heads/main^{tree}")
    assert tip_tree == anchor_tree, (
        "rehearsal tree mismatch: %s != %s" % (tip_tree, anchor_tree))
    print("  tree parity: bare main == anchor (%s)" % anchor_tree[:12])

    refs = run_git(bare, "for-each-ref", "--format=%(refname)").splitlines()
    assert refs == ["refs/heads/main"], "stray refs left: %s" % refs
    print("  refs clean: only main remains")

    return m, bare, mirror, state


def main():
    n_units, n_authored, n_total = manifest_counts()
    print("manifest: %d units, %d authored commits, %d total commits"
          % (n_units, n_authored, n_total))

    scratch = Path(tempfile.mkdtemp(prefix="rehearse-"))
    print("rehearsal sandbox: %s" % scratch)

    print("PASS 1: clean run")
    m1, bare, mirror, state = run_once(scratch)
    evs = journal_events(state)
    assert evs.count("run-start") == 1 and evs.count("bootstrap") == 1, evs
    assert evs.count("merged") == n_units, \
        "merged %d != %d" % (evs.count("merged"), n_units)
    assert evs.count("verified") == 1, evs
    print("  journal: run-start, bootstrap, %d merged, verified ✓" % n_units)
    assert_commits_clean(bare, "clean-run")

    n_actual = len(run_git(bare, "log", "--format=%H", "main").splitlines())
    assert n_actual == n_total, "commit count %d != expected %d" \
        % (n_actual, n_total)
    print("  commit cardinality: %d == bootstrap + %d authored + %d merges"
          % (n_total, n_authored, n_units))

    shas_clean = run_git(bare, "log", "--topo-order", "--format=%H", "main")
    # Materialize the clean run's per-commit TREE list NOW — PASS 2 wipes
    # and rebuilds the bare repo; merge dates differ so SHAs differ too.
    trees_clean = [run_git(bare, "rev-parse", h + "^{tree}")
                   for h in shas_clean.splitlines()]

    print("PASS 2: crash at PR#5 + resume")
    shutil.rmtree(state)
    shutil.rmtree(mirror)
    shutil.rmtree(bare)
    try:
        run_once(scratch, crash_at_merge=5)
        raise AssertionError("crash run should not complete pass")
    except SystemExit as e:
        assert "SIMULATED CRASH" in str(e), e
    print("  crash injected at merge #5; resuming")
    run_once(scratch, resume=True)
    evs2 = journal_events(state)
    assert evs2.count("verified") == 1, evs2
    # Crash between PR-create and merge means resume MUST reuse the
    # still-open PR (GET path), never POST a duplicate.
    creates_u5 = [e for e in (Path(state) / "run.jsonl").read_text()
                  .splitlines() if json.loads(e)["event"] == "pr-created"
                  and json.loads(e)["unit"] == 5]
    assert len(creates_u5) == 1, \
        "unit-5 PR created %d times (duplicate POST on resume)" \
        % len(creates_u5)
    shas_resumed = run_git(bare, "log", "--topo-order", "--format=%H", "main")
    trees_resumed = [run_git(bare, "rev-parse", h + "^{tree}")
                     for h in shas_resumed.splitlines()]
    assert trees_clean == trees_resumed, "resume produced divergent trees"
    print("  resume converged: per-commit trees identical to clean run")
    print("  unit-5 PR created exactly once across crash+resume ✓")
    assert_commits_clean(bare, "resume-run")

    print("PASS 3: poisoned manifest title refused (black-box)")
    manifest_doc = json.loads(MANIFEST.read_text())
    toks = load_driver().load_forbidden()
    poison = sorted(toks, key=len)[-1]
    manifest_doc["units"][0]["title"] = \
        "feat: restore legacy %s handle" % poison
    poisoned = Path(tempfile.mkdtemp(prefix="poison-")) / "manifest.json"
    poisoned.write_text(json.dumps(manifest_doc))
    m3 = load_driver()
    old_env = dict(os.environ)
    os.environ["REPLAY_MANIFEST"] = str(poisoned)
    sys.argv = ["replay-driver", "--plan-only"]
    refused = False
    try:
        m3.main()
    except SystemExit as e:
        refused = (e.code == 1)
    finally:
        sys.argv = ["replay-driver"]
        os.environ.clear()
        os.environ.update(old_env)
    assert refused, "poisoned manifest was NOT refused"
    print("  forbidden-token sweep fired on poisoned manifest ✓")

    print("PASS 4: crash after bootstrap push (pre-save_state) + adoption")
    scratch4 = Path(tempfile.mkdtemp(prefix="rehearse-boot-"))
    try:
        run_once(scratch4, crash_at_repo_info=True)
        raise AssertionError("repo-info crash run should not complete")
    except SystemExit as e:
        assert "SIMULATED CRASH" in str(e), e
    st4_path = scratch4 / "state" / "state.json"
    st4 = json.loads(st4_path.read_text()) if st4_path.exists() else {}
    assert not st4.get("main_tip") and not st4.get("done"), \
        "state must NOT have recorded bootstrap at crash point: %s" % st4
    run_once(scratch4, resume=True)
    evs4 = journal_events(scratch4 / "state")
    assert "bootstrap-adopted" in evs4, evs4
    assert evs4.count("verified") == 1, evs4
    anchor_tree = Path("/tmp/replay2-anchor.txt").read_text().split()[1]
    tip4 = run_git(scratch4 / "remote.git", "rev-parse",
                   "refs/heads/main^{tree}")
    assert tip4 == anchor_tree, "PASS4 tree mismatch"
    print("  bootstrap adopted via content-pinned tree proof ✓")
    print("  tree parity after adoption ✓")

    print("\nALL GATES GREEN — sandbox at %s" % scratch)


if __name__ == "__main__":
    main()
