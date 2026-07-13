# Recovering Apple Notes from a Notehold backup

Restoring a Notehold archive temporarily replaces the complete local Notes database; it is not a selective one-note import. Keep the Mac offline while the older database is open, recover the notes you need, and restore the current database before reconnecting to iCloud.

Make sure the chosen ZIP is fully downloaded and give Terminal Full Disk Access before starting.

## Short recovery procedure

1. Disconnect the Mac from the internet, temporarily disable Notehold, and quit Notes.
2. Choose a backup ZIP and verify its checksum and ZIP integrity.
3. Rename the current `group.com.apple.notes` folder alongside the original in `~/Library/Group Containers`. Do not delete it.
4. Extract the older `group.com.apple.notes` folder from the ZIP into `~/Library/Group Containers`.
5. Open Notes while still offline and export or copy the notes you want to recover.
6. Quit Notes, move the older database aside, and restore the current database's original name.
7. Confirm the current database works before reconnecting to the internet and re-enabling Notehold.

Do not reconnect an older database to iCloud unless you intentionally want to attempt a complete rollback.

## Exact commands

Use the same Terminal window throughout so the paths defined below remain available.

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
