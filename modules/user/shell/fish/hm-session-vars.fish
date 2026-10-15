# modules/user/shell/fish/hm-session-vars.fish
# Import Home Manager session variables into Fish
set -l hm_session_vars ~/.nix-profile/etc/profile.d/hm-session-vars.sh

if test -f $hm_session_vars
  while read -l line
    string match -qr '^\s*export\s+' -- $line; or continue
    set -l stmt (string replace -r '^\s*export\s+' '' -- $line)
    set -l parts (string split -m 1 '=' -- $stmt)
    set -l varname (string trim -- $parts[1])
    set -l value $parts[2]
    set value (string trim -c '"' -- $value)
    set value (string trim -c "'" -- $value)
    set -gx $varname "$value"
  end < $hm_session_vars
end
