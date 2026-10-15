#!/usr/bin/env python3
"""derive-v3-manifest.py — derive the replay-v3 unit manifest from v1's chain.

Walks the archive repo's first-parent history (bootstrap -> 33 replay-era PR
merges -> forward-era merges -> direct landings) and emits, per unit:

  - the v1 branch name (organic: pr-01-shell, feat/..., chore/...)
  - the v1 PR title and body (provenance lines included, verbatim from the
    archived PR record — they are part of the surface we are recreating)
  - the v1 head-commit subjects (1-2 per PR), preserving intra-PR arcs
  - per-commit path sets: anchor-tree paths FIRST APPEARING at each head
    commit along the chain, so the union over all commits is provably the
    anchor tree and units are disjoint by construction.

Deviations recorded in the manifest:
  - units whose paths were all superseded/deleted before the anchor drop out
    (e.g. cf-deploy wrapper: added on a forward PR, then reverted; final tree
    has no remnant)
  - the unit introducing .github/workflows is moved to the END by the driver
    (mid-chain CI would fire failing runs on every later partial-tree PR)
  - v1's bootstrap subject claimed "CI-first foundation" while CI actually
    landed at PR #34; v3's bootstrap subject drops that suffix.

Reads: local repo (any refspec), /tmp/replay2-anchor.txt (commit + tree),
PAT from ~/nix-config-private/.pat-handoff (0600; in-process read only, used
solely for GET of archived PR metadata).

Writes: ~/nix-config-private/replay-3-manifest.json (campaign machinery;
stays in the private kit, never enters the public tree).
"""

import json
import os
import re
import subprocess
import sys
import urllib.request
import urllib.error
from pathlib import Path

REPO = Path(os.environ.get("REPLAY_REPO_ROOT", str(Path.home() / "nix-config")))
PRIVATE_KIT = Path.home() / "nix-config-private"
PAT_FILE = PRIVATE_KIT / ".pat-handoff"
ANCHOR_PATH = Path("/tmp/replay2-anchor.txt")
OUT = Path(os.environ.get("REPLAY_MANIFEST_OUT",
                          str(PRIVATE_KIT / "replay-3-manifest.json")))
ARCHIVE_REPO = "scrawny7275/nix-config-ARCHIVE-DO-NOT-PUBLICIZE"

BOOTSTRAP_SUBJECT = "chore: repository bootstrap"


def git(*args):
    return subprocess.run(["git", "-C", str(REPO)] + list(args),
                          capture_output=True, text=True, check=True).stdout


def tree_paths(rev):
    return set(x for x in git("ls-tree", "-r", "--name-only", rev
                              ).split("\n") if x)


def first_parent_chain(tip):
    return git("rev-list", "--first-parent", "--reverse", tip).splitlines()


def is_merge(rev):
    return len(git("rev-parse", rev + "^@").split()) > 1


def head_commits(merge_rev):
    """non-merge commits on the head branch of a merge, oldest first."""
    out = git("rev-list", "--no-merges", "--reverse",
              "%s^1..%s^2" % (merge_rev, merge_rev)).splitlines()
    return out


def fetch_v1_prs():
    pat = PAT_FILE.read_text().strip()
    url = ("https://api.github.com/repos/%s/pulls?state=all&per_page=100"
           % ARCHIVE_REPO)
    req = urllib.request.Request(url)
    req.add_header("Authorization", "token %s" % pat)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode())


def branch_slug(title):
    """feat(desktop): niri compositor — uwsm session ... -> feat/desktop-niri-compositor

    Conventional topic branch: type/scope-tail. Mechanical from the v1 PR
    title — no hand-curation. Stopwords dropped, em-dash tail ignored,
    first four significant words kept.
    """
    m = re.match(r"\s*([A-Za-z+\-]+)(?:\(([^)]*)\))?\s*:\s*(.*)", title)
    if not m:
        return slugify(title)
    t, scope, rest = m.group(1), m.group(2), m.group(3)
    t = t.replace("+", "-").lower()
    stop = {"and", "or", "the", "a", "an", "with", "via", "for", "of", "in",
            "to", "from", "as", "on"}
    words = [w for w in re.findall(r"[a-z0-9]+",
                                   rest.split("—")[0].lower())
             if w not in stop]
    tail = "-".join(words[:4])[:34].strip("-")
    if scope:
        s = re.sub(r"[^a-z0-9]+", "-", scope.lower()).strip("-")
        return "%s/%s-%s" % (t, s, tail) if tail else "%s/%s" % (t, s)
    return "%s/%s" % (t, tail)


def slugify(title, maxlen=48):
    """feat(desktop): niri compositor — uwsm session -> feat/desktop-niri-compositor"""
    head = title.split("—")[0].strip()          # drop em-dash tail
    out = []
    for ch in head:
        ch = ch.lower()
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "-":
            out.append("-")
    s = "".join(out).strip("-")
    s = s.replace(":", "").replace("(", "-").replace(")", "").replace("--", "-")
    parts = [p for p in s.split("-") if p]
    acc = ""
    for p in parts:
        nxt = p if not acc else acc + "-" + p
        if len(nxt) > maxlen:
            break
        acc = nxt
    return acc


