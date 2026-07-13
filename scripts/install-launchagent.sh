#!/bin/bash

set -eu

readonly LABEL="io.github.rsheyd.notehold"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -L)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SOURCE_PLIST="$PROJECT_DIR/$LABEL.plist"
readonly INSTALL_DIR="$HOME/Library/LaunchAgents"
readonly INSTALLED_PLIST="$INSTALL_DIR/$LABEL.plist"
readonly LOG_FILE="$HOME/Library/Logs/notehold-launchd.log"

read_installed_setting() {
  key="$1"
  default_value="$2"
  value=""
  if [ -f "$INSTALLED_PLIST" ]; then
    value=$(/usr/bin/plutil -extract "EnvironmentVariables.$key" raw -o - "$INSTALLED_PLIST" 2>/dev/null || true)
  fi
  if [ -n "$value" ]; then
    /usr/bin/printf '%s\n' "$value"
  else
    /usr/bin/printf '%s\n' "$default_value"
  fi
}

backup_destination_was_explicit=false
if [ -n "${BACKUP_DIR+x}" ]; then
  backup_destination_was_explicit=true
  BACKUP_DESTINATION="$BACKUP_DIR"
else
  BACKUP_DESTINATION=$(read_installed_setting BACKUP_DIR "$HOME/Backups/Apple Notes")
fi
if [ -n "${BACKUP_INTERVAL_DAYS+x}" ]; then
  BACKUP_INTERVAL_SETTING="$BACKUP_INTERVAL_DAYS"
else
  BACKUP_INTERVAL_SETTING=$(read_installed_setting BACKUP_INTERVAL_DAYS 10)
fi
if [ -n "${AUTO_CLEANUP+x}" ]; then
  AUTO_CLEANUP_SETTING="$AUTO_CLEANUP"
else
  AUTO_CLEANUP_SETTING=$(read_installed_setting AUTO_CLEANUP true)
fi
readonly BACKUP_DESTINATION BACKUP_INTERVAL_SETTING AUTO_CLEANUP_SETTING

if [ "$backup_destination_was_explicit" = "true" ] && [ ! -d "$BACKUP_DESTINATION" ]; then
  echo "Backup destination was not found: $BACKUP_DESTINATION" >&2
  echo "Choose an existing folder or create this folder, then run the installer again." >&2
  exit 2
fi

if [ "$AUTO_CLEANUP_SETTING" != "true" ] && [ "$AUTO_CLEANUP_SETTING" != "false" ]; then
  echo "AUTO_CLEANUP must be true or false." >&2
  exit 2
fi

case "$BACKUP_INTERVAL_SETTING" in
  ''|*[!0-9]*)
    echo "BACKUP_INTERVAL_DAYS must be a positive whole number." >&2
    exit 2
    ;;
esac
if [ "$BACKUP_INTERVAL_SETTING" -lt 1 ]; then
  echo "BACKUP_INTERVAL_DAYS must be at least 1." >&2
  exit 2
fi

/bin/mkdir -p "$INSTALL_DIR"
if [ ! -d "$BACKUP_DESTINATION" ] && [ ! -f "$INSTALLED_PLIST" ]; then
  /bin/mkdir -p "$BACKUP_DESTINATION"
fi

for candidate_plist in "$INSTALL_DIR"/*.plist; do
  [ -e "$candidate_plist" ] || continue
  [ "$candidate_plist" = "$INSTALLED_PLIST" ] && continue

  candidate_program=$(
    /usr/bin/plutil -extract ProgramArguments.0 raw -o - "$candidate_plist" 2>/dev/null || true
  )
  if [ "$candidate_program" = "$SCRIPT_DIR/notehold-backup.sh" ]; then
    candidate_label=$(
      /usr/bin/plutil -extract Label raw -o - "$candidate_plist" 2>/dev/null || true
    )
    echo "Another LaunchAgent already uses this backup script: ${candidate_label:-$candidate_plist}" >&2
    echo "Disable or remove that job before installing $LABEL to avoid duplicate backup checks." >&2
    exit 2
  fi
done

temporary_plist=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/$LABEL.XXXXXX.plist")
cleanup() {
  /bin/rm -f "$temporary_plist"
}
trap cleanup EXIT HUP INT TERM

/bin/cp "$SOURCE_PLIST" "$temporary_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 \"$SCRIPT_DIR/notehold-backup.sh\"" "$temporary_plist"
/usr/bin/plutil -replace EnvironmentVariables.BACKUP_DIR -string "$BACKUP_DESTINATION" "$temporary_plist"
/usr/bin/plutil -replace EnvironmentVariables.BACKUP_INTERVAL_DAYS -string "$BACKUP_INTERVAL_SETTING" "$temporary_plist"
/usr/bin/plutil -replace EnvironmentVariables.AUTO_CLEANUP -string "$AUTO_CLEANUP_SETTING" "$temporary_plist"
/usr/bin/plutil -replace StandardOutPath -string "$LOG_FILE" "$temporary_plist"
/usr/bin/plutil -replace StandardErrorPath -string "$LOG_FILE" "$temporary_plist"
/usr/bin/plutil -lint "$temporary_plist" >/dev/null
/bin/mv "$temporary_plist" "$INSTALLED_PLIST"

if [ "${NOTEHOLD_SKIP_LAUNCHCTL_FOR_TESTS:-false}" != "true" ]; then
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$LABEL" 2>/dev/null || true
  /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$INSTALLED_PLIST"
  if ! /bin/launchctl print "gui/$(/usr/bin/id -u)/$LABEL" >/dev/null; then
    echo "The LaunchAgent was installed but could not be read back." >&2
    exit 1
  fi
fi

echo "Notehold installed successfully."
echo "  Backup destination: $BACKUP_DESTINATION"
echo "  Backup frequency: every $BACKUP_INTERVAL_SETTING days"
if [ "$AUTO_CLEANUP_SETTING" = "true" ]; then
  echo "  Automatic cleanup: true (only the most recent, 10-day, 30-day, 90-day, 180-day, and 365-day-old backups are retained)"
else
  echo "  Automatic cleanup: false (backups are retained indefinitely)"
fi
echo "  Background check: at login and approximately once every 24 hours"
