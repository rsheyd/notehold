# How Notehold works

Notehold installs a user LaunchAgent that checks at login and approximately once every 24 hours. If the newest completed archive is older than the configured interval, it creates a backup.

## Backup process

1. Confirm the Notes database and backup destination are available, then quit Notes if it is open.
2. Create a dated ZIP in local temporary staging and test every entry with `unzip -t`.
3. Move the completed ZIP into the destination and write an adjacent SHA-256 checksum.
4. If cleanup is enabled, verify and move redundant archive/checksum pairs to Trash.
5. Reopen Notes if it was open before the backup.
6. If configured, ask Resend to email the result after a successful new backup or a failed attempt.

A lock prevents overlapping runs. Partial archives and checksums are removed after errors, so the destination receives only completed backups.

When `notehold backup` runs in an interactive terminal, it displays milestone messages and an elapsed-time spinner during archive creation. The LaunchAgent does not emit this terminal display.

## Sleeping and failures

The job cannot run while the Mac is shut down or the user is logged out. It catches up after the next login or scheduled check.

If the destination is unavailable, Notehold records the error locally and shows a macOS notification. Because no new archive exists, the next check tries again.

## Installation and files

Each release is copied into a versioned directory before the stable `current` link is switched. Updates preserve settings in the installed LaunchAgent; old program versions remain until uninstall. The downloaded or cloned source directory is not needed after installation.

- Command: `~/.local/bin/notehold`
- Program: `~/Library/Application Support/Notehold/current`
- LaunchAgent: `~/Library/LaunchAgents/io.github.rsheyd.notehold.plist`
- Notes database: `~/Library/Group Containers/group.com.apple.notes`
- Default backups: `~/Backups/Apple Notes`
- Backup log: `notehold.log` in the configured destination
- Fallback log: `~/Library/Logs/notehold.log`
- LaunchAgent output: `~/Library/Logs/notehold-launchd.log`
- Resend API key: the login Keychain item `io.github.rsheyd.notehold.resend` (only when email is configured)

## Troubleshooting

Start with:

```sh
notehold status
```

For the default destination, inspect recent backup activity with:

```sh
tail -50 "$HOME/Backups/Apple Notes/notehold.log"
```

List all completed backups in the configured destination with:

```sh
notehold list
```

If the destination was unavailable, inspect:

```sh
tail -50 ~/Library/Logs/notehold.log
tail -50 ~/Library/Logs/notehold-launchd.log
```

[Return to the Notehold README](../README.md)
