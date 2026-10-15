# Create symblink from host hardawre-configuration.nix in repo

## Remove broken symlink

```bash
sudo rm -f /etc/nixos/hardware-configuration.nix
```

## Regenerate the file

```bash
sudo nixos-generate-config
```

or

```bash
sudo nixos-generate-config --root /
```

or

```bash
sudo nixos-generate-config --dir /etc/nixos/
```

## Fix ownership

```bash
sudo chown $USER:$(id -gn) /etc/nixos/hardware-configuration.nix
```

## Recreate symlink

```bash
sudo ln /etc/nixos/hardware-configuration.nix -sf ~/nix-config/hosts/laptop/hardware-configuration.nix
```

## Verify end-to-end resolution

```bash
ls -la /etc/nixos/hardware-configuration.nix
```
