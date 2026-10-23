# XDG MIME Defaults — Closed Candidate Registry Architecture

The system that decides which application opens which file type:
`modules/user/desktop/xdg/`. Four cooperating pieces, two validation gates,
one rule — **a desktop ID that was never declared anywhere cannot become a
default anywhere**.

## Problem Statement

The pre-refactor central `mimeApps.nix` mapped MIME types through a list of
hardcoded, free-string desktop IDs. Two real bugs were found in it during a
2026-10 session, both of the same class:

- `org.system76.CosmicFiles/CosmicEdit/CosmicPlayer.desktop` — the actual
  files are `com.system76.*`; the defaults silently fell through to whatever
  xdg guessed.
- `zeditor.desktop` — the real file is `dev.zed.Zed.desktop` (and the role
  referencing it was dead anyway).

The failure class is the point: a typo'd, misremembered, or uninstalled
desktop ID produces **no error anywhere** — eval, build, switch and runtime
all stay green, and files simply open in the wrong application (or a
picker). The old file's own TODO said it best: _"refactor this module to
have app selection as host-specific data, making this module generic and
reusable across hosts."_ A naming collision made things worse: the roles
option was `defaultApps` — indistinguishable from the HM MIME map it feeds,
`xdg.mimeApps.defaultApplications`.

## Root Cause

1. **Defaults are policy expressed as free strings with zero validation.**
   Upstream `.desktop` files declare _capability_ (`MimeType=` — what an app
   _can_ open); nothing checked _selection_ (what _should_ open by default).
2. **Eval-time discovery of installed desktop files is impossible in Nix.**
   Desktop files live inside store output paths that do not exist until
   built. Reading them at eval "works" only for packages already built on
   that machine — _store-state-dependent eval_, non-reproducible truth that
   passes locally, fails on CI's fresh store, and lies on a stale one. The
   Nix language additionally blocks constructing output paths from
   derivations, and option _types_ cannot read merged config. Conclusion:
   the candidate set must be **declared**, not discovered — and its
   enforcement must be **post-merge assertions**, not option types.

## Solution Architecture

| Piece                | Role                                                       | Gate                                                   |
| -------------------- | ---------------------------------------------------------- | ------------------------------------------------------ |
| `roleApps`           | **the pick** — per-role options (browser, file-manager, …) | role-name typos fail at eval with suggestions          |
| `roleCandidates`     | **the menu** — registered desktop IDs per role             | unregistered selections fail at eval (**fitness**)     |
| `mimeTypeOverrides`  | **the hatch** — per-MIME re-assertions at plain priority   | values validated against the union of known IDs        |
| `mime-apps-scan.nix` | activation-time scan of the merged map                     | missing desktop files abort the switch (**existence**) |

`mimeApps.nix` is a pure function `{ roleApps }` → MIME-type map; the
craft app modules (wordcraft/pdfcraft/deckcraft) self-register their
document families into it via `lib.mkDefault` (their MIME surface — they
deliberately register **no** role candidates: no role's consumed types fit
them).

### Priority layering

| Layer                                          | Priority        | Example                                                |
| ---------------------------------------------- | --------------- | ------------------------------------------------------ |
| option default (the portable fallback profile) | —               | `roleApps.browser = "helium.desktop"` in `default.nix` |
| app-module claim                               | `lib.mkDefault` | a future browser module claiming the role              |
| host selection                                 | plain           | `hosts/laptop/home.nix`                                |

Two `mkDefault` claims on one role, or two plain assignments from different
modules, fail the merge **loudly, naming both files and both values** —
the claiming contract. The laptop declares all ten selections explicitly;
hosts that declare nothing inherit the fallback profile. Leaving a role
unset in both places is equivalent.

### The seed (user decision 2026-10-20)

Candidates are seeded **module-side, as independent literals** — deliberately
NOT derived from the `roleApps` values — so drift between a role's value
and its candidate registration fails validation. The residual hole (one
typo pasted identically into both strings, same file) is covered by the
activation scan. Rejected alternatives: seeding candidates _from_ the
defaults (tautological — the org.system76 bug lived _in_ the defaults);
host-side-only seed (fresh-host footgun). With the laptop declaring
explicitly, the cross-check returns on the host side: host-authored values
vs module-authored candidates, different files.

## The failure UX tour (real messages)

Role-name typo — the closed schema:

```
error: The option `modules.user.desktop.xdg.roleApps.browesr' does not exist.
Did you mean `modules.user.desktop.xdg.roleApps.browser', …?
```

