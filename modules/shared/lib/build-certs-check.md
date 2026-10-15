# Check if key-store is ok after build cacerts

```shell-script
# Should show "Java KeyStore" or similar
file ~/.config/nix/cacerts

# Should show a non-zero count (hundreds, since it includes system CAs + private CAs)
keytool -list -keystore ~/.config/nix/cacerts -storepass changeit | grep -c "Entry"

# Should show your private CA somewhere in the list
keytool -list -v -keystore ~/.config/nix/cacerts -storepass changeit | grep -i "employer"
```
