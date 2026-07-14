# Recovering Apple Notes from a Notehold backup

Restoring a Notehold archive temporarily replaces the complete local Notes database; it is not a selective one-note import. Keep the Mac offline while the older database is open, recover the notes you need, and restore the current database before reconnecting to iCloud.

1. Disconnect the Mac from the internet and quit Notes.
2. In Finder, double-click the chosen backup ZIP and locate the extracted `group.com.apple.notes` folder.
3. Choose **Go > Go to Folder** in Finder and open `~/Library/Group Containers`.
4. Rename the current `group.com.apple.notes` folder to something like `group.com.apple.notes.before-restore`. Do not delete it.
5. Move the extracted `group.com.apple.notes` folder into `~/Library/Group Containers`.
6. Open Notes while still offline and export or copy the notes you want to recover, then quit Notes.
7. Rename the older database folder, restore the original folder's `group.com.apple.notes` name, and confirm that Notes works before reconnecting to the internet.

Do not reconnect an older database to iCloud unless you intentionally want to attempt a complete rollback.

[Return to the Notehold README](../README.md)
