# Recovering Apple Notes from a Notehold backup

Restoring a Notehold archive replaces the complete local Notes database; it is not a selective one-note import. Database formats can change between macOS releases, and reconnecting an older database to iCloud can merge or overwrite data in ways that are difficult to predict. The safest approach is to open the restored database while offline, recover the notes you need, and then return to the current database.

Before starting, make sure the chosen ZIP is fully available locally rather than represented only by a cloud placeholder. Give Terminal Full Disk Access, just as `/bin/bash` has for the backup job.

## Recovery-first procedure

1. Disconnect the Mac from Wi-Fi and any wired network. This prevents Notes from immediately reconciling the restored database with iCloud.
2. Disable the automatic backup job temporarily:

   ```sh
   launchctl bootout gui/$(id -u)/io.github.rsheyd.notehold
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

## Return to the current database

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
  "$HOME/Library/LaunchAgents/io.github.rsheyd.notehold.plist"
```

Keep both Desktop safety folders until Notes has synchronized normally and the recovered material is safely stored. A full permanent rollback should begin with an additional fresh backup and is best handled as a supervised recovery rather than by reconnecting the old database directly.

[Return to the Notehold README](../README.md)
