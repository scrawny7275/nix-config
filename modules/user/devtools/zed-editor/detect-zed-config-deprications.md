# How to Detect Deprecations Yourself (No Guesswork)

1. Zed's Runtime Log: Open Ctrl/Cmd+Shift+P → zed: open log. Filter for deprecated or settings. Zed prints exact key paths and migration hints at startup. 2. Home Manager Trace: Run home-manager switch --show-trace 2>&1 | grep -i "zed\|deprecated". The HM module validates JSON structure but not Zed's internal schema—runtime warnings come from Zed itself. 3. Source Schema: Check pkgs.zed-editor or the Zed repo's crates/zed/src/settings.rs for the authoritative schema. Keys not present there are deprecated.
