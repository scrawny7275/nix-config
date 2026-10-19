# NTFS dirty-flag runbook (external USB drives)

## Symptom

- File manager (cosmic-files / dolphin / thunar) shows a cryptic error when clicking
  the drive; the partition appears in the sidebar but never mounts.
- Kernel log confirms the cause:

  ```
  $ journalctl -k | grep -i dirty
  ntfs3(sdXN): volume is dirty and "force" flag is not set!
  ntfs3(sdXN): It is recommened to use chkdsk.
  ```

## Cause

The NTFS "dirty" bit is written to disk whenever a volume is detached uncleanly:

- pulling the USB drive out without ejecting first
- Windows "Fast Startup" hibernation on a machine the drive was attached to
- crash / power loss mid-write

The kernel `ntfs3` driver refuses read-write mounts of dirty volumes unless the
`force` mount option is passed — and udisks2 (the D-Bus layer every file manager
calls on click) never passes it. The kernel docs explicitly mark `force` as
*"Not recommended for use"*, so this repo deliberately configures **no `force`
anywhere** (neither global defaults nor per-device). The correct fix is to clear
the flag on the volume, not to silence the warning.

## Recovery (per dirty partition)

Identify the partition by **LABEL** — device letters are assigned per plug and
shift when USB devices cycle (in the 2026-10 incident DAVID moved sda1 → sdb1
within a day). Never copy a device letter from an old log or command:

```
$ lsblk -o NAME,LABEL,FSTYPE,SIZE,MOUNTPOINTS
```

```
sudo ntfsfix -n /dev/sdXN   # read-only preview: shows what would be fixed
sudo ntfsfix -d /dev/sdXN   # repair + journal reset + clear dirty flag
```

Semantics (ntfsfix(8)):

- `-d` clears the dirty flag **only if the volume can be fixed and mounted**;
  if it cannot be fixed, the flag is deliberately left set (loud failure).
- **NEVER run plain `ntfsfix` (without `-d`)** — plain mode *sets* the dirty
  flag to request a Windows chkdsk at next mount. Repeated plain runs keep the
  volume unmountable and re-dirty volumes being fixed; this actually happened
  in this machine's shell history.
- ntfsfix is **NOT** a Linux chkdsk. If `-d` reports the volume cannot be
  fixed, in order:
  1. Rescue read-only first (rescue mount below, or image the volume with
     `ntfsclone` from the same ntfs3g package) — zero risk, preserves options.
  2. Data exists elsewhere → `mkfs.ntfs -L <label> /dev/sdXN`, move on.
  3. Only copy, too big to rescue → a one-time `chkdsk /f` on any Windows
     machine is the only true repair; borrowing one beats living in rescue
     mode.
  4. Otherwise the volume can stay in rescue mode indefinitely: reads work,
     click-mount does not — that is the loud failure doing its job.

## Read-only rescue (data access from a dirty volume)

```
sudo mkdir -p /mnt/rescue
sudo mount -o ro,force -t ntfs3 /dev/sdXN /mnt/rescue
```

`force` here is a conscious one-off, read-only decision made by the operator —
it is intentionally NOT configured system-wide.

## Zombie mounts (entry exists, drive gone)

Symptom: `/run/media/$USER/<label>` (or a file-manager sidebar entry) exists
for a drive that is no longer connected. `ls` into it gives
`Input/output error`; `journalctl -k` floods
`ntfs3(sdXN): failed to read volume ...`; the device is absent from `lsblk`.

These come from manual `sudo mount` workflows (udisks never leaves them) — the
drive was unplugged while still mounted. Costs: journal spam, a dead erroring
entry in file managers, and the pinned old device letter forces replugged
drives onto new letters (DAVID shifted sda1 → sdb1 this way in the 2026-10
incident).

```
sudo umount '/run/media/$USER/<label>'   # add -l if "target is busy"
ls -la '/run/media/$USER/<label>'        # NOW you see the real tmpfs dir
sudo rmdir '/run/media/$USER/<label>'    # only if EMPTY — if not, that data
                                         # is on tmpfs and dies at reboot:
                                         # copy it somewhere real first
```

## Prevention

- Always eject via the file manager (or `udisksctl unmount -b /dev/sdXN`)
  before unplugging the drive.
- On Windows machines the drive visits: disable Fast Startup
  (hibernation marks NTFS volumes dirty).
- After a clean unmount the ntfs3 driver clears the flag itself; with proper
  ejection the cycle is self-sustaining.

## Driver notes

- udisks2 prefers the in-kernel `ntfs3` driver (builtin `ntfs_drivers=ntfs3,ntfs`).
- Verify which driver actually mounted:

  ```
  $ findmnt -no FSTYPE /run/media/$USER/<label>
  ntfs3
  ```

  If it ever shows `fuseblk`, udisks fell back to the ntfs-3g FUSE driver —
  report it, that changes the analysis.

- `ntfs3g` is installed for the `ntfsfix` tool and as a FUSE fallback only;
  it is not expected to be the mounting driver.
