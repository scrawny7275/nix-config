#!/usr/bin/env python3
"""replay-driver.py (v3) — rebuild scrawny7275/nix-config as a curated PR
series, manifest-driven.

Rebuilds an EMPTY, freshly-created private repo into a content-identical tip
of the pinned anchor commit. Units come from a derived manifest
(see scripts/release/derive-v3-manifest.py): v1's own topic granularity,
organic branch names, v1 PR titles/bodies, per-PR 1-3 commit arcs, GitHub
default merge titles (no commit_title override). The final tree MUST equal
the anchor tree exactly; the driver aborts on any invariant break.
Resumable via state.json.

Mirror semantics (READ CAREFULLY):
  The bare mirror in STATE_DIR is the CONTENT SOURCE, cloned ONE TIME via
  --setup while the source URL still resolves to the OLD repo. At execution
  time the same URL resolves to the NEW repo — every push/fetch of main
  during the run talks to the NEW repo; content comes only from the parked
  mirror's object store. --setup REFUSES to re-run against an existing
  mirror (a refetch after the rename would pull the NEW repo's refs over
  the anchor).

Prereqs (manual, NOT done by this driver):
  1. OLD repo renamed away (nix-config-ARCHIVE-DO-NOT-PUBLICIZE).
  2. NEW private repo `scrawny7275/nix-config` created EMPTY (no auto-init,
     issues/wiki/projects disabled).
  3. Manifest derived and present at REPLAY_MANIFEST (default:
     ~/nix-config-private/replay-3-manifest.json), anchor-matched.
  4. PAT (contents:rw, pull_requests:rw on the new repo) via REPLAY_PAT,
     REPLAY_PAT_FILE, or sops extract.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path
from typing import NoReturn

# ---------------------------------------------------------------- constants

OWNER = "scrawny7275"
REPO = "nix-config"
SSH_URL = "ssh://git@ssh.github.com:443/{o}/{r}.git".format(o=OWNER, r=REPO)
API = "https://api.github.com"

IDENT_NAME = "scrawny7275"
IDENT_EMAIL = "283480047+scrawny7275@users.noreply.github.com"

PRIVATE_KIT = Path.home() / "nix-config-private"
SOPS_KEY = Path.home() / ".config" / "sops" / "age" / "keys.txt"
SECRETS_YAML = Path.home() / "nix-config" / "secrets" / "laptop.yaml"
MANIFEST_PATH = Path(os.environ.get(
    "REPLAY_MANIFEST",
    str(PRIVATE_KIT / "replay-3-manifest.json")))

STATE_ROOT = os.environ.get("REPLAY_STATE_DIR") or os.environ.get(
    "XDG_STATE_HOME", str(Path.home() / ".local" / "state"))
STATE_DIR = Path(STATE_ROOT) / "replay-driver"
STATE_FILE = STATE_DIR / "state.json"
RUN_LOG = STATE_DIR / "run.jsonl"

ANCHOR_PATH = Path(os.environ.get(
    "REPLAY_ANCHOR", "/tmp/replay2-anchor.txt"))   # two lines: commit, tree

GIT_ENV_BASE = {
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_SYSTEM": "/dev/null",
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_ASKPASS": "/bin/false",
    "GIT_NO_REPLACE_OBJECTS": "1",
}

FORBIDDEN_SOURCES = [
    PRIVATE_KIT / "replace-map.txt",
]

# ------------------------------------------------------------------ utilities

def die(msg, code=1) -> NoReturn:
    print("ABORT: %s" % msg, file=sys.stderr)
    sys.exit(code)


def git_env(extra=None, dates=None):
    env = dict(os.environ)
    env.update(GIT_ENV_BASE)
    env["GIT_AUTHOR_NAME"] = IDENT_NAME
    env["GIT_AUTHOR_EMAIL"] = IDENT_EMAIL
    env["GIT_COMMITTER_NAME"] = IDENT_NAME
    env["GIT_COMMITTER_EMAIL"] = IDENT_EMAIL
    if dates:
        env["GIT_AUTHOR_DATE"] = dates
        env["GIT_COMMITTER_DATE"] = dates
    key_path = str(Path.home() / ".ssh" / ("id_ed25519_%s" % OWNER))
    env["GIT_SSH_COMMAND"] = "ssh -i %s -o IdentitiesOnly=yes" % key_path
    if extra:
        env.update(extra)
    return env


def g(cmd, repo, env_extra=None, check=True, capture=True):
    full = ["git", "-C", str(repo)] + cmd
    r = subprocess.run(full, env=git_env(env_extra),
                       capture_output=capture, text=True)
    if check and r.returncode != 0:
        die("git failed: %s\n%s" % (" ".join(cmd), r.stderr.strip()[:2000]))
    return r


def journal(event, **kw):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "event": event}
    rec.update(kw)
    with open(RUN_LOG, "a") as fh:
        fh.write(json.dumps(rec, sort_keys=True) + "\n")
        fh.flush()
        os.fsync(fh.fileno())


def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"done": [], "main_tip": None, "run_id": None, "pushed": {}}


def save_state(st):
    tmp = STATE_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(st, indent=2, sort_keys=True))
    os.replace(tmp, STATE_FILE)

# ------------------------------------------------------- forbidden token sweep

def load_forbidden():
    toks = set()
    for src in FORBIDDEN_SOURCES:
        if not src.exists():
            die("forbidden-corpus source missing: %s (fail-closed)" % src)
        for line in src.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            lhs = line.split("\t")[0].split("=>")[0].split("=")[0].strip()
            if lhs and not lhs.startswith("github_pat_"):
                toks.add(lhs)
    if len(toks) < 3:
        die("forbidden corpus parsed to <3 tokens; refusing to run blind")
    return toks


def scan_outbound(label, text, toks):
    for t in sorted(toks, key=len, reverse=True):
        if t and t in text:
            die("forbidden token in outbound %s: %r" % (label, t))

# -------------------------------------------------------------------- GitHub API

class GH:
    def __init__(self, pat):
        self.pat = pat

    def call(self, method, path, payload=None, expect=(200, 201, 204),
             retry_codes=(), retries=5, delay=6):
        url = "%s%s" % (API, path)
        data = None
        if payload is not None:
            data = json.dumps(payload).encode()
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", "token %s" % self.pat)
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("User-Agent", "replay-driver/3")
        req.add_header("X-GitHub-Api-Version", "2022-11-28")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                body = resp.read().decode()
                status = resp.status
        except urllib.error.HTTPError as e:
            if e.code in retry_codes and retries > 0:
                journal("api-retry", method=method, path=path,
                        status=e.code, attempts_left=retries - 1)
                time.sleep(delay)
                return self.call(method, path, payload, expect,
                                 retry_codes, retries - 1, delay)
            body = e.read().decode()
            die("github API %s %s -> %s: %s" % (method, path, e.code,
                                                body[:1500]))
        if status not in expect:
            die("github API %s %s -> %s (expected %s): %s"
                % (method, path, status, expect, body[:1500]))
        return (json.loads(body) if body else None), status

# ------------------------------------------------------------------- tree carving

def anchor_files(repo, anchor):
    out = g(["ls-tree", "-r", "--name-only", anchor], repo).stdout
    return sorted(x for x in out.split("\n") if x)


def drop_index_paths(repo, paths, env_extra):
    for i in range(0, len(paths), 200):
        chunk = paths[i:i + 200]
        if chunk:
            subprocess.run(
                ["git", "-C", str(repo), "update-index", "--force-remove",
                 "-z", "--stdin"],
                input="".join(p + "\0" for p in chunk).encode(),
                env=git_env(env_extra), check=True)


def carve_tree(repo, anchor, keep_paths):
    """Tree-SHA of `anchor` restricted to keep_paths."""
    tmpdir = tempfile.mkdtemp(prefix="replay-idx-")
    idx = os.path.join(tmpdir, "idx")
    env_extra = {"GIT_INDEX_FILE": idx}
    g(["read-tree", anchor], repo, env_extra)
    allf = anchor_files(repo, anchor)
    drop = [p for p in allf if p not in keep_paths]
    drop_index_paths(repo, drop, env_extra)
    tree = g(["write-tree"], repo, env_extra).stdout.strip()
    reap(tmpdir)
    return tree


def reap(p):
    import shutil
    shutil.rmtree(p, ignore_errors=True)

# -------------------------------------------------------------------- manifest

def load_manifest(anchor_commit, anchor_tree, all_files):
    """Load + validate the derived manifest. Returns units list."""
    if not MANIFEST_PATH.exists():
        die("manifest missing: %s (derive it first)" % MANIFEST_PATH)
    m = json.loads(MANIFEST_PATH.read_text())
    if m["anchor_commit"] != anchor_commit:
        die("manifest anchor %s != pinned %s — re-derive after re-pin"
            % (m["anchor_commit"][:12], anchor_commit[:12]))
    if m["anchor_tree"] != anchor_tree:
        die("manifest anchor tree mismatch")
    units = m["units"]
    boot = m.get("bootstrap", {"subject": "chore: repository bootstrap",
                               "paths": ["LICENSE", ".gitignore"]})
    # partition: disjoint, nonempty, every path in anchor, coverage complete
    seen = {}
    for i, u in enumerate(units, 1):
        u["n"] = i
        if not u["flat_paths"]:
            die("unit %d (%s) has no paths" % (i, u["branch"]))
        for p in u["flat_paths"]:
            if p in seen:
                die("partition conflict: %s in units %s and %s"
                    % (p, seen[p], i))
            seen[p] = i
        for cm in u["commits"]:
            if not cm["subject"]:
                die("unit %d commit without subject" % i)
    anchor_set = set(all_files)
    extra = sorted(set(seen) - anchor_set)
    if extra:
        die("manifest paths not in anchor: %s" % extra[:10])
    covered = set(seen) | set(boot["paths"])
    missing = sorted(anchor_set - covered)
    if missing:
        die("anchor paths uncovered by manifest: %s" % missing[:10])
    branches = [u["branch"] for u in units]
    if len(set(branches)) != len(branches):
        die("duplicate branch names in manifest")
    # CI-last rule: .github/ may exist only in the final unit
    for i, u in enumerate(units):
        if any(p.startswith(".github/") for p in u["flat_paths"]):
            if i != len(units) - 1:
                die("workflows paths in unit %d but CI must be LAST" % i)
    return m, units, boot

# ----------------------------------------------------------------------- driver

def ensure_repo(repo_dir):
    if not (Path(repo_dir) / "HEAD").exists() \
            and not (Path(repo_dir) / ".git").exists():
        die("mirror missing at %s — run --setup first" % repo_dir)


def main():
    plan_only = "--plan-only" in sys.argv
    resume_ok = "--resume" in sys.argv

    anchor_lines = ANCHOR_PATH.read_text().split()
    anchor_commit, anchor_tree = anchor_lines[0], anchor_lines[1]

    toks = load_forbidden()

    mirror = Path(os.environ.get("REPLAY_MIRROR",
                                 str(STATE_DIR / "mirror")))
    if "--setup" in sys.argv:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        if mirror.exists():
            die("mirror already exists at %s — REFUSING to refetch. "
                "The URL may already resolve to the NEW repo; deleting is "
                "manual: rm -rf the path ONLY if pre-flip." % mirror)
        subprocess.run(
            ["git", "clone", "--no-checkout",
             os.environ.get("REPLAY_SRC_URL", SSH_URL), str(mirror)],
            env=git_env(), check=True)
        got_tree = g(["rev-parse", "%s^{tree}" % anchor_commit],
                     mirror).stdout.strip()
        if got_tree != anchor_tree:
            die("anchor mismatch: fetched tree %s != pinned %s"
                % (got_tree, anchor_tree))
        print("setup OK: mirror at %s, anchor %s" % (mirror,
                                                     anchor_commit[:12]))
        return

    # --plan-only may run against the live worktree when no mirror exists yet.
    if plan_only and not mirror.exists():
        mirror = Path(".")
    ensure_repo(mirror)
    if not plan_only:
        got_tree = g(["rev-parse", "%s^{tree}" % anchor_commit],
                     mirror).stdout.strip()
        if got_tree != anchor_tree:
            die("anchor drift: mirror tree %s != pinned %s — mirror was "
                "fetched post-flip or the anchor moved. Re-pin and re-derive."
                % (got_tree, anchor_tree))
    all_files = anchor_files(mirror, anchor_commit)

    m, units, boot = load_manifest(anchor_commit, anchor_tree, all_files)
    # outbound sweep over EVERY manifest string before any byte leaves
    for u in units:
        scan_outbound("branch", u["branch"], toks)
        scan_outbound("title", u["title"], toks)
        scan_outbound("body", u["body"], toks)
        for cm in u["commits"]:
            scan_outbound("subject", cm["subject"], toks)
    scan_outbound("bootstrap-subject", boot["subject"], toks)

    total_authored = 1 + sum(len(u["commits"]) for u in units)

    if plan_only:
        print("PLAN: %d units, %d authored commits, %d files"
              % (len(units), total_authored, len(all_files)))
        for u in units:
            print("  PR%02d  %-52s %3d files, %d commit(s)"
                  % (u["n"], u["branch"], len(u["flat_paths"]),
                     len(u["commits"])))
        return

    # ---------------- live execution ----------------
    # PAT chain: REPLAY_PAT env (rehearsal) -> REPLAY_PAT_FILE (handoff file,
    # read in-process only) -> sops extract (canonical). The token NEVER
    # transits shell argv or stdout.
    pat = os.environ.get("REPLAY_PAT")
    if pat is None and os.environ.get("REPLAY_PAT_FILE"):
        pat = Path(os.environ["REPLAY_PAT_FILE"]).read_text().strip()
    if pat is None:
        pat = subprocess.run(
            ["sops", "decrypt", "--extract",
             '["api_keys"]["github_persona_pat"]',
             str(SECRETS_YAML)],
            env={**os.environ, "SOPS_AGE_KEY_FILE": str(SOPS_KEY)},
            capture_output=True, text=True, check=True).stdout.strip()
    if not pat.startswith("github_pat_"):
        die("pat extract shape wrong")
    gh = GH(pat)
    del pat  # token lives only inside gh

    state = load_state() if resume_ok else {"done": [], "main_tip": None,
                                            "run_id": None, "pushed": {}}
    state.setdefault("pushed", {})
    if not state.get("run_id"):
        state["run_id"] = "replay-%d" % int(time.time())
        journal("run-start", run_id=state["run_id"], anchor=anchor_commit,
                units=len(units))

    # Bootstrap: if repo empty, push the bootstrap commit to main.
    remote_heads = g(["ls-remote", "--heads", SSH_URL],
                     mirror, capture=True).stdout
    if "refs/heads/main" not in remote_heads:
        if state["done"] or state["main_tip"]:
            die("remote reports empty but local state claims progress — "
                "state/remote mismatch; refusing to guess")
        idx_dir = tempfile.mkdtemp(prefix="replay-boot-")
        idx = os.path.join(idx_dir, "idx")
        env_extra = {"GIT_INDEX_FILE": idx}
        g(["read-tree", anchor_commit], mirror, env_extra)
        keep = set(boot["paths"])
        drop_index_paths(
            mirror, [p for p in all_files if p not in keep], env_extra)
        boot_tree = g(["write-tree"], mirror, env_extra).stdout.strip()
        reap(idx_dir)
        boot_date = "%d +0000" % (int(time.time())
                                  - (total_authored + 1) * 1800)
        scan_outbound("bootstrap-msg", boot["subject"], toks)
        boot_commit = subprocess.run(
            ["git", "-C", str(mirror), "commit-tree", boot_tree,
             "-m", boot["subject"]],
            env=git_env(dates=boot_date), capture_output=True, text=True,
            check=True).stdout.strip()
        g(["push", SSH_URL, "%s:refs/heads/main" % boot_commit], mirror)
        # Empty repos: first push SHOULD become the default branch. If the
        # account default was something else (e.g. master), all PRs
        # targeting base=main would still work but the repo HEAD dangles.
        info, _ = gh.call("GET", "/repos/%s/%s" % (OWNER, REPO), expect=(200,))
        if info and info.get("default_branch") != "main":
            die("default_branch is %r, not 'main' — flip it in repo "
                "Settings > Branches (needs admin; PAT lacks it), then "
                "re-run with --resume" % info.get("default_branch"))
        if info and not info.get("private"):
            die("repo reports private=false — refusing to replay into a "
                "public surface")
        state["main_tip"] = boot_commit
        save_state(state)
        journal("bootstrap", commit=boot_commit, tree=boot_tree,
                default_branch="main", private=True)
        print("bootstrapped main at %s" % boot_commit[:12])
    else:
        # Resume path: remote main may hold merge commits created AFTER the
        # mirror was cloned one-time pre-flip. Fetch them into the object
        # store or the next commit-tree -p <merge> fails on a missing parent.
        g(["fetch", SSH_URL, "main"], mirror)
        got = g(["ls-remote", SSH_URL, "refs/heads/main"],
                mirror).stdout.split()[0]
        if not state["done"] and not state["main_tip"]:
            # Either foreign content (abort) or our own bootstrap push
            # landed but a later step died before save_state (adopt: the
            # bootstrap tree is content-pinned, equality proves provenance).
            idx_dir = tempfile.mkdtemp(prefix="replay-probe-")
            env_extra = {"GIT_INDEX_FILE": os.path.join(idx_dir, "idx")}
            g(["read-tree", anchor_commit], mirror, env_extra)
            drop_index_paths(
                mirror, [p for p in all_files
                         if p not in set(boot["paths"])], env_extra)
            want_boot_tree = g(["write-tree"], mirror, env_extra).stdout.strip()
            reap(idx_dir)
            got_tree_now = g(["rev-parse", "%s^{tree}" % got],
                             mirror).stdout.strip()
            if got_tree_now != want_boot_tree:
                die("remote main exists on a FRESH run with an unexpected "
                    "tree (%s != bootstrap %s) — foreign content or wrong "
                    "repo. Stop and check." % (got_tree_now, want_boot_tree))
            journal("bootstrap-adopted", commit=got, tree=want_boot_tree)
            print("adopted pre-existing bootstrap commit %s" % got[:12])
        state["main_tip"] = got

    commit_seq = [state.get("seq", 0)]

    def next_date():
        commit_seq[0] += 1
        state["seq"] = commit_seq[0]
        save_state(state)   # persist sequence: resume must not re-stamp
        stamp = int(time.time()) - (total_authored
                                    - commit_seq[0] + 1) * 1800
        return "%d +0000" % stamp

    cumulative = set(boot["paths"])

    for u in units:
        n = u["n"]
        if n in state["done"]:
            cumulative |= set(u["flat_paths"])
            continue
        parent = state["main_tip"]
        unit_keep = cumulative | set(u["flat_paths"])
        reuse = state["pushed"].get(str(n))
        if reuse:
            seen = g(["rev-parse", "%s^{tree}" % reuse],
                     mirror).stdout.strip()
            want = carve_tree(mirror, anchor_commit, unit_keep)
            if seen != want:
                die("resume: pushed %s tree %s != fresh carve %s — "
                    "anchor or partition drift since crash"
                    % (reuse, seen, want))
            commit = reuse
        else:
            for cm in u["commits"]:
                cumulative |= set(cm["paths"])
                tree = carve_tree(mirror, anchor_commit, cumulative)
                msg = cm["subject"]
                scan_outbound("commit-msg", msg, toks)
                dates = next_date()
                c = subprocess.run(
                    ["git", "-C", str(mirror), "commit-tree", tree,
                     "-p", parent, "-m", msg],
                    env=git_env(dates=dates), capture_output=True, text=True,
                    check=True).stdout.strip()
                parent = c
                journal("commit", unit=n, commit=c, subject=msg[:80])
            commit = parent
            g(["push", SSH_URL, "%s:refs/heads/%s" % (commit, u["branch"])],
              mirror)
            state["pushed"][str(n)] = commit
            save_state(state)
            journal("pushed", unit=n, commit=commit, branch=u["branch"])
        # Idempotent PR create: crash between create and merge must not 422.
        head_ref = "{}:{}".format(OWNER,
                                 urllib.parse.quote(u["branch"], safe=""))
        open_prs, _ = gh.call("GET",
                              "/repos/%s/%s/pulls?state=open&head=%s"
                              % (OWNER, REPO, head_ref),
                              expect=(200,))
        if open_prs:
            prn = open_prs[0]["number"]
        else:
            pr, _ = gh.call("POST", "/repos/%s/%s/pulls" % (OWNER, REPO),
                            {"title": u["title"], "head": u["branch"],
                             "base": "main", "body": u["body"]},
                            expect=(201,), retry_codes=(422,))
            if pr is None or "number" not in pr:
                die("PR create returned empty body for unit %d" % n)
            prn = pr["number"]
            journal("pr-created", pr=prn, unit=n, branch=u["branch"])
        # Default merge title: omit commit_title entirely -> GitHub writes
        # "Merge pull request #N from owner/branch" + PR title as body.
        merge, _ = gh.call("PUT",
                           "/repos/%s/%s/pulls/%d/merge" % (OWNER, REPO, prn),
                           {"merge_method": "merge"},
                           expect=(200,), retry_codes=(405, 409, 422))
        if merge is None or "sha" not in merge:
            die("merge returned empty body for PR #%d" % prn)
        gh.call("DELETE", "/repos/%s/%s/git/refs/heads/%s"
                % (OWNER, REPO, urllib.parse.quote(u["branch"], safe="")),
                expect=(204,))
        new_tip = merge["sha"]
        g(["fetch", SSH_URL, "main"], mirror)
        state["main_tip"] = new_tip
        state["done"].append(n)
        save_state(state)
        journal("merged", pr=prn, unit=n, commit=commit, merge=new_tip)
        print("PR#%d merged (%s) -> %s" % (prn, u["title"][:48],
                                           new_tip[:10]))
        cumulative = unit_keep
        time.sleep(2)

    # ---------------- final verification ----------------
    g(["fetch", SSH_URL, "main"], mirror)
    final_tip = g(["ls-remote", SSH_URL, "refs/heads/main"],
                  mirror).stdout.split()[0]
    final_tree = g(["rev-parse", "%s^{tree}" % final_tip],
                   mirror).stdout.strip()
    if final_tree != anchor_tree:
        die("FINAL MISMATCH: tip tree %s != anchor tree %s"
            % (final_tree, anchor_tree))
    journal("verified", final_tip=final_tip, tree=final_tree,
            units=len(units))
    print("VERIFIED: remote main tree == anchor tree (%s)" % anchor_tree)
    print("Run log: %s" % RUN_LOG)


if __name__ == "__main__":
    main()
