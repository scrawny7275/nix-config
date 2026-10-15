# Sops secrets encryption

1. Make temporary available _sops_

   ```bash
   nix-shell -p sops
   ```

2. Decrypt the File First (If Already Encrypted)
   If the file has already been encrypted, you should decrypt it first before attempting to re-encrypt it. You can do this by running:

   ```bash
   sops -d -i secrets/laptop.yaml
   ```

   This will decrypt the file in place, allowing you to modify its contents.

3. Ensure the File is Unencrypted Before Re-encrypting
   If you want to overwrite the file and re-encrypt it, make sure that there’s no sops metadata present when you attempt to re-encrypt the file. You can remove the metadata manually by clearing the sops section from the file, or by creating a new file and moving the contents there.

   For example:
   1. Remove the sops metadata:
      Open secrets/laptop.yaml and delete the sops section at the top of the file, which might look like this:

      ```yaml
      sops:
        age:
          - recipient: age1rk2nayluj2fz6hrmdpjqhkzuhlgg82ysrze6lpmykw5u9nzpwgcsn244sx
            enc: |
              -----BEGIN AGE ENCRYPTED FILE-----
              ...
              -----END AGE ENCRYPTED FILE-----
      ```

      After removing it, you can re-encrypt the file with:

      ```bash
      sops --config secrets/.sops.yaml -e -i secrets/laptop.yaml
      ```

   2. Or create a fresh file:
      Alternatively, if you don't want to manually edit the existing file, you can create a new unencrypted file and copy the contents into it:

      ```bash
        cp secrets/laptop.yaml secrets/laptop_new.yaml
        sops --config secrets/.sops.yaml -e -i secrets/laptop_new.yaml
      ```

4. Encrypting the File Again
   Once you've removed the metadata or created a fresh file, you should be able to encrypt it again with:

   ```bash
   sops --config secrets/.sops.yaml -e -i secrets/laptop.yaml
   ```

   This command will:
   - Encrypt the file (-e).
   - Modify the file in place (-i), which means it will overwrite the existing file with the re-encrypted content.

5. Editor Mode for Encrypted Files
   If the file is encrypted and you want to modify it, you can use the editor mode instead of directly using -e for encryption:

   ```bash
     sops secrets/laptop.yaml
   ```

   This will open the file in an editor, allowing you to decrypt, edit, and re-encrypt it automatically when you save and close the editor.
