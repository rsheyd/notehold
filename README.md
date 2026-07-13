# Notehold

**Automatic, recoverable backups for Apple Notes.**

Notehold is a command-line backup utility for macOS. It creates dated ZIP archives of your complete local Notes database, checks once a day and after login, and by default creates a new backup when the latest successful one is at least 10 days old.

Notehold does not include a conventional Mac app or graphical interface. Installation, configuration, status, and manual backups are managed with the `notehold` command in Terminal.

Source: [github.com/rsheyd/notehold](https://github.com/rsheyd/notehold)

Archives go to `~/Backups/Apple Notes` by default. You can instead use an external drive or a folder synced by Dropbox, Google Drive, OneDrive, or iCloud Drive.

## Contents

- [Getting started](#getting-started)
  - [Quick start](#quick-start)
  - [Install without Git](#install-without-git)
  - [Run `notehold` from anywhere](#run-notehold-from-anywhere)
  - [Update Notehold](#update-notehold)
- [Configuration](#configuration)
  - [Backup destination](#backup-destination)
  - [Backup schedule](#backup-schedule)
  - [Automatic cleanup](#automatic-cleanup)
- [How Notehold works](#how-notehold-works)
  - [Backup process](#backup-process)
  - [Full Disk Access](#full-disk-access)
- [Command reference](#command-reference)
  - [Manual commands](#manual-commands)
  - [Status and logs](#status-and-logs)
- [Recovery](#recovery)
  - [Restoring a backup](#restoring-a-backup)
- [Maintenance](#maintenance)
  - [Reload or uninstall](#reload-or-uninstall)

## Getting started

### Why Notehold?

iCloud keeps Notes synchronized across devices, but synchronization is not the same as keeping independent, dated backups. An accidental edit or deletion can sync to every device. This project gives you ordinary ZIP files that you can inspect, copy, and verify without a proprietary restore tool or repository password.

For protection from loss or failure of the Mac itself, store the archives somewhere that is copied off the Mac, such as an external drive or a cloud-synced folder. The script verifies each local ZIP and checksum, but it cannot confirm that a cloud provider finished uploading it.

### Quick start

1. Give `/bin/bash` Full Disk Access under **System Settings > Privacy & Security > Full Disk Access**. See [Full Disk Access](#full-disk-access) for why the command-line version needs this. Do this before installation because the background check starts immediately when installed.

2. In Terminal, clone Notehold and install it:

   ```sh
   git clone https://github.com/rsheyd/notehold.git
   notehold/notehold install
   ```

3. Create the first backup:

   ```sh
   ~/.local/bin/notehold backup
   ```

Installation starts the daily background check. When a backup is needed, Notehold briefly closes Notes to create a consistent archive, then reopens it if it was previously open.

### Install without Git

If the `git` command is unavailable and you do not want to install Apple's Command Line Tools, download and extract the latest `notehold-VERSION.tar.gz` file from the [Notehold releases](https://github.com/rsheyd/notehold/releases) page. In Terminal, change to the extracted directory and run:

```sh
./notehold install
```

Give `/bin/bash` Full Disk Access before installation, just as described in the main [Quick start](#quick-start). The extracted directory is no longer needed after installation.

### Run `notehold` from anywhere

The installed command lives at `~/.local/bin/notehold`. If the installer warns that `~/.local/bin` is not on `PATH`, add it for the default macOS shell and start a new login shell:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
exec zsh -l
```

Confirm that the command is available:

```sh
command -v notehold
```

You can then use commands such as `notehold backup` from any directory. Without this optional setup, use the full path, such as `~/.local/bin/notehold backup`.

### Update Notehold

If you kept the clone from the Quick Start, change to its parent directory, pull the latest released code, and run the installer again:

```sh
git -C notehold pull --ff-only
notehold/notehold install
```

If you deleted the clone or installed without Git, download and extract the newer archive from the [Notehold releases](https://github.com/rsheyd/notehold/releases) page and run `./notehold install` from the extracted directory.

Each release is copied into its own versioned program directory before the active `current` link is switched. The installed backup destination, frequency, and cleanup choice are preserved unless replacement values are supplied with the install command. Existing program versions remain available until `notehold uninstall`; backup archives and logs are always outside the program directory.

## Configuration

### Backup destination

The default destination is stored on the same Mac as the Notes database. It can help with accidental changes to Notes, but it does not protect against loss, theft, or failure of the Mac's storage. For better protection, use a folder that is copied off the Mac—for example, a locally synced Google Drive, Dropbox, OneDrive, or iCloud Drive folder—or include the destination in another backup system such as Time Machine.

`BACKUP_DIR` is the local path where the script writes archives. To select a destination during installation, create the folder first and then pass its path to the installer:

The examples below use the installed `notehold` command. During the first installation from a clone, use `notehold/notehold` instead; from an extracted release, use `./notehold`.

```sh
BACKUP_DIR="$HOME/Library/CloudStorage/Dropbox/Backups/Apple Notes" \
  notehold install
```

Use the actual path on your Mac rather than copying this example unchanged. You can drag a folder from Finder into Terminal to insert its full path. Cloud providers commonly appear under `~/Library/CloudStorage`, although the exact path depends on the provider and account. If an explicitly selected folder does not exist or is unavailable, the installer stops and asks you to choose or create it instead of silently creating a possibly mistyped path.

Make sure the destination remains downloaded locally. After creating a test backup, confirm that its ZIP and checksum appear on another device or on the provider's website. Cloud sync should not be the only copy when stronger protection is needed, because deletions and corruption can sync too.

#### Change the backup destination

Changing the destination does not move or delete any existing archives. They remain in the old folder unless you copy them yourself.

1. Create or choose the new folder. If it is cloud-synced, make sure it is available locally.
2. Rerun the installer with the new path. Other installed settings are preserved:

   ```sh
   BACKUP_DIR="$HOME/path/to/your/new-backup-folder" \
     notehold install
   ```

3. Create and verify a backup in the new destination:

   ```sh
   notehold backup
   ```

4. Confirm that the new folder contains a dated `.zip` file and its adjacent `.zip.sha256` file. For a cloud destination, also confirm that both files finish syncing.

Installed manual commands and scheduled backups both use the destination recorded by `notehold install`. An environment value supplied directly to a manual command still overrides the installed value for that one run.

### Backup schedule

The default backup frequency is every 10 days. `BACKUP_INTERVAL_DAYS` sets the minimum number of days between successful backups. Use a positive whole number when installing. For example, to back up every 7 days:

```sh
BACKUP_INTERVAL_DAYS=7 notehold install
```

The LaunchAgent still checks once per day and at login; changing this value controls when that check considers the backup stale. A backup might run later than the exact interval if the Mac was shut down, the user was logged out, or the destination was unavailable.

Rerun the installer with the new value whenever you want to change the persistent schedule. Settings you do not supply are preserved:

```sh
BACKUP_INTERVAL_DAYS=14 \
  notehold install
```

`--force` always creates a backup regardless of this interval. Setting `BACKUP_INTERVAL_DAYS` only for a manual `--if-stale` command changes that one check; rerunning the installer is what makes the value persistent for scheduled checks.

### Automatic cleanup

Automatic cleanup is enabled by default. To retain every completed archive indefinitely instead, disable it when installing:

```sh
AUTO_CLEANUP=false notehold install
```

Automatic cleanup runs only after a new archive has passed all backup and integrity checks. Only the most recent, 10-day, 30-day, 90-day, 180-day, and 365-day-old backups are retained. Because the Mac may be asleep or the destination unavailable on a target date, these are approximate recovery points rather than exact guarantees. Immediately after a backup, cleanup normally keeps at most six valid pairs: the new archive plus five historical points.

Cleanup asks Finder to move redundant ZIP and checksum pairs to the Mac Trash. It never falls back to permanent deletion. The files remain recoverable until Trash is emptied, but removing them from a cloud-synced destination will normally sync that removal to the cloud provider. Finder may ask for permission the first time cleanup runs. You can preview the policy against your existing archives at any time:

```sh
notehold retention preview
```

Incomplete pairs, invalid checksum metadata, the most recent archive, and any archive that fails checksum verification immediately before cleanup are never moved. Every decision is logged. After one or more pairs are moved to Trash, macOS shows a single summary notification; the log contains the complete filenames. If Finder refuses the move or only part of a pair moves, cleanup reports an error and requires manual attention rather than permanently deleting anything.

## How Notehold works

### Files and locations

- Installed command: `~/.local/bin/notehold`
- Installed program: `~/Library/Application Support/Notehold/current`
- Versioned program files: `~/Library/Application Support/Notehold/versions/<version>`
- Backup script: `scripts/notehold-backup.sh`
- LaunchAgent template: `io.github.rsheyd.notehold.plist`
- LaunchAgent installer: `scripts/install-launchagent.sh`
- Installed LaunchAgent: `~/Library/LaunchAgents/io.github.rsheyd.notehold.plist`
- Notes source: `~/Library/Group Containers/group.com.apple.notes`
- Default archive destination: `~/Backups/Apple Notes`
- Backup log: `notehold.log` inside the configured archive destination
- Fallback log when the backup folder is unavailable: `~/Library/Logs/notehold.log`
- LaunchAgent output: `~/Library/Logs/notehold-launchd.log`

The installer copies the released program into the versioned application-support directory, points `~/.local/bin/notehold` to the active version, and installs the background job. The installed program does not depend on the cloned or extracted source directory, which can be kept for easier updates or deleted after installation.

Archive names begin with the date, for example `apple-notes-2026-07-10.zip`. Each archive has an adjacent checksum file such as `apple-notes-2026-07-10.zip.sha256`. A timestamp is added if a forced backup is run more than once on the same date.

### Backup process

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
9. If automatic cleanup is enabled, moves redundant archives to Trash only after the verified backup is complete.
10. Reopens Notes only if it was open when the backup began.

The ZIP test confirms that every archived entry can be decompressed. The checksum comparison confirms that the archive's bytes have not changed since it was created. Partial archives and checksum files are removed after errors. A lock prevents overlapping runs.

### Sleeping, shutdown, and failures

The job cannot run while the Mac is shut down. Because it runs at login and checks daily rather than relying on one monthly calendar event, it catches up after the next login or wake. It still needs the user to be logged in.

If the backup destination is unavailable, the error is recorded in the local fallback log and a macOS notification shows the specific unavailable path. Other activity is recorded in the backup log beside the archives. No incomplete archive is placed in the backup folder after a failure. The next daily check tries again because it will still consider the backup stale.

### Full Disk Access

The Notes database is stored in another app's protected data container at `~/Library/Group Containers/group.com.apple.notes`. macOS does not treat it like an ordinary document selected by the user. Backup utilities that read another app's private data require the user to grant Full Disk Access; Notehold cannot grant that permission automatically.

The current command-line version is implemented as shell scripts. `/bin/bash` interprets those scripts, so macOS associates the protected file access with Bash rather than with a graphical app named Notehold. Give `/bin/bash` Full Disk Access under **System Settings > Privacy & Security > Full Disk Access** before the first backup.

In the Full Disk Access file picker, press **Command-Shift-G**, enter `/bin/bash`, and choose **Open**. Make sure the new Bash entry is enabled.

This permission is broader than access for Notehold alone: other scripts run through `/bin/bash` may also be able to read protected files. Notehold uses it to read and archive the local Notes database. Its source is available in this repository for inspection, and the permission can be revoked after running `notehold uninstall`.

Avoiding the Bash permission would require a separately signed executable or Mac app to perform the protected work. That is outside the scope of this command-line release; it would not eliminate the requirement for the user to approve access to the Notes database.

## Command reference

### Manual commands

Create a backup immediately, regardless of age:

```sh
notehold backup
```

Run only the lightweight age check:

```sh
notehold check
```

Preview which redundant archive pairs the retention policy would remove:

```sh
notehold retention preview
```

Apply the retention policy once, even when automatic cleanup is disabled:

```sh
notehold retention apply
```

Applying retention removes eligible pairs from the backup destination by moving them to the Mac Trash. It verifies each archive immediately before the move, logs every moved filename, and sends one summary notification. It never falls back to permanent deletion.

### Status and logs

Show the installed destination, backup frequency, automatic-cleanup policy, most recent activity, and up to three recent backups:

```sh
notehold status
```

The status command is read-only. It reads configuration from the installed LaunchAgent, reports whether the destination is currently available, and does not print raw launchd environment details.

Inspect recent activity:

```sh
tail -50 "$HOME/Backups/Apple Notes/notehold.log"
```

If the destination was unavailable, inspect the fallback and LaunchAgent logs:

```sh
tail -50 ~/Library/Logs/notehold.log
tail -50 ~/Library/Logs/notehold-launchd.log
```

Inspect the installed service:

```sh
launchctl print gui/$(id -u)/io.github.rsheyd.notehold
```

## Recovery

### Restoring a backup

Restoring this archive replaces the complete local Notes database; it is not a selective one-note import. Database formats can change between macOS releases, and reconnecting an older database to iCloud can merge or overwrite data in ways that are difficult to predict. The safest use is to open the restored database while offline, recover the notes you need, and then return to the current database.

Before starting, make sure the chosen ZIP is fully available locally rather than only represented by a cloud placeholder. Give Terminal Full Disk Access, just as `/bin/bash` has for the backup job.

### Recovery-first procedure

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
  "$HOME/Library/LaunchAgents/io.github.rsheyd.notehold.plist"
```

Keep both Desktop safety folders until Notes has synchronized normally and the recovered material is safely stored. A full permanent rollback should begin with an additional fresh backup and is best handled as a supervised recovery rather than by reconnecting the old database directly.

## Maintenance

### Reload or uninstall

Running `notehold install` again reloads the background job. When installing a newer release, it also switches the active program version while preserving the existing destination, frequency, and cleanup choice unless replacements were supplied.

To check which version is active:

```sh
notehold version
```

To unload the background job and remove the command, LaunchAgent, and all installed program versions:

```sh
notehold uninstall
```

Uninstall never removes backup destinations, ZIP archives, checksum files, or logs. The uninstall script only removes a program directory bearing Notehold's installation marker, only removes the `notehold` command when it points to that installation, and only removes the expected LaunchAgent.

If `~/.local/bin` is not on `PATH`, run the command by its full path:

```sh
~/.local/bin/notehold uninstall
```
