# Some Notes about declarative setup of Brave Browser

With Nix for it can be possible perfectly declare:

    ✅ Package installation
    ✅ Extensions via programs.brave.extensions
    ✅ CLI args via commandLineArgs
    ✅ System-level policies via environment.etc

Intent to declarative setup additional preferences:

    - User-state UI preferences
    - Manual one-time setup options

## Quick actions

Access Brave preferences: Open new Brave Tab -> `brave://prefs-internals/`
Access Brave polocies: Open new Brave Tab -> `brave://policy`

Determine current value of an option:

```bash
jq '.brave.new_tab_page.show_stats' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
```

Check if an option is MAC-protected:

```bash
jq --arg path "browser.show_home_button" '
  .protection.macs as $macs |
  ($path | split(".")) as $keys |
  # Traverse the MAC tree matching the path
  reduce $keys[] as $k (.; if . == null then null else .[$k] end) |
  if . then "⛔ PROTECTED (MAC exists)" else "✅ SAFE (No MAC)" end
' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
```

Kill Brave browser instances:

```bash
 killall brave
```

or

```bash
pkill brave
```

## 🧠 Critical Reflection

Making the assumption: "If I can declaratively manage one browser preference, I should manage all of them."

Not all preferences are equal. For example, the home button visibility is a UI preference stored in a mutable JSON blob that Brave actively rewrites. By contrast, extensions or CLI args are installation-time configuration that don't conflict with runtime state.

Nix excels at reproducible infrastructure (packages, extensions, policies, system configs). Browsers are interactive applications with cryptographic integrity checks, session state, and user-driven UI state. Forcing UI prefs into declarative config creates:

    - False reproducibility (MACs break across machines/profiles)
    - Silent failures (values revert without error)
    - Maintenance debt (fighting browser updates)

It can't be extracted or reused MAC values to toggle preferences — they're cryptographic proofs, not static tokens. One path forward could be:

    - Set critical UI prefs manually once, let Brave manage them

## Declare a new Brave preference option

1. Add this line to the module (`default.nix` file) braveSettings attrset:

   ```nix
   braveSettings = {
   # ... your existing settings ...
   "brave.new_tab_page.show_stats" = true; # 🔍 TEST SETTING
   };
   ```

2. Ensure to kill all brave instances:

   If you didn't fully kill all Brave processes (check ps aux | grep brave), the running instance will overwrite your changes on exit.

   Need to fully quit Brave and re-open it to see the changes. Can be used:

   ```bash
     killall brave
   ```

   or

   ```bash
     pkill brave
   ```

## Check Available Brave Preferences

Key names vary by version: Brave sometimes uses brave_news::has_seen_onboarding or ntp::brave_news::has_seen_welcome.

You can discover the exact key by opening `brave://prefs-internals`.

🔍 MAC-Protected/Unprotected options: Brave cryptographically signs preferences it considers "security-sensitive" or "policy-enforced" (homepage, startup URLs, extension state, UI buttons that affect phishing flows). Layout/workflow prefs like vertical tabs and news toggles are left unsigned.

🔐 What is a MAC in Brave Preferences?

There is some settings entries like:

```json
"show_home_button":"F6B8688079AA4C4657C3FEDCF3311348C99CB4907EEC8560CC323E4F37D1EA41",
"show_home_button_encrypted_hash":"djExb67/0X9M8wEXzI4pu9JtjFd4mr0fIG6n8uJAdvwEjm1edmtGUkSMZscuY9HfZZfY"
```

show_home_button: SHA-256 hash of the value + path (integrity check)
show_home_button_encrypted_hash: Encrypted MAC using a profile-specific secret key (authenticity check)

These are **Message Authentication Codes **(MACs) — cryptographic integrity checksums that Brave uses to detect tampering.
MACs use a per-profile cryptographic key stored in your OS keyring (libsecret/KWallet). It can't be reproduce it. Each MAC is computed over the exact value (true vs false). A MAC for true won't validate false. Some implementations include timestamps or session data in the MAC input. Even if you copied a valid MAC, Brave may recompute and overwrite it on next launch.

Brave computes these when it writes a preference, then verifies them on read. If they don't match, Brave may: - Ignore the setting - Revert to default - Log a corruption warning

This breaks the jq approach take it here.

For example, if the script sets `"browser.show_home_button": true` the value is updated, but "protection.macs.browser.show_home_button" still has the old hash (mismatch).

Brave starts up, validates preferences and detects the inconsistency.

This is why browser preference files resist declarative management: it's not just about setting values — also must maintain cryptographic integrity proofs.

So, a practical workaround could be let Brave manage protected MACs settings and set the preference manually once in Brave's UI.

## 🧪 Check the current value of an specific Brave preference

```bash
jq '.brave.new_tab_page.show_stats' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
```

Run this against your Preferences file to see if a path is MAC-protected:

```bash
jq --arg path "browser.show_home_button" '
  .protection.macs as $macs |
  ($path | split(".")) as $keys |
  # Traverse the MAC tree matching the path
  reduce $keys[] as $k (.; if . == null then null else .[$k] end) |
  if . then "⛔ PROTECTED (MAC exists)" else "✅ SAFE (No MAC)" end
' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
```

### Brave Policies

Another thing could be use Brave Policies for anything that can be manage this way. Enterprise policies (in /etc/brave/policies/managed/) bypass the MAC system because they're designed for admin enforcement.

Check if your desired setting exists as an enterprise policy. For verify the full policy list open in a new tab `brave://policy`.
Them add it to the policies Brave file:

```nix
environment.etc."/brave/policies/managed/home-button.json".text = builtins.toJSON {
  # If this policy existed (it doesn't for show_home_button):
  # ShowHomeButton = true;
};
```

(Note: show_home_button is not currently a supported policy — this is illustrative.)

For additional info on Brave group policies, visit the site https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy or simple search it on the web.

## Apply settings

Just run the activation comand after any new setting:

```bash
  home-manager switch --flake ~/nix-config#user
```
