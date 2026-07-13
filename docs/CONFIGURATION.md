# Configuring Notehold

Notehold defaults to `~/Backups/Apple Notes`, creates a backup when the newest successful archive is at least 10 days old, and automatically moves redundant older backups to the Mac Trash. Rerun `notehold install` with the settings below to change those defaults. Settings you do not supply are preserved.

The examples use the installed `notehold` command. During the first installation from a clone, use `notehold/notehold` instead; from an extracted release, use `./notehold`.

## Backup destination

The default destination is stored on the same Mac as the Notes database. It can help with accidental changes to Notes, but it does not protect against loss, theft, or failure of the Mac's storage. For better protection, use a folder that is copied off the Mac—for example, a locally synced Google Drive, Dropbox, OneDrive, or iCloud Drive folder—or include the destination in another backup system such as Time Machine.

`BACKUP_DIR` is the local path where Notehold writes archives. To select a destination, create the folder first and then run:

```sh
BACKUP_DIR="$HOME/Library/CloudStorage/Dropbox/Backups/Apple Notes" \
  notehold install
```

Use the actual path on your Mac rather than copying this example unchanged. You can drag a folder from Finder into Terminal to insert its full path. Cloud providers commonly appear under `~/Library/CloudStorage`, although the exact path depends on the provider and account. If an explicitly selected folder does not exist or is unavailable, the installer stops instead of silently creating a possibly mistyped path.

Make sure the destination remains downloaded locally. After creating a test backup, confirm that its ZIP and checksum appear on another device or on the provider's website. Cloud sync should not be the only copy when stronger protection is needed, because deletions and corruption can sync too.

### Change the backup destination

Changing the destination does not move or delete existing archives. They remain in the old folder unless you copy them yourself.

1. Create or choose the new folder. If it is cloud-synced, make sure it is available locally.
2. Rerun the installer with the new path:

   ```sh
   BACKUP_DIR="$HOME/path/to/your/new-backup-folder" \
     notehold install
   ```

3. Create a backup in the new destination:

   ```sh
   notehold backup
   ```

4. Confirm that the new folder contains a dated `.zip` file and its adjacent `.zip.sha256` file. For a cloud destination, also confirm that both files finish syncing.

Installed manual commands and scheduled backups both use the destination recorded by `notehold install`. An environment value supplied directly to a manual command overrides the installed value for that one run.

## Backup schedule

The default backup frequency is every 10 days. `BACKUP_INTERVAL_DAYS` sets the minimum number of days between successful backups. Use a positive whole number when installing. For example, to back up every 7 days:

```sh
BACKUP_INTERVAL_DAYS=7 notehold install
```

The LaunchAgent still checks once per day and at login; this setting controls when that check considers the backup stale. A backup might run later than the exact interval if the Mac was shut down, the user was logged out, or the destination was unavailable.

Rerun the installer with a new value whenever you want to change the persistent schedule:

```sh
BACKUP_INTERVAL_DAYS=14 notehold install
```

`notehold backup` always creates a backup regardless of this interval.

## Automatic cleanup

Automatic cleanup is enabled by default. To retain every completed archive indefinitely instead, disable it when installing:

```sh
AUTO_CLEANUP=false notehold install
```

Automatic cleanup runs only after a new archive passes all backup and integrity checks. It retains the most recent backup and recovery points nearest 10, 30, 90, 180, and 365 days old. Because the Mac may be asleep or the destination unavailable on a target date, these are approximate recovery points rather than exact guarantees.

Cleanup asks Finder to move redundant ZIP and checksum pairs to the Mac Trash. It never falls back to permanent deletion. The files remain recoverable until Trash is emptied, but removing them from a cloud-synced destination will normally sync that removal to the cloud provider. Finder may ask for permission the first time cleanup runs.

Preview the policy against your existing archives at any time:

```sh
notehold retention preview
```

Incomplete pairs, invalid checksum metadata, the most recent archive, and any archive that fails checksum verification immediately before cleanup are never moved. Every decision is logged. If Finder refuses the move or only part of a pair moves, cleanup reports an error and requires manual attention rather than permanently deleting anything.

[Return to the Notehold README](../README.md)
