# r/macapps post draft

## Recommended title

I made Notehold, a free open-source backup utility for Apple Notes

## Alternate titles

- Notehold: automatic, dated ZIP backups for Apple Notes
- I wanted actual backups of my Apple Notes, so I made Notehold

## Post

I use Apple Notes for a lot, and at some point I realized that iCloud sync was not quite the same thing as having a backup. If I accidentally deleted or changed something, that change could sync across all my devices.

So I made Notehold, a small free and open-source command-line utility that creates dated ZIP backups of the complete local Notes database.

By default, it checks once a day and after login, and creates a new backup when the latest one is at least 10 days old. The ZIPs can go in any folder, including an external drive or a folder synced with Google Drive, Dropbox, or iCloud Drive. It verifies each archive and writes a SHA-256 checksum. There is also an optional retention policy that moves redundant older archives to the Trash instead of permanently deleting them.

The tradeoff is that this is a command-line utility, not a polished Mac app. Because the Notes database lives in a protected macOS container, `/bin/bash` needs Full Disk Access for automatic backups. Notehold briefly closes Notes while making a backup so the database is captured consistently, then reopens it if it was already running.

I have tested installation and real backups on macOS 26.5.2. The first public release is v0.1.2.

GitHub: https://github.com/rsheyd/notehold

I would appreciate feedback, especially on whether the installation and recovery instructions are clear.

## Before posting

- Attach `assets/notehold-readme-hero.png`.
- Complete the non-destructive recovery drill before implying that recovery has been manually tested.
