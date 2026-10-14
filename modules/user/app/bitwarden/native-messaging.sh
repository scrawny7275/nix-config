#!/usr/bin/env bash
# Bitwarden Desktop <-> browser native messaging bridge, fully dynamic.
#
# Discovers installed browsers (WebBrowser .desktop entries), classifies them
# (mozilla / chromium), finds their user data dirs by probing, checks for the
# Bitwarden extension, and writes com.8bit.bitwarden.json manifests with a
# `path` key pointing at a copy of desktop_proxy shipped by the currently
# running bitwarden-desktop.
#
# Browsers that the Bitwarden app itself manages (it writes their manifests on
# startup) are left untouched, so this module never fights the app.
#
# Everything is probe-driven: no browser-name -> data-dir dictionaries.
# Set BW_NM_DRY_RUN=1 to print actions without writing anything.

set -uo pipefail

BW_EXT_ID_FF="{446900e4-71c2-419f-a6a7-df9c091e268b}"
BW_EXT_ID_CR="nngceckbapebfimnlniiiahkandclblb"
MANIFEST_NAME="com.8bit.bitwarden.json"
PROXY_NAME=".bitwarden_desktop_proxy"
DRY_RUN="${BW_NM_DRY_RUN:-}"

# Chrome Web Store ids Bitwarden's manifest generator allows by default.
CHROMIUM_ORIGINS=(
  "chrome-extension://nngceckbapebfimnlniiiahkandclblb/"
  "chrome-extension://hccnnhgbibccigepcmlgppchkpfdophk/"
  "chrome-extension://jbkfoedolllekgbhcbcoahefnbanhhlh/"
  "chrome-extension://ccnckbpmaceehanjmeomladnmlffdjgn/"
)

# Data dirs the Bitwarden app itself writes manifests into (observed in
# app.log: it creates .app.bw.socket listeners in exactly these). The app owns
# them; we must not clobber or race it.
app_owned_paths() {
  printf '%s\n' \
    "$HOME/.mozilla" \
    "$HOME/.config/google-chrome" \
    "$HOME/.config/chromium" \
    "$HOME/.config/microsoft-edge" \
    "$HOME/.config/vivaldi" \
    "$HOME/.config/BraveSoftware" \
    "$HOME/.var/app/com.google.Chrome" \
    "$HOME/.var/app/com.google.ChromeDev" \
    "$HOME/.var/app/com.google.Chrome.Beta" \
    "$HOME/.var/app/org.chromium.Chromium" \
    "$HOME/.var/app/com.microsoft.Edge" \
    "$HOME/.var/app/org.mozilla.firefox"
}