def main():
    anchor_commit, anchor_tree = ANCHOR_PATH.read_text().split()
    anchor_files = tree_paths(anchor_commit)

    v1_prs = fetch_v1_prs()
    by_branch = {}
    for p in v1_prs:
        by_branch.setdefault(p["head"]["ref"], p)  # first occurrence wins

    chain = first_parent_chain(anchor_commit)
    seen = set()
    units = []
    trailing = []   # post-merge-queue direct landings that added paths
    warnings = []

    for rev in chain:
        paths = tree_paths(rev)
        new = paths - seen
        seen |= paths
        if not is_merge(rev):
            if not units:
                assert {"LICENSE", ".gitignore"} <= new, \
                    "bootstrap root lacks LICENSE/.gitignore"
            else:
                keep = sorted(p for p in new if p in anchor_files)
                if keep:
                    subj = git("log", "-1", "--format=%s", rev).strip()
                    trailing.append({"subj": subj, "paths": keep})
            continue
        subject = git("log", "-1", "--format=%s", rev).strip()
        try:
            pr_num = int(subject.split("#")[1].split()[0])
            branch = subject.split("from ", 1)[1].split("/", 1)[1]
        except Exception as e:
            warnings.append("unparsable merge subject %s: %r (%s)"
                            % (rev[:10], subject, e))
            continue
        meta = by_branch.get(branch)
        heads = head_commits(rev)
        # Per-commit path split: first appearance along the merge's head
        # branch, intersected with the anchor. Modifications to pre-existing
        # paths do not reassign ownership (final blob comes from the anchor).
        prev_tree = tree_paths(git("rev-parse", rev + "^1").strip())
        commits = []
        for c in heads:
            cp = tree_paths(c)
            own = sorted(p for p in (cp - prev_tree) if p in anchor_files)
            if own or not commits:
                commits.append({"subject": git("log", "-1", "--format=%s",
                                               c).strip(),
                                "paths": own})
            prev_tree = cp | prev_tree
        flat = [p for cm in commits for p in cm["paths"]]
        if not flat:
            warnings.append("PR #%d (%s): no surviving anchor paths — dropped"
                            % (pr_num, branch))
            continue
        title = (meta or {}).get("title") or commits[-1]["subject"]
        units.append({
            "branch": branch_slug(title),
            "title": title,
            "body": (meta or {}).get("body") or "",
            "v1_branch": branch,
            "commits": commits,
            "flat_paths": flat,
        })

    # Trailing direct landings -> organic units, one per landing, branch
    # slugs derived from their own subjects (best-practice topic branches).
    for t in trailing:
        units.append({
            "branch": branch_slug(t["subj"]),
            "title": t["subj"],
            "body": "",
            "commits": [{"subject": t["subj"], "paths": t["paths"]}],
            "flat_paths": t["paths"],
        })

    # ---- CI-last rule: the unit introducing .github/workflows is moved to
    # the END — mid-chain CI would fire failing runs against every later
    # partial-tree PR card. Recorded in notes.
    ci_idx = None
    for i, u in enumerate(units):
        if any(p.startswith(".github/") for p in u["flat_paths"]):
            assert ci_idx is None, "workflows paths in more than one unit"
            ci_idx = i
    if ci_idx is not None and ci_idx != len(units) - 1:
        moved = units.pop(ci_idx)
        units.append(moved)
        reorder_note = ("unit %d (%s) moved to END (CI-last rule)"
                        % (ci_idx + 1, moved["branch"]))
    else:
        reorder_note = "CI unit already last"

    # ---- partition validation (hard gates)
    all_paths = [p for u in units for p in u["flat_paths"]]
    assert len(set(all_paths)) == len(all_paths), "partition overlap"
    covered = set(all_paths) | {"LICENSE", ".gitignore"}
    missing = sorted(anchor_files - covered)
    assert not missing, "uncovered anchor paths: %s" % missing[:15]
    for u in units:
        assert u["flat_paths"], "empty unit slipped through"
    branches = [u["branch"] for u in units]
    assert len(set(branches)) == len(branches), "duplicate branch names"

    out = {
        "anchor_commit": anchor_commit,
        "anchor_tree": anchor_tree,
        "bootstrap": {"subject": BOOTSTRAP_SUBJECT,
                      "paths": ["LICENSE", ".gitignore"]},
        "units": units,
        "warnings": warnings,
        "stats": {"units": len(units), "paths": len(all_paths) + 2,
                  "anchor_files": len(anchor_files),
                  "commits": sum(len(u["commits"]) for u in units)},
        "notes": [
            "unit order == v1 first-parent chain order (CI-last exception)",
            reorder_note,
            "empty-after-anchor-intersection units dropped (see warnings)",
            "merge commits use GitHub default titles (API, no commit_title)",
            "branch names derived mechanically from v1 PR titles",
            "bootstrap subject drops v1's false 'CI-first' claim",
        ],
    }
    OUT.write_text(json.dumps(out, indent=2) + "\n")
    print("units: %d  commits: %d  paths covered: %d/%d"
          % (len(units), out["stats"]["commits"],
             len(all_paths) + 2, len(anchor_files)))
    for w in warnings:
        print("WARN:", w)
    for i, u in enumerate(units, 1):
        ncommits = len(u["commits"])
        print("  %2d. %-32s %3d files, %d commit(s) | %s"
              % (i, u["branch"], len(u["flat_paths"]), ncommits,
                 u["title"][:60]))
    print("wrote %s" % OUT)


if __name__ == "__main__":
    main()
