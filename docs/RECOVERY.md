# Recovering Apple Notes from a Notehold backup

Restoring a Notehold archive temporarily replaces the complete local Notes database; it is not a selective one-note import. Keep the Mac offline while the older database is open, recover the notes you need, and restore the current database before reconnecting to iCloud.

Make sure the chosen ZIP is fully downloaded before starting.

## Recover with Finder

1. Disconnect the Mac from the internet and quit Notes.
2. In Finder, double-click the chosen backup ZIP and locate the extracted `group.com.apple.notes` folder.
3. Choose **Go > Go to Folder** in Finder and open `~/Library/Group Containers`.
4. Rename the current `group.com.apple.notes` folder to something like `group.com.apple.notes.before-restore`. Do not delete it.
5. Move the extracted `group.com.apple.notes` folder into `~/Library/Group Containers`.
6. Open Notes while still offline and export or copy the notes you want to recover, then quit Notes.
7. Rename the older database folder, restore the original folder's `group.com.apple.notes` name, and confirm that Notes works before reconnecting to the internet.

Do not reconnect an older database to iCloud unless you intentionally want to attempt a complete rollback.

## Optional exact commands

The commands below add checksum and ZIP verification and temporarily unload Notehold during recovery. They require Full Disk Access for the terminal app running them. Use the same terminal window throughout so the paths defined below remain available.

### 1. Disconnect and stop Notehold

Disconnect Wi-Fi and any wired network, then set the archive path, stop Notehold, verify the backup, and quit Notes:

```sh
NOTES_PARENT="$HOME/Library/Group Containers"
CURRENT_NOTES="$NOTES_PARENT/group.com.apple.notes"
RESTORE_ARCHIVE="$HOME/Backups/Apple Notes/apple-notes-2026-07-10.zip"
SAFETY_COPY="$NOTES_PARENT/group.com.apple.notes.before-restore-$(date +%Y%m%d-%H%M%S)"
RECOVERED_COPY="$NOTES_PARENT/group.com.apple.notes.recovered-$(date +%Y%m%d-%H%M%S)"

launchctl bootout gui/$(id -u)/io.github.rsheyd.notehold
cd "$(dirname "$RESTORE_ARCHIVE")"
shasum -a 256 -c "$(basename "$RESTORE_ARCHIVE").sha256"
unzip -t "$RESTORE_ARCHIVE"

osascript -e 'tell application id "com.apple.Notes" to quit'
while pgrep -x Notes >/dev/null; do sleep 1; done
```

Both verification commands must succeed. A checksum mismatch means the archive changed after creation and should not be restored without investigation.

### 2. Replace the current database temporarily

```sh
mv "$CURRENT_NOTES" "$SAFETY_COPY"
ditto -x -k "$RESTORE_ARCHIVE" "$NOTES_PARENT"
```

### 3. Recover notes while offline

```sh
open -a Notes
```

Confirm the expected notes appear, then export or copy what you need outside Notes.

### 4. Restore the current database

```sh
osascript -e 'tell application id "com.apple.Notes" to quit'
while pgrep -x Notes >/dev/null; do sleep 1; done

mv "$CURRENT_NOTES" "$RECOVERED_COPY"
mv "$SAFETY_COPY" "$CURRENT_NOTES"
open -a Notes
```

Confirm the current notes are back before reconnecting the network. Then re-enable Notehold:

```sh
launchctl bootstrap gui/$(id -u) \
  "$HOME/Library/LaunchAgents/io.github.rsheyd.notehold.plist"
```

Keep the two renamed database folders until Notes has synchronized normally and the recovered material is safely stored.

[Return to the Notehold README](../README.md)