is_app_owned() {
  local p="$1" root
  while IFS= read -r root; do
    [ -z "$root" ] && continue
    if [ "$p" = "$root" ]; then
      return 0
    fi
    case "$p" in
      "$root"/*) return 0 ;;
    esac
  done < <(app_owned_paths)
  return 1
}

log() {
  [ -n "${BW_NM_QUIET:-}" ] || printf '[bitwarden-nm] %s\n' "$*"
}

# ---------------------------------------------------------------------------
# 1. Discover installed browsers via WebBrowser .desktop entries
# ---------------------------------------------------------------------------
discover_browsers() {
  # -L: application dirs are often reached through symlink chains
  # (~/.nix-profile -> ~/.local/state/nix/profiles/profile -> store).
  local dirs=(
    "$HOME/.nix-profile/share/applications"
    "$HOME/.local/share/applications"
    "/etc/profiles/$USER/share/applications"
    "/run/current-system/sw/share/applications"
  )
  local d f exe first
  for d in "${dirs[@]}"; do
    [ -d "$d" ] || continue
    while IFS= read -r -d '' f; do
      # Strict Categories= check (substring matches catch e.g. cosmic-settings)
      grep -q '^Categories=.*WebBrowser' "$f" 2>/dev/null || continue
      # First whitespace-delimited token of the first Exec= line.
      # (activation runs with a minimal PATH: no awk; and `read` inside an
      # `IFS= read` loop inherits empty IFS, so use parameter expansion)
      exe=$(grep '^Exec=' "$f" 2>/dev/null | head -1 | sed -e 's/^Exec=//' -e 's/ %[A-Za-z@:]*//g')
      exe=${exe%% *}
      [ -n "$exe" ] || continue
      case "$exe" in
        /*) first="$exe" ;;
        *)
          # Activation may run with a sparse PATH; probe the usual profile
          # locations directly before falling back to command -v.
          first=""
          for c in "$HOME/.nix-profile/bin/$exe" "/etc/profiles/$USER/bin/$exe" "/run/current-system/sw/bin/$exe"; do
            if [ -x "$c" ]; then first="$c"; break; fi
          done
          if [ -z "$first" ]; then
            first=$(command -v "$exe" 2>/dev/null) || continue
          fi
          ;;
      esac
      [ -n "$first" ] && printf '%s\n' "$first"
    done < <(find -L "$d" -maxdepth 1 -name '*.desktop' -print0 2>/dev/null)
  done | sort -u
}

# Resolve a browser binary to its nix store package dir, or empty.
# Handles makeBinaryWrapper ELFs (readlink -f lands inside the package) and
# non-package launchers (e.g. Helium's bwrap script -> not attributable).
package_dir_of() {
  local rl dir
  rl=$(readlink -f "$1" 2>/dev/null) || return 0
  dir=$(dirname "$rl")
  case "$dir" in
    /nix/store/*/*) ;;
    *) return 0 ;;  # store file itself (bwrap) or non-nix install
  esac
  # /nix/store/<hash-name-version>/...
  # (path split on "/": "" nix store <pkg> ... -> fields 1-4)
  local pkg
  pkg=$(printf '%s' "$dir" | cut -d/ -f1-4)
  case "$pkg" in
    /nix/store/*-*) printf '%s\n' "$pkg" ;;
  esac
}

# Identity key for a store path (e.g. from compatibility.ini): strip the nix
# prefix, hash, and version suffix so profile entries written by older
# versions of the same browser still match the installed one.
pkg_key() {
  # Accepts a full store path; extract the package part first.
  local pkg
  pkg=$(printf '%s' "$1" | cut -d/ -f1-4)
  basename "$pkg" | sed -e 's/^[a-z0-9]*-//' -e 's/-[0-9][0-9A-Za-z.+_-]*$//'
}

# ---------------------------------------------------------------------------
# 2. Locate the desktop_proxy binary of the bitwarden-desktop the system
#    actually runs (not merely the newest one left in the store).
# ---------------------------------------------------------------------------
find_proxy() {
  local cand rl d found
  for cand in "/run/current-system/sw/bin/bitwarden" "$HOME/.nix-profile/bin/bitwarden"; do
    [ -x "$cand" ] || continue
    rl=$(readlink -f "$cand" 2>/dev/null) || continue
    d=$(dirname "$rl")
    if [ -x "$d/libexec/desktop_proxy" ]; then
      printf '%s\n' "$d/libexec/desktop_proxy"
      return 0
    fi
  done
  # Legacy fallback: newest bitwarden-desktop main package dir in the store.
  found=$(find /nix/store -maxdepth 1 -type d -regex '.*/[a-z0-9]*-bitwarden-desktop-[0-9.][0-9A-Za-z.]*' 2>/dev/null | sort -V | tail -1)
  [ -n "$found" ] && [ -x "$found/libexec/desktop_proxy" ] && printf '%s\n' "$found/libexec/desktop_proxy"
}

# ---------------------------------------------------------------------------
# 3. Mozilla-family: find profiles.ini files, derive UAppData (nearest hidden
#    directory ancestor), attribute to an installed browser via
#    compatibility.ini -> store path identity, gate on the extension xpi.
# ---------------------------------------------------------------------------
nearest_dot_ancestor() {
  local d
  d=$(dirname "$1")
  while [ "$d" != "$HOME" ] && [ "$d" != "/" ]; do
    case "$(basename "$d")" in
      .*) printf '%s\n' "$d"; return 0 ;;
    esac
    d=$(dirname "$d")
  done
  return 1
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

write_manifest() {
  # $1 = NM dir, $2 = family (mozilla|chromium)
  local nm="$1" family="$2" proxy="$3" path_esc manifest
  mkdir -p "$nm"
  if [ -n "$DRY_RUN" ]; then
    log "WOULD write $nm/$MANIFEST_NAME + copy proxy ($family)"
    return 0
  fi
  cp -f "$proxy" "$nm/$PROXY_NAME"
  chmod 755 "$nm/$PROXY_NAME"
  path_esc=$(json_escape "$nm/$PROXY_NAME")
  if [ "$family" = mozilla ]; then
    manifest=$(printf '{
  "name": "com.8bit.bitwarden",
  "description": "Bitwarden desktop <-> browser bridge",
  "path": "%s",
  "type": "stdio",
  "allowed_extensions": ["%s"]
}' "$path_esc" "$BW_EXT_ID_FF")
  else
    manifest=$(printf '{
  "name": "com.8bit.bitwarden",
  "description": "Bitwarden desktop <-> browser bridge",
  "path": "%s",
  "type": "stdio",
  "allowed_origins": [
    "%s",
    "%s",
    "%s",
    "%s"
  ]
}' "$path_esc" "${CHROMIUM_ORIGINS[@]}")
  fi
  printf '%s\n' "$manifest" > "$nm/$MANIFEST_NAME"
  log "wrote $nm/$MANIFEST_NAME ($family)"
}

