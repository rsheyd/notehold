# Configuring Notehold

Notehold defaults to:

- Backup destination: `~/Backups/Apple Notes`
- Backup interval: 10 days
- Automatic cleanup: enabled
- Email notifications: disabled

Rerun `notehold install` with one of the settings below to change it. Settings you do not supply are preserved.

## Backup destination

Create the destination first, then install with its path:

```sh
BACKUP_DIR="$HOME/path/to/your/backup-folder" notehold install
```

Changing the destination does not move or delete existing archives. Afterward, run `notehold backup` and confirm that the new folder contains a ZIP and adjacent `.sha256` file.

For protection from loss of the Mac, choose an external drive or locally downloaded cloud-synced folder. Confirm cloud backups appear on another device or the provider's website; Notehold verifies local files but cannot verify that cloud upload completed.

## Backup schedule

Set the minimum days between scheduled backups:

```sh
BACKUP_INTERVAL_DAYS=7 notehold install
```

The background job still checks daily and at login. `notehold backup` always creates a backup immediately.

## Automatic cleanup

Cleanup is enabled by default. It keeps the newest backup and recovery points nearest 10, 30, 90, 180, and 365 days old. Redundant verified ZIP and checksum pairs are moved to the Mac Trash, never permanently deleted.

Disable cleanup to retain every completed archive:

```sh
AUTO_CLEANUP=false notehold install
```

Preview what the current policy would move:

```sh
notehold retention preview
```

The newest archive, incomplete pairs, invalid checksum metadata, and archives that fail checksum verification are never moved.

## Email notifications with Resend

Notehold can send an email after it creates and verifies a new backup, and whenever a backup attempt fails. Daily checks that find a recent backup do not send email. A notification-delivery problem is recorded in the backup log but does not invalidate or remove a completed archive.

Create a Resend sending API key and make it available to the current shell as `RESEND_NOTEHOLD_API_TOKEN`. Then configure the destination and sender:

```sh
RESEND_NOTEHOLD_API_TOKEN="$RESEND_NOTEHOLD_API_TOKEN" \
RESEND_EMAIL_TO="you@example.com" \
RESEND_EMAIL_FROM="Notehold <onboarding@resend.dev>" \
notehold install
```

During installation, Notehold copies the API key to the login Keychain. The background LaunchAgent does not read `.zshrc`, and the API key is not stored in the LaunchAgent. Later upgrades reuse the Keychain entry, so the token variable is needed only when initially configuring or replacing the key.

The destination and sender are stored in the LaunchAgent. Resend's `onboarding@resend.dev` sender can send only to the email associated with the Resend account. To send elsewhere, verify a domain in Resend and use an address on that domain, such as `Notehold <backups@updates.example.com>`.

To disable email while preserving the Keychain entry:

```sh
RESEND_EMAIL_TO="" RESEND_EMAIL_FROM="" notehold install
```

[Return to the Notehold README](../README.md)
