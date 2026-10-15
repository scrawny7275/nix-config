#!/usr/bin/env bash
# ci/scan-history.sh — generic secret hygiene scan of the full git object store.
# PUBLIC-SAFE by design: only generic credential classes, never repo-specific tokens
# (repo-specific checks live in the private pre-push hook).
#
#   1. sensitive-path scan over ALL history filenames
#   2. generic credential-pattern scan over ALL objects (blobs+commits), incl.
#      unreachable/rescue objects so nothing can hide in the shadow store
#
# exit 0 = clean; exit 1 = findings (printed redacted).
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"
fail=0

echo '--- sensitive-path scan (all history filenames) ---'
paths=$(
  git log --all --name-only --format='' \
    | sort -u \
    | grep -iE '\.(ovpn|cer|der|key|p12|pfx|jks|keystore|agekey)$|(^|/)(id_rsa|id_ed25519|id_dsa|id_ecdsa|credentials)(\.|$)|(^|/)certs?/' \
    | grep -vE '\.enc$|\.pub$|docs/' || true
)
if [ -n "$paths" ]; then
  echo "$paths"
  fail=1
else
  echo 'ok'
fi

echo '--- generic credential-pattern scan (all objects) ---'
scan_out=$(
  git cat-file --batch-all-objects --batch-check='%(objectname) %(objecttype)' \
    | awk '$2=="blob" || $2=="commit" {print $1}' \
    | git cat-file --batch \
    | rg -a -o -e 'BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY' \
        -e 'github_pat_[A-Za-z0-9_]{20,}' \
        -e 'gh[pousr]_[A-Za-z0-9]{30,}' \
        -e 'gl(pat|rt|dt|so)-[A-Za-z0-9_-]{20,}' \
        -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
        -e 'AKIA[0-9A-Z]{16}' \
        -e 'sk-(ant-|proj-)?[A-Za-z0-9_-]{20,}' \
        -e 'AIza[0-9A-Za-z_-]{30,}' \
        -e 'PrivateKey = [A-Za-z0-9+/]{43}=' \
    || true
)
if [ -n "$scan_out" ]; then
  echo 'FINDINGS (redacted):'
  printf '%s\n' "$scan_out" | sed -E 's/(.{10}).+(.{4})/\1…\2/' | head -20
  fail=1
else
  echo 'ok'
fi

[ "$fail" = 0 ] && echo 'HISTORY-SCAN-CLEAN' || { echo 'HISTORY-SCAN-DIRTY'; exit 1; }