main() {
  local proxy
  proxy=$(find_proxy)
  if [ -z "$proxy" ]; then
    log "WARNING: bitwarden-desktop desktop_proxy not found; skipping native messaging setup"
    return 0
  fi
  log "proxy: $proxy"

  # --- collect installed mozilla-family browser identity keys --------------
  local -a bin_names=() bin_keys=()
  local bin pkg key
  while IFS= read -r bin; do
    [ -z "$bin" ] && continue
    pkg=$(package_dir_of "$bin")
    [ -z "$pkg" ] && continue
    # mozilla-family iff the package ships application.ini
    if [ -n "$(find "$pkg" -maxdepth 3 -name application.ini -print -quit 2>/dev/null)" ]; then
      key=$(pkg_key "$pkg")
      bin_names+=("$(basename "$bin")")
      bin_keys+=("$key")
    fi
  done < <(discover_browsers)

  # --- mozilla-family data dirs (profiles.ini census) ----------------------
  local pini uapp compatfile storepath ckey matched name i
  while IFS= read -r -d '' pini; do
    uapp=$(nearest_dot_ancestor "$pini") || { log "skip (no hidden data dir): $pini"; continue; }
    if is_app_owned "$uapp"; then
      log "skip (app-managed): $uapp"
      continue
    fi
    # attribute to an installed browser via compatibility.ini store references
    matched=""
    while IFS= read -r -d '' compatfile; do
      while IFS= read -r storepath; do
        [ -n "$storepath" ] || continue
        ckey=$(pkg_key "$storepath")
        for i in "${!bin_keys[@]}"; do
          if [ "$ckey" = "${bin_keys[$i]}" ]; then
            matched="${bin_names[$i]}"
            break 2
          fi
        done
      done < <(grep -hE '^(LastPlatformDir|LastAppDir)=' "$compatfile" 2>/dev/null | cut -d= -f2-)
    done < <(find "$uapp" -maxdepth 4 -name compatibility.ini -print0 2>/dev/null)
    if [ -z "$matched" ]; then
      log "skip (no installed browser claims it): $uapp"
      continue
    fi
    if [ -z "$(find "$uapp" -maxdepth 4 -name "$BW_EXT_ID_FF.xpi" -print -quit 2>/dev/null)" ]; then
      log "skip (no Bitwarden extension): $matched -> $uapp"
      continue
    fi
    write_manifest "$uapp/native-messaging-hosts" mozilla "$proxy"
    log "linked $matched (mozilla) -> $uapp/native-messaging-hosts"
  done < <(find "$HOME" -maxdepth 6 \
      \( -name .cache -o -name .nix-profile -o -name .local -o -name node_modules \
         -o -name .git -o -name snap -o -name Steam \) -prune \
      -o -type f -name profiles.ini -print0 2>/dev/null)

  # --- chromium-family config dirs (Local State census) --------------------
  # Attribution note: chromium config dirs carry no store-path identity, so
  # any non-app-owned chromium dir with the extension installed gets a
  # manifest. Stale dirs of uninstalled browsers would keep their manifest
  # until removed manually - harmless but noted here.
  local -a confs=()
  local f conf
  while IFS= read -r -d '' f; do
    confs+=("$(dirname "$f")")
  done < <(find "$HOME/.config" "$HOME/.var/app" -maxdepth 4 \
      \( -name .cache -o -name .git \) -prune \
      -o -type f -name 'Local State' -print0 2>/dev/null)
  for conf in "${confs[@]}"; do
    if is_app_owned "$conf"; then
      log "skip (app-managed): $conf"
      continue
    fi
    if [ -z "$(find "$conf" -maxdepth 3 -type d -name "$BW_EXT_ID_CR" -print -quit 2>/dev/null)" ]; then
      log "skip (no Bitwarden extension): $conf"
      continue
    fi
    write_manifest "$conf/NativeMessagingHosts" chromium "$proxy"
    log "linked chromium dir -> $conf/NativeMessagingHosts"
  done
}

main
