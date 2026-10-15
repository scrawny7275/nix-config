# Register independent files as binary with sops

## 🔍 How to Find Your Age Public Key

Check Your Existing sops-nix Config

```bash
# Look for something like this:
sops = {
  age.keyFile = "$HOME/.config/sops/age/keys.txt";
  # or
  age.sshKeyPaths = [ "$HOME/.ssh/id_ed25519_<identity>" ];
};
```

Extract the public key:

```bash
# If using age key file:
cat ~/.config/sops/age/keys.txt
# Output looks like:
# # created: 2024-01-15T10:30:00Z
# # public key: age1<public-key-fragment>...
# AGE-SECRET-KEY-<private-fragment>...  ← private key (never share)
```

✅ Use the line starting with # public key: age1... — just the age1... part.

## Generate a New Age Key (If You Don't Have One)

```bash
# Install age if needed
nix shell nixpkgs#age -c bash

# Generate a new key pair
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# View the public key
grep "public key" ~/.config/sops/age/keys.txt
# Output: # public key: age1<your-public-key>
```

✅ Copy the age1... string (without the # public key: prefix).

## How to generate the encrypted file

Make sops temporary available inside a nix shell, if not already installed:

```bash
nix-shell -p sops
```

Encrypt the secret file using yout public age key:

```bash
# Encrypt a single file
sops --encrypt --age <age-pubkey> "$f" > "${f}.enc"
```

or

```bash
sops --encrypt \
       --input-type binary \
       --output-type binary \
       --age <age-pubkey> \
       "$f" > "${f}.enc"
```

example:

```bash
nix-shell -p sops --run '
                          AGE_PUB=$(grep "public key" "$HOME/.config/sops/age/keys.txt" | sed "s/.*public key: //")
                          sops --encrypt --input-type binary --output-type binary --age "$AGE_PUB" \
                          ./modules/system/openvpn/secrets/password > ./modules/system/openvpn/secrets/password.enc
                          '
```

<age-pubkey>: age public key — the encryption key that sops-nix uses to encrypt/decrypt secrets.
"$f": path to the file going to be encrypted. Usually isn't desirable to commit/push this file to git, so add it to gitignore.
"${f}.enc": output path name of the encrypted file to generate.

### ✅ Verify It Works (Optional)

After encrypting, test decryption:

```bash
# Should output the original content without prompting (if key is loaded)
sops -d ${f}.enc
```

If you get Panic: failed to load age keys, ensure:

1. Your private key is in ~/.config/sops/age/keys.txt
2. File permissions are 600: chmod 600 ~/.config/sops/age/keys.txt
3. Your sops-nix config points to the correct key path

## How to use the encrypted secret file in nix (with sops-nix)

Register each independent .enc file with sops-nix:

```nix
  # Register each independent .enc file with sops-nix
  sops.secrets = {
    "openvpn/${f}" = {
      sopsFile = ./${f}.enc; # Adjust relative path to the secret
      format = "binary";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
```
