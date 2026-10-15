#!/usr/bin/env bash
# ci/verify.sh — structural gates for the public surface of this flake.
# Progressive: eval/interlock gates activate once the flake scaffold exists
# (pre-scaffold replay-era trees carry no flake.nix and are skipped loudly).
# (Override-mode builds need the private input and stay LOCAL-only by design.)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

scaffolded=0
if [ -f flake.nix ]; then
  scaffolded=1
fi

echo '--- stub integrity ---'
if [ -f share/private-stub/values.nix ]; then
  git ls-files --error-unmatch share/private-stub/values.nix >/dev/null
  grep -q '^  real = false;' share/private-stub/values.nix
  echo 'ok: stub tracked and real=false'
else
  echo 'SKIP: no employer stub in this tree (pre-security era)'
fi

echo '--- flake.lock hygiene ---'
if [ -f flake.lock ] && [ "$scaffolded" = 1 ]; then
  python3 - <<'EOF'
import json, sys
d = json.load(open('flake.lock'))
bad = []
def walk(x):
    if isinstance(x, dict):
        p = x.get('path')
        if isinstance(p, str) and p.startswith('/'):
            bad.append(p)
        for v in x.values(): walk(v)
    elif isinstance(x, list):
        for v in x: walk(v)
walk(d)
sys.exit('FAIL: absolute paths in flake.lock: %s' % bad if bad else 0)
EOF
  echo 'ok: no absolute paths in flake.lock'
else
  echo 'SKIP: no flake.lock in this tree (pre-scaffold era)'
fi

echo '--- stranger-mode eval: system ---'
if [ "$scaffolded" = 1 ]; then
  nix eval .#nixosConfigurations.laptop.config.system.build.toplevel.drvPath >/dev/null
  nix eval .#nixosConfigurations.laptop.config.modules.private.enable | grep -qx false
  echo 'ok'
  echo '--- stranger-mode eval: home ---'
  nix eval .#homeConfigurations.user.config.home.username | grep -qx '"user"'
  echo 'ok'
  echo '--- negative interlock: enable-without-override must fail loudly ---'
  INTERLOCK_ERR="$(mktemp)"
  if nix eval --expr '
    let f = builtins.getFlake (toString ./.); in
    (f.inputs.stable.lib.nixosSystem {
      specialArgs.inputs = f.inputs;
      modules = [ ./hosts/laptop/system.nix { modules.private.enable = true; } ];
    }).config.system.build.toplevel.drvPath' 2>"$INTERLOCK_ERR" >/dev/null; then
    echo 'FAIL: private input enabled against stub evaluated without error'
    rm -f "$INTERLOCK_ERR"; exit 1
  fi
  grep -q 'private.*input is the public stub' "$INTERLOCK_ERR" && rm -f "$INTERLOCK_ERR"
  echo 'ok: interlock fired with expected message'
else
  echo 'SKIP: no flake scaffold in this tree (pre-scaffold era) — secrets/history gates still apply'
fi

echo 'VERIFY-OK'
