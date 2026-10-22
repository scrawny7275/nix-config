---
name: four-questions
description: Use before declaring dev work complete, before committing or creating PRs, and after AI writes a feature or fix - the four verification questions (security, efficiency, regressions, tests) answered with evidence, never from memory or intent
metadata:
  opencode/slash: "true"
---

<!--
Vendored from the "Rachel" video transcript by buildinghappi
Source: ~/Documents/Rachel - Video by buildinghappi.txt (lives outside the flake;
  this file is the tracked artifact per the artifact-placement rule)
Fetched: 2026-10-21
Adaptations: NOT verbatim - the four questions are rewritten as bounded checks
  mapped onto existing gates (Secret Handling standing rule,
  verification-before-completion red-green cycle). The transcript is
  auto-generated with mis-transcriptions ("Clot"/"Cloud" = Claude, "prov" =
  prove, "you're data" = your data). One practitioner's heuristic, not a
  validated standard - bounded deliberately: "most secure way" invites checkbox
  theater, "most efficient way" invites premature optimization.
Refresh: n/a (one-off transcript; no upstream to diff against).
-->

# Four Questions

## Overview

**Core principle:** AI-built code works before it's understood. The feature runs, the API answers - and the understanding of what will break, scale, confuse, or leak never arrives. These four checks close the gap between "it works" and "it's ready".

The hard part of engineering was never writing the code: it's knowing what breaks, what scales, what confuses the next person, what leaks. AI made those problems show up faster, not go away.

## The Gate

```
BEFORE declaring dev work complete, committing, or creating a PR:

ANSWER ALL FOUR CHECKS WITH EVIDENCE - fresh output, cited files, named lines.
Memory, intent, and "should be fine" are not evidence.

Cannot answer with evidence = not done. Say so and enumerate the gaps.
```

## The Four Checks (bounded, by design)

### 1. Security - bounded to what changed

- Injection surfaces: does any input cross a trust boundary (CLI args, HTTP, env, files, socket payloads)? What validates it?
- Secret exposure: is any key/token/password materialized in plaintext - command lines, logs, process env, test fixtures? Cross-check the Secret Handling standing rule in AGENTS.md before answering.
- Auth-surface changes: new endpoints or callables? Permission checks added, weakened, or removed?

NOT "is this the most secure possible" - unbounded security questions invite checkbox theater. Bounded to the diff.

### 2. Efficiency - bounded to obvious blunders

- Algorithmic blunders visible without profiling: accidental O(n^2), repeated work inside loops, N+1 queries, re-reading what a variable already holds.
- Accidental complexity for the next reader: indirection that solves no stated problem.

NOT micro-optimization. "Most efficient way" invites premature optimization; flag only what a reviewer would call obvious.

### 3. Regressions - enumerate, don't assume

- Enumerate the blast radius with names: callers, dependents, config consumers, downstream modules that read what changed.
- For each risk named, prove the regression absent (or present) via the verification-before-completion red-green cycle - write the test, watch it fail against the old behavior, pass against the new.

### 4. Tests - evidence, not intent

- What test is needed before shipping this? Write the failing test FIRST, watch it fail, then make it pass.
- Fresh verification output per verification-before-completion - no completion claim without it.

## Relationship to verification-before-completion

This skill is WHAT to ask before shipping AI-built work. verification-before-completion is HOW to prove any claim made while answering. Load both; use them together.

## When this applies

- Before ANY "done", "works", "shipped" claim about dev work
- Before `git commit`, `git push`, PR creation
- After AI (you or another agent) wrote a feature or fix
- On demand: `/four-questions`
