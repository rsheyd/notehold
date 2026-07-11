# Apple Notes backup

This setup creates versioned ZIP archives of the local Apple Notes data folder and stores them in a destination you choose. It checks once a day and after login, but only creates an archive when the newest successful backup is at least 30 days old.

By default, archives go to `~/Backups/Apple Notes`. Set `BACKUP_DIR` when installing or running the script to use another local or cloud-synced folder. The script also accepts `NOTES_DIR` and `MAX_BACKUP_AGE_DAYS` environment variables.

## Install

Clone this repository, then run:

```sh
./scripts/install-launchagent.sh
```

To choose another destination:

```sh
BACKUP_DIR="$HOME/path/to/your/backup-folder" ./scripts/install-launchagent.sh
```

The installer creates the destination if needed, generates a LaunchAgent with paths for the current Mac, loads it, and reads back its status.

## Files and locations

- Backup script: `scripts/backup-apple-notes.sh`
- LaunchAgent template: `io.github.apple-notes-backup.plist`
- LaunchAgent installer: `scripts/install-launchagent.sh`
- Installed LaunchAgent: `~/Library/LaunchAgents/io.github.apple-notes-backup.plist`
- Notes source: `~/Library/Group Containers/group.com.apple.notes`
- Default archive destination: `~/Backups/Apple Notes`
- Backup log: `~/Backups/Apple Notes/apple-notes-backup.log`
- Fallback log when the backup folder is unavailable: `~/Library/Logs/apple-notes-backup.log`
- LaunchAgent output: `~/Library/Logs/apple-notes-backup-launchd.log`

Archive names begin with the date, for example `apple-notes-2026-07-10.zip`. Each archive has an adjacent checksum file such as `apple-notes-2026-07-10.zip.sha256`. A timestamp is added if a forced backup is run more than once on the same date.

## How a backup works

The background job runs at login and approximately once every 24 hours. The lightweight check looks for a completed `apple-notes-*.zip` archive modified within the last 30 days. If one exists, it logs that no work is needed and exits without closing Notes.

When a backup is due, the script:

1. Confirms the Notes source and backup destination are available.
2. Records whether Notes is open and, if so, quits it cleanly.
3. Creates the ZIP in a local temporary staging directory.
4. Tests every entry in the new ZIP with `unzip -t`.
5. Moves the completed archive into the destination and writes its SHA-256 checksum to an adjacent `.sha256` file.
6. Randomly chooses an older archive, recalculates its SHA-256 hash, and compares it with the stored checksum. If there is no older archive, it verifies the new one.
7. Tests the randomly selected archive with `unzip -t` after its checksum matches.
8. Records the new archive's size and SHA-256 checksum in the log.
9. Reopens Notes only if it was open when the backup began.

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
