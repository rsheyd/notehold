# Apple Notes backup

Apple Notes Backup creates dated ZIP archives of your complete local Notes database. It checks once a day and after login, and by default creates a new backup when the latest successful one is at least 10 days old.

Archives go to `~/Backups/Apple Notes` by default. You can instead use an external drive or a folder synced by Dropbox, Google Drive, OneDrive, or iCloud Drive.

## Contents

- [Why use this?](#why-use-this)
- [Quick start](#quick-start)
- [Choose a backup destination](#choose-a-backup-destination)
- [Change the backup destination](#change-the-backup-destination)
- [Change the backup frequency](#change-the-backup-frequency)
- [Optional automatic cleanup](#optional-automatic-cleanup)
- [Files and locations](#files-and-locations)
- [How a backup works](#how-a-backup-works)
- [Sleeping, shutdown, and failures](#sleeping-shutdown-and-failures)
- [Permissions](#permissions)
- [Manual commands](#manual-commands)
- [Restoring a backup](#restoring-a-backup)
- [Reload or uninstall](#reload-or-uninstall)

## Why use this?

iCloud keeps Notes synchronized across devices, but synchronization is not the same as keeping independent, dated backups. An accidental edit or deletion can sync to every device. This project gives you ordinary ZIP files that you can inspect, copy, and verify without a proprietary restore tool or repository password.

For protection from loss or failure of the Mac itself, store the archives somewhere that is copied off the Mac, such as an external drive or a cloud-synced folder. The script verifies each local ZIP and checksum, but it cannot confirm that a cloud provider finished uploading it.

## Quick start

1. Give `/bin/bash` Full Disk Access under **System Settings > Privacy & Security > Full Disk Access**. This allows the background job to read the protected Notes database.
2. From this repository, run:

   ```sh
   ./scripts/install-launchagent.sh
   ```

3. Create the first backup:

   ```sh
   ./scripts/backup-apple-notes.sh --force
   ```

4. Look for the new ZIP and its `.sha256` checksum file in `~/Backups/Apple Notes`.

The installer creates the default destination when needed, installs the daily background job, loads it, and prints a short summary of the active destination, frequency, cleanup setting, and retained recovery points. It stops with an explanation if another LaunchAgent already points to the same backup script, preventing duplicate scheduled checks. The first backup can be large and may take a while. Notes closes briefly so the database can be archived consistently, then reopens if it was open before the backup began.

## Choose a backup destination

The default destination is stored on the same Mac as the Notes database. It can help with accidental changes to Notes, but it does not protect against loss, theft, or failure of the Mac's storage. For better protection, use a folder that is copied off the Mac—for example, a locally synced Google Drive, Dropbox, OneDrive, or iCloud Drive folder—or include the destination in another backup system such as Time Machine.

`BACKUP_DIR` is the local path where the script writes archives. To select a destination during installation, create the folder first and then pass its path to the installer:

```sh
BACKUP_DIR="$HOME/Library/CloudStorage/Dropbox/Backups/Apple Notes" \
  ./scripts/install-launchagent.sh
```

Use the actual path on your Mac rather than copying this example unchanged. You can drag a folder from Finder into Terminal to insert its full path. Cloud providers commonly appear under `~/Library/CloudStorage`, although the exact path depends on the provider and account. If an explicitly selected folder does not exist or is unavailable, the installer stops and asks you to choose or create it instead of silently creating a possibly mistyped path.

Make sure the destination remains downloaded locally. After creating a test backup, confirm that its ZIP and checksum appear on another device or on the provider's website. Cloud sync should not be the only copy when stronger protection is needed, because deletions and corruption can sync too.

## Change the backup destination

Changing the destination does not move or delete any existing archives. They remain in the old folder unless you copy them yourself.

1. Create or choose the new folder. If it is cloud-synced, make sure it is available locally.
2. Rerun the installer with the new path. Also repeat any non-default frequency or cleanup settings you use, because the installer regenerates the complete configuration each time:

   ```sh
   BACKUP_DIR="$HOME/path/to/your/new-backup-folder" \
   BACKUP_INTERVAL_DAYS=10 \
   AUTO_CLEANUP=false \
     ./scripts/install-launchagent.sh
   ```

3. Create and verify a backup in the new destination:

   ```sh
   BACKUP_DIR="$HOME/path/to/your/new-backup-folder" \
     ./scripts/backup-apple-notes.sh --force
   ```

4. Confirm that the new folder contains a dated `.zip` file and its adjacent `.zip.sha256` file. For a cloud destination, also confirm that both files finish syncing.

The manual command needs `BACKUP_DIR` because it does not read the destination from the installed LaunchAgent. Once the installer has been rerun, scheduled backups use the new destination automatically.

## Change the backup frequency

The default backup frequency is every 10 days. `BACKUP_INTERVAL_DAYS` sets the minimum number of days between successful backups. Use a positive whole number when installing. For example, to back up every 7 days:

```sh
BACKUP_INTERVAL_DAYS=7 ./scripts/install-launchagent.sh
```

The LaunchAgent still checks once per day and at login; changing this value controls when that check considers the backup stale. A backup might run later than the exact interval if the Mac was shut down, the user was logged out, or the destination was unavailable.

Rerun the installer with the new value whenever you want to change the persistent schedule. Include the destination and cleanup settings again if you customized them, because the installer regenerates the LaunchAgent configuration:

```sh
BACKUP_INTERVAL_DAYS=14 \
AUTO_CLEANUP=true \
BACKUP_DIR="$HOME/path/to/your/backup-folder" \
  ./scripts/install-launchagent.sh
```

`--force` always creates a backup regardless of this interval. Setting `BACKUP_INTERVAL_DAYS` only for a manual `--if-stale` command changes that one check; rerunning the installer is what makes the value persistent for scheduled checks.

## Optional automatic cleanup

Archives are never removed by default. To opt into automatically moving redundant archives to the Mac Trash when installing:

```sh
AUTO_CLEANUP=true BACKUP_DIR="$HOME/path/to/your/backup-folder" \
  ./scripts/install-launchagent.sh
```

Automatic cleanup runs only after a new archive has passed all backup and integrity checks. Only the most recent, 10-day, 30-day, 90-day, 180-day, and 365-day-old backups are retained. Because the Mac may be asleep or the destination unavailable on a target date, these are approximate recovery points rather than exact guarantees. Immediately after a backup, cleanup normally keeps at most six valid pairs: the new archive plus five historical points.

This option asks Finder to move redundant ZIP and checksum pairs to the Mac Trash. It never falls back to permanent deletion. The files remain recoverable until Trash is emptied, but removing them from a cloud-synced destination will normally sync that removal to the cloud provider. Finder may ask for permission the first time cleanup runs. Before enabling it, preview the policy against your existing archives:

```sh
BACKUP_DIR="$HOME/path/to/your/backup-folder" \
  ./scripts/backup-apple-notes.sh --retention-preview
```

Incomplete pairs, invalid checksum metadata, the most recent archive, and any archive that fails checksum verification immediately before cleanup are never moved. Every decision is logged. After one or more pairs are moved to Trash, macOS shows a single summary notification; the log contains the complete filenames. If Finder refuses the move or only part of a pair moves, cleanup reports an error and requires manual attention rather than permanently deleting anything.

## Files and locations

- Backup script: `scripts/backup-apple-notes.sh`
- LaunchAgent template: `io.github.apple-notes-backup.plist`
- LaunchAgent installer: `scripts/install-launchagent.sh`
- Installed LaunchAgent: `~/Library/LaunchAgents/io.github.apple-notes-backup.plist`
- Notes source: `~/Library/Group Containers/group.com.apple.notes`
- Default archive destination: `~/Backups/Apple Notes`
- Backup log: `apple-notes-backup.log` inside the configured archive destination
- Fallback log when the backup folder is unavailable: `~/Library/Logs/apple-notes-backup.log`
- LaunchAgent output: `~/Library/Logs/apple-notes-backup-launchd.log`

Archive names begin with the date, for example `apple-notes-2026-07-10.zip`. Each archive has an adjacent checksum file such as `apple-notes-2026-07-10.zip.sha256`. A timestamp is added if a forced backup is run more than once on the same date.

## How a backup works

The background job runs at login and approximately once every 24 hours. The lightweight check looks for a completed `apple-notes-*.zip` archive modified within the last 10 days. If one exists, it logs that no work is needed and exits without closing Notes.

When a backup is due, the script:

1. Confirms the Notes source and backup destination are available.
2. Records whether Notes is open and, if so, quits it cleanly.
3. Creates the ZIP in a local temporary staging directory.
4. Tests every entry in the new ZIP with `unzip -t`.
5. Moves the completed archive into the destination and writes its SHA-256 checksum to an adjacent `.sha256` file.
6. Randomly chooses an older archive, recalculates its SHA-256 hash, and compares it with the stored checksum. If there is no older archive, it verifies the new one.
7. Tests the randomly selected archive with `unzip -t` after its checksum matches.
8. Records the new archive's size and SHA-256 checksum in the log.
9. If automatic cleanup was explicitly enabled, moves redundant archives to Trash only after the verified backup is complete.
10. Reopens Notes only if it was open when the backup began.

The ZIP test confirms that every archived entry can be decompressed. The checksum comparison confirms that the archive's bytes have not changed since it was created. Partial archives and checksum files are removed after errors. A lock prevents overlapping runs.

## Sleeping, shutdown, and failures

The job cannot run while the Mac is shut down. Because it runs at login and checks daily rather than relying on one monthly calendar event, it catches up after the next login or wake. It still needs the user to be logged in.

If the backup destination is unavailable, the error is recorded in the local fallback log and a macOS notification shows the specific unavailable path. Other activity is recorded in the backup log beside the archives. No incomplete archive is placed in the backup folder after a failure. The next daily check tries again because it will still consider the backup stale.

## Permissions

`/bin/bash` needs Full Disk Access under **System Settings > Privacy & Security > Full Disk Access** so the background job can read the protected Notes data folder.

## Manual commands

Create a backup immediately, regardless of age:

```sh
./scripts/backup-apple-notes.sh --force
```

Run only the lightweight age check:

```sh
./scripts/backup-apple-notes.sh --if-stale
```

Preview which redundant archive pairs the retention policy would remove:

```sh
./scripts/backup-apple-notes.sh --retention-preview
```

Apply the retention policy once, even when automatic cleanup is disabled:

```sh
./scripts/backup-apple-notes.sh --apply-retention
```

Applying retention removes eligible pairs from the backup destination by moving them to the Mac Trash. It verifies each archive immediately before the move, logs every moved filename, and sends one summary notification. It never falls back to permanent deletion.

Inspect recent activity:

```sh
tail -50 "$HOME/Backups/Apple Notes/apple-notes-backup.log"
```

If the destination was unavailable, inspect the fallback and LaunchAgent logs:

```sh
tail -50 ~/Library/Logs/apple-notes-backup.log
tail -50 ~/Library/Logs/apple-notes-backup-launchd.log
```

Inspect the installed service:

```sh
launchctl print gui/$(id -u)/io.github.apple-notes-backup
```

## Restoring a backup

Restoring this archive replaces the complete local Notes database; it is not a selective one-note import. Database formats can change between macOS releases, and reconnecting an older database to iCloud can merge or overwrite data in ways that are difficult to predict. The safest use is to open the restored database while offline, recover the notes you need, and then return to the current database.

Before starting, make sure the chosen ZIP is fully available locally rather than only represented by a cloud placeholder. Give Terminal Full Disk Access, just as `/bin/bash` has for the backup job.

### Recovery-first procedure

1. Disconnect the Mac from Wi-Fi and any wired network. This prevents Notes from immediately reconciling the restored database with iCloud.
2. Disable the automatic backup job temporarily:

   ```sh
   launchctl bootout gui/$(id -u)/io.github.apple-notes-backup
   ```

3. Set the archive you want to restore and verify it:

   ```sh
   RESTORE_ARCHIVE="$HOME/Backups/Apple Notes/apple-notes-2026-07-10.zip"
   cd "$(dirname "$RESTORE_ARCHIVE")"
   shasum -a 256 -c "$(basename "$RESTORE_ARCHIVE").sha256"
   unzip -t "$RESTORE_ARCHIVE"
   ```

   Both commands must succeed. A checksum mismatch means the archive has changed since creation and should not be restored without further investigation.

4. Quit Notes and confirm that it is no longer running:

   ```sh
   osascript -e 'tell application id "com.apple.Notes" to quit'
   while pgrep -x Notes >/dev/null; do sleep 1; done
   ```

5. Move the current database aside. Do not delete it:

   ```sh
   SAFETY_COPY="$HOME/Desktop/group.com.apple.notes.before-restore-$(date +%Y%m%d-%H%M%S)"
   mv "$HOME/Library/Group Containers/group.com.apple.notes" "$SAFETY_COPY"
   ```

6. Extract the archived folder back into its original parent directory:

   ```sh
   ditto -x -k "$RESTORE_ARCHIVE" "$HOME/Library/Group Containers"
   ```

7. Open Notes while still offline and confirm that the expected notes appear:

   ```sh
   open -a Notes
   ```

8. Recover the material you need. For a small number of notes, use **File > Export as > Markdown** or **PDF**, or copy their contents into files outside Notes. Avoid reconnecting this restored database to iCloud unless the intention is a full rollback and the consequences have been considered carefully.

### Returning to the current database

Quit Notes again. Preserve the recovered database for inspection, then put the safety copy back. Replace the example safety-copy path with the exact path created in step 5.

```sh
osascript -e 'tell application id "com.apple.Notes" to quit'
while pgrep -x Notes >/dev/null; do sleep 1; done

RECOVERED_COPY="$HOME/Desktop/group.com.apple.notes.recovered-$(date +%Y%m%d-%H%M%S)"
mv "$HOME/Library/Group Containers/group.com.apple.notes" "$RECOVERED_COPY"
mv "$HOME/Desktop/group.com.apple.notes.before-restore-YYYYMMDD-HHMMSS" \
  "$HOME/Library/Group Containers/group.com.apple.notes"
open -a Notes
```

After the current database is back and Notes looks correct, reconnect the network and reload the background job:

```sh
launchctl bootstrap gui/$(id -u) \
  "$HOME/Library/LaunchAgents/io.github.apple-notes-backup.plist"
```

Keep both Desktop safety folders until Notes has synchronized normally and the recovered material is safely stored. A full permanent rollback should begin with an additional fresh backup and is best handled as a supervised recovery rather than by reconnecting the old database directly.

## Reload or uninstall

After changing the template or installer, rerun `./scripts/install-launchagent.sh` to regenerate and reload the installed job.

To disable the job:

```sh
launchctl bootout gui/$(id -u)/io.github.apple-notes-backup
```

The existing ZIP archives are not removed when the job is disabled.
