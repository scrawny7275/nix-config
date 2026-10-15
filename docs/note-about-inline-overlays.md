# Important Caveat

This only works if Home Manager manages its own pkgs. If you're using Home Manager as a NixOS module with:

```bash
home-manager.useGlobalPkgs = true;
```

Then nixpkgs.overlays inside Home Manager modules won't work because pkgs is already fixed by NixOS. In that case, overlays must be defined at the NixOS level, or you must set useGlobalPkgs = false (or omit it, defaults to false).

Since your setup has been working with nixpkgs.overlays in modules, you're likely using standalone Home Manager or useGlobalPkgs = false, so the self-contained pattern works perfectly.
