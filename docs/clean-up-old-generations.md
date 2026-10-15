# 🧹 Cleaning Up Old Generations

Over time, old generations of your Home Manager config pile up. You can prune them with:

```shell-script
sudo nix-collect-garbage -d
```

Cleanup user-space packages and dependencies (same command without `sudo`)

```shell-script
nix-collect-garbage -d
```

Finally, need to rebuild the system wide configs and home manager for have a single generation after the clen-up.
Run first system-wide

```shell-script
sudo nixos-rebuild switch --flake ~/nix-config#laptop
```

Then, user-space

```shell-script
home-manager switch --flake .#<user-name>
```

This deletes old generations and frees disk space.
