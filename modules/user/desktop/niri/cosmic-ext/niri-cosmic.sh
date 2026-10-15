      set -e

      # Reset failed units
      if command -v systemctl >/dev/null; then
        for unit in $(systemctl --user --no-legend --state=failed --plain list-units | cut -f1 -d' '); do
          partof="$(systemctl --user show -p PartOf --value "$unit")"
          for target in cosmic-session.target graphical-session.target; do
            if [ "$partof" = "$target" ]; then
              systemctl --user reset-failed "$unit"
              break
            fi
          done
        done
      fi

      export XDG_CURRENT_DESKTOP=niri:Cosmic
      export XDG_SESSION_DESKTOP=cosmic
      export XDG_SESSION_TYPE=wayland
      export XCURSOR_THEME="''${XCURSOR_THEME:-Cosmic}"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export GDK_BACKEND=wayland,x11
      export MOZ_ENABLE_WAYLAND=1
      export QT_QPA_PLATFORM="wayland;xcb"
      export QT_AUTO_SCREEN_SCALE_FACTOR=1
      export QT_ENABLE_HIGHDPI_SCALING=1
      export XDG_MENU_PREFIX=cosmic-

      if command -v systemctl >/dev/null; then
        systemctl --user import-environment \
                  XDG_SESSION_TYPE \
                  XDG_CURRENT_DESKTOP \
                  XDG_SESSION_DESKTOP \
                  WAYLAND_DISPLAY \
                  XCURSOR_THEME
      fi

      # Start COSMIC session
      if [[ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        dbus-run-session -- cosmic-session niri
      else
        exec cosmic-session niri
      fi
