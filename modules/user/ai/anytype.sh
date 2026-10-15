#!/bin/sh
# anytype — thin read-anywhere + sandbox-only-write CLI client over the
# Anytype desktop app's Local API ("curl with rules"; NOT an MCP, not a nix wrap)
# Trial (2026-09-30): every call logged to ${XDG_STATE_HOME:-$HOME/.local/state}/anytype-trial.log
set -eu

BASE="${ANYTYPE_API_BASE:-http://127.0.0.1:31009}"
VER="2025-11-08"
KEY_FILE="${ANYTYPE_API_KEY_FILE:-$HOME/.config/anytype-agent/api-key}"
SANDBOX_ID="${ANYTYPE_SANDBOX_ID:-}"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/anytype-trial.log"

die() { echo "anytype-cli: $*" >&2; exit 2; }

usage="usage: anytype-cli docs | anytype-cli GET /v2/<path> | anytype-cli <POST|PATCH|DELETE> /v2/spaces/<sandbox-id>/<path> ['<json>']
rules:  GET anywhere. POST/PATCH/DELETE only inside the sandbox space (ANYTYPE_SANDBOX_ID).
note:   scoped keys refuse /v1 (403 v1_not_available_for_scoped_keys) — use /v2 routes. Old unscoped keys stay on /v1.
examples:
  anytype-cli GET /v2/spaces
  anytype-cli GET /v2/auth/whoami     # show this key's grants/scopes
  anytype-cli docs                    # app's OpenAPI spec = endpoint discovery (pipe through jq/head)"

[ $# -ge 1 ] || die "$usage"

if [ ! -f "$KEY_FILE" ]; then
  die "no API key at $KEY_FILE — sops template renders it; add api_keys/anytype to secrets then home-manager switch"
fi

KEY=$(cat "$KEY_FILE")
mkdir -p "$(dirname "$LOG")"

request() { # $1=METHOD $2=path $3=optional body
  if [ -n "${3:-}" ]; then
    curl -sS -m 30 -w '\n%{http_code}' -X "$1" \
      -H "Authorization: Bearer $KEY" -H "Anytype-Version: $VER" \
      -H 'Content-Type: application/json' -d "$3" "$BASE$2"
  else
    curl -sS -m 30 -w '\n%{http_code}' -X "$1" \
      -H "Authorization: Bearer $KEY" -H "Anytype-Version: $VER" \
      -H 'Accept: application/json' "$BASE$2"
  fi
}

run() { # $1=METHOD $2=path $3=optional body
  RESP=$(request "$1" "$2" "${3:-}") || die "cannot reach $BASE — is the Anytype app running?"
  CODE=${RESP##*$'\n'}
  printf '%s\n' "${RESP%$'\n'*}"
  printf '%s %s %s -> %s\n' "$(date -Is)" "$1" "$2" "$CODE" >> "$LOG"
  case "$CODE" in 2*|3*) return 0 ;; *) echo "anytype-cli: HTTP $CODE" >&2; return 1 ;; esac
}

if [ "$1" = docs ]; then
  for p in /v2/docs/openapi.json /v1/docs/openapi.json /docs/openapi.json; do
    if RESP=$(request GET "$p" 2>/dev/null); then
      CODE=${RESP##*$'\n'}
      [ "$CODE" = 200 ] && { printf '%s\n' "${RESP%$'\n'*}"; printf '%s GET %s -> 200\n' "$(date -Is)" "$p" >> "$LOG"; exit 0; }
    fi
  done
  die "cannot fetch OpenAPI spec from $BASE — is Anytype running (and the key valid)?"
fi

[ $# -ge 2 ] || die "$usage"
METHOD=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
case "$METHOD" in
  GET) ;;
  POST|PATCH|DELETE)
    [ -n "$SANDBOX_ID" ] || die "writes disabled until ANYTYPE_SANDBOX_ID is set (module bootstrap)"
    case "$2" in
      */spaces/"$SANDBOX_ID"*|*/spaces/"$SANDBOX_ID") ;;   # inside sandbox space
      *) die "non-GET allowed only inside sandbox space $SANDBOX_ID (got: $2)" ;;
    esac ;;
  *) die "invalid method '$1' (GET | POST | PATCH | DELETE)" ;;
esac
if [ "$METHOD" = GET ] || [ "$METHOD" = DELETE ]; then
  run "$METHOD" "$2" ""
else
  [ $# -ge 3 ] || die "$usage"
  run "$METHOD" "$2" "$3"
fi
