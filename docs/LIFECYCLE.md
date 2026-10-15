# ~/nix-config/LIFECYCLE.md

## Service Cleanup Checklist

When removing a module:
1. [ ] Identify systemd services: `grep -r "systemd.user.services" module.nix`
2. [ ] Disable services: `systemctl --user disable --now service-name`
3. [ ] Remove generated files: `rm ~/.config/systemd/user/service-name.service`
4. [ ] Remove module from flake.nix
5. [ ] Rebuild: `home-manager switch --flake ~/nix-config#user`
6. [ ] Verify: `systemctl --user status service-name`
