#!/bin/bash

set -eu

readonly LABEL="io.github.apple-notes-backup"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SOURCE_PLIST="$PROJECT_DIR/$LABEL.plist"
readonly INSTALL_DIR="$HOME/Library/LaunchAgents"
readonly INSTALLED_PLIST="$INSTALL_DIR/$LABEL.plist"
readonly LOG_FILE="$HOME/Library/Logs/apple-notes-backup-launchd.log"
readonly BACKUP_DESTINATION="${BACKUP_DIR:-$HOME/Backups/Apple Notes}"
readonly BACKUP_AGE_SETTING="${MAX_BACKUP_AGE_DAYS:-10}"
readonly AUTO_CLEANUP_SETTING="${AUTO_CLEANUP:-false}"

if [ "$AUTO_CLEANUP_SETTING" != "true" ] && [ "$AUTO_CLEANUP_SETTING" != "false" ]; then
  echo "AUTO_CLEANUP must be true or false." >&2
  exit 2
fi

case "$BACKUP_AGE_SETTING" in
  ''|*[!0-9]*)
    echo "MAX_BACKUP_AGE_DAYS must be a positive whole number." >&2
    exit 2
    ;;
esac
if [ "$BACKUP_AGE_SETTING" -lt 1 ]; then
  echo "MAX_BACKUP_AGE_DAYS must be at least 1." >&2
  exit 2
fi

/bin/mkdir -p "$INSTALL_DIR" "$BACKUP_DESTINATION"

temporary_plist=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/$LABEL.XXXXXX.plist")
cleanup() {
  /bin/rm -f "$temporary_plist"
}
trap cleanup EXIT HUP INT TERM

/bin/cp "$SOURCE_PLIST" "$temporary_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 \"$SCRIPT_DIR/backup-apple-notes.sh\"" "$temporary_plist"
/usr/bin/plutil -replace EnvironmentVariables.BACKUP_DIR -string "$BACKUP_DESTINATION" "$temporary_plist"
/usr/bin/plutil -replace EnvironmentVariables.MAX_BACKUP_AGE_DAYS -string "$BACKUP_AGE_SETTING" "$temporary_plist"
/usr/bin/plutil -replace EnvironmentVariables.AUTO_CLEANUP -string "$AUTO_CLEANUP_SETTING" "$temporary_plist"
/usr/bin/plutil -replace StandardOutPath -string "$LOG_FILE" "$temporary_plist"
/usr/bin/plutil -replace StandardErrorPath -string "$LOG_FILE" "$temporary_plist"
/usr/bin/plutil -lint "$temporary_plist"
/bin/mv "$temporary_plist" "$INSTALLED_PLIST"

/bin/launchctl bootout "gui/$(/usr/bin/id -u)/$LABEL" 2>/dev/null || true
/bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$INSTALLED_PLIST"
/bin/launchctl print "gui/$(/usr/bin/id -u)/$LABEL"
