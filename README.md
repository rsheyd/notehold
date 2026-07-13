# Notehold

**Automatic, recoverable backups for Apple Notes.**

Notehold is a command-line backup utility for macOS. It creates dated ZIP archives of your complete local Notes database, checks once a day and after login, and by default creates a new backup when the latest successful one is at least 10 days old.

Notehold does not include a conventional Mac app or graphical interface. Installation, configuration, status, and manual backups are managed with the `notehold` command in Terminal.

Source: [github.com/rsheyd/notehold](https://github.com/rsheyd/notehold)

Development and release instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

Archives go to `~/Backups/Apple Notes` by default. You can instead use an external drive or a folder synced by Dropbox, Google Drive, OneDrive, or iCloud Drive.

## Contents

- [Getting started](#getting-started)
  - [Quick start](#quick-start)
  - [Install without Git](#install-without-git)
  - [Update Notehold](#update-notehold)
- [Configuration](#configuration)
- [How Notehold works](#how-notehold-works)
  - [Backup process](#backup-process)
  - [Full Disk Access](#full-disk-access)
- [Command reference](#command-reference)
  - [Manual commands](#manual-commands)
  - [Status and logs](#status-and-logs)
- [Recovery](#recovery)
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

Backups are saved in `~/Backups/Apple Notes` by default, and redundant older backups are automatically moved to the Mac Trash to limit storage growth.

The installer adds `~/.local/bin` to `PATH`, so `notehold` is available from any directory in new Terminal windows.

### Install without Git

If the `git` command is unavailable and you do not want to install Apple's Command Line Tools, download and extract the latest `notehold-VERSION.tar.gz` file from the [Notehold releases](https://github.com/rsheyd/notehold/releases) page. In Terminal, change to the extracted directory and run:

```sh
./notehold install
```

Give `/bin/bash` Full Disk Access before installation, just as described in the main [Quick start](#quick-start). The extracted directory is no longer needed after installation.

### Update Notehold

If you kept the clone from the Quick Start, change to its parent directory, pull the latest released code, and run the installer again:

```sh
git -C notehold pull --ff-only
notehold/notehold install
```

If you deleted the clone or installed without Git, download and extract the newer archive from the [Notehold releases](https://github.com/rsheyd/notehold/releases) page and run `./notehold install` from the extracted directory.

Each release is copied into its own versioned program directory before the active `current` link is switched. The installed backup destination, frequency, and cleanup choice are preserved unless replacement values are supplied with the install command. Existing program versions remain available until `notehold uninstall`; backup archives and logs are always outside the program directory.

## Configuration

By default, Notehold stores archives in `~/Backups/Apple Notes`, creates a backup when the newest successful archive is at least 10 days old, and automatically moves redundant older backups to the Mac Trash.

See [Configuring Notehold](docs/CONFIGURATION.md) to choose another destination, change the schedule, disable automatic cleanup, or preview the retention policy.

## How Notehold works

### Files and locations

- Installed command: `~/.local/bin/notehold`
- Shell PATH configuration: `~/.zprofile` when `~/.local/bin` is not already available
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

Restoring a backup replaces the complete local Notes database and can interact unpredictably with iCloud. Do not treat it as a selective one-note import or reconnect an old database without understanding the consequences.

Follow the offline, recovery-first procedure in [Recovering Apple Notes from a Notehold backup](docs/RECOVERY.md).

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

The generic `~/.local/bin` entry remains in `~/.zprofile` after uninstall because other command-line tools may also use that directory.

If `~/.local/bin` is not on `PATH`, run the command by its full path:

```sh
~/.local/bin/notehold uninstall
```