Unregistered selection — the registry (fitness gate), proven with an
installed-but-unregistered app:

```
Failed assertions:
- xdg.roleApps.browser: "brave.desktop" is not a registered candidate
  (registered for browser: helium.desktop). Register it in
  modules.user.desktop.xdg.roleCandidates.browser or fix the desktop ID.
```

Registration role typo:

```
- xdg.roleCandidates."brower" is not a known role (known roles: browser,
  document-viewer, file-archiver, file-manager, image-viewer, music-player,
  office-suite, text-editor, torrent-client, video-player).
```

Missing desktop file at switch — the existence gate:

```
[xdg-scan] MISSING desktop entry: ghost.desktop (used by MIME types: application/x-test)
[xdg-scan] xdg.mimeApps.defaultApplications reference desktop files that do not exist — aborting switch.
```

## Recipes

**Switch an app for a role (host).** Declare it in `hosts/*/home.nix`:

```nix
modules.user.desktop.xdg.roleApps.browser = "librewolf.desktop";
```

If the app is not yet a registered candidate, the eval fails with the
message above — register it first, in the module that provides the app (or
at host level for raw packages):

```nix
modules.user.desktop.xdg.roleCandidates.browser = [ "librewolf.desktop" ];
```

The one-line registration **is** the escape hatch. There is deliberately no
bypass option: a hatch would recreate the unvalidated path this system
exists to close.

**Ship an app that should own a MIME family (app module).** The craft-app
pattern — self-register the family with `lib.mkDefault` (see
`modules/user/app/{wordcraft,pdfcraft,deckcraft}.nix`), so hosts and the
role mapping can still re-assert anything at plain priority.

**Claim a role from an app module.** `roleApps.<role> = lib.mkDefault
"<id>.desktop"` — wins over the fallback profile, loses to any host plain
assignment, conflicts loudly with another claim.

**Add a new role.** Declare its option in `default.nix` and its mapping
lines in `mimeApps.nix` **together, centrally**. The schema closure is
config-side only: an option injected under `roleApps` from outside merges
but is consumed by nothing — silent dead config, exactly the failure class
this system removes.

**Fresh host.** It inherits the fallback profile. Declare deviations only,
or declare everything like the laptop does.

## Design decisions & rejected alternatives

- **Hybrid gates, not scan-only.** The scan is the "dynamic detection"
  dream — zero registration lines, complete reality coverage — but it is
  invisible to `nix flake check`/CI and has no fitness gate (a
  wrong-but-installed app passes existence). Registry = fitness at eval;
  scan = existence at switch. Orthogonal, both shipped.
- **`mime-apps-scan.nix` vs `desktop-entry-guard.nix`.** The guard _prunes_
  dangling handwritten entries at activation; the scan is a _gate_ that
  never deletes and vetoes the switch. Different bug classes, different
  verbs, deliberately separate modules.
- **`mimeApps.nix` keeps its name.** It _is_ the `xdg.mimeApps` value,
  mirroring `portal.nix` ↔ `xdg.portal`. The collision was in the option
  names (`defaultApps` → `roleApps`, `extraDefaultApplications` →
  `mimeTypeOverrides`).

## Verification

- `tests/default.nix` runs with `nix flake check`: the pure mapping lock
  (33 role keys) and four validator cases — valid → `[]`, the historical
  org.system76 scenario as the selection-typo fixture (exact message),
  registration role typo, unregistered override.
- The real config evaluates with **0 failing assertions**.
- The scan was proven against a built activation package: 13/13 desktop
  IDs resolve in the live environment; a ghost ID aborts with the message
  above.

## File map

| File                                                  | What it is                                                                                            |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `modules/user/desktop/xdg/default.nix`                | options (`roleApps`, `roleCandidates`, `mimeTypeOverrides`), fallback profile, seed, assertion wiring |
| `modules/user/desktop/xdg/role-validation.nix`        | the pure three-gate validator                                                                         |
| `modules/user/desktop/xdg/mimeApps.nix`               | generic MIME mapping (function of `roleApps`)                                                         |
| `modules/user/desktop/xdg/mime-apps-scan.nix`         | activation-time existence gate                                                                        |
| `hosts/laptop/home.nix`                               | the laptop's explicit selections + scan enable                                                        |
| `modules/user/app/{wordcraft,pdfcraft,deckcraft}.nix` | MIME-family self-registration pattern                                                                 |
