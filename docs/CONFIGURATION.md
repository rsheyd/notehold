# Configuring Notehold

Notehold defaults to:

- Backup destination: `~/Backups/Apple Notes`
- Backup interval: 10 days
- Automatic cleanup: enabled

Rerun `notehold install` with one of the settings below to change it. Settings you do not supply are preserved.

## Backup destination

Create the destination first, then install with its path:

```sh
BACKUP_DIR="$HOME/path/to/your/backup-folder" notehold install
```

Changing the destination does not move or delete existing archives. Afterward, run `notehold backup` and confirm that the new folder contains a ZIP and adjacent `.sha256` file.

For protection from loss of the Mac, choose an external drive or locally downloaded cloud-synced folder. Confirm cloud backups appear on another device or the provider's website; Notehold verifies local files but cannot verify that cloud upload completed.

## Backup schedule

Set the minimum days between scheduled backups:

```sh
BACKUP_INTERVAL_DAYS=7 notehold install
```

The background job still checks daily and at login. `notehold backup` always creates a backup immediately.

## Automatic cleanup

Cleanup is enabled by default. It keeps the newest backup and recovery points nearest 10, 30, 90, 180, and 365 days old. Redundant verified ZIP and checksum pairs are moved to the Mac Trash, never permanently deleted.

Disable cleanup to retain every completed archive:

```sh
AUTO_CLEANUP=false notehold install
```

Preview what the current policy would move:

```sh
notehold retention preview
```

The newest archive, incomplete pairs, invalid checksum metadata, and archives that fail checksum verification are never moved.

[Return to the Notehold README](../README.md)
