#!/bin/bash

set -eu

readonly LABEL="io.github.rsheyd.notehold"
readonly INSTALLED_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
readonly FALLBACK_LOG="$HOME/Library/Logs/notehold.log"

echo "Notehold"
echo

if [ ! -f "$INSTALLED_PLIST" ]; then
  echo "Status: Not installed"
  echo "Run notehold install to install the background backup job."
  exit 1
fi

read_setting() {
  key="$1"
  default_value="$2"
  value=$(/usr/bin/plutil -extract "EnvironmentVariables.$key" raw -o - "$INSTALLED_PLIST" 2>/dev/null || true)
  if [ -n "$value" ]; then
    /usr/bin/printf '%s\n' "$value"
  else
    /usr/bin/printf '%s\n' "$default_value"
  fi
}

backup_dir=$(read_setting BACKUP_DIR "$HOME/Backups/Apple Notes")
backup_interval=$(read_setting BACKUP_INTERVAL_DAYS 10)
auto_cleanup=$(read_setting AUTO_CLEANUP false)

if [ -n "${STATUS_SERVICE_LOADED_FOR_TESTS+x}" ]; then
  service_loaded="$STATUS_SERVICE_LOADED_FOR_TESTS"
elif /bin/launchctl print "gui/$(/usr/bin/id -u)/$LABEL" >/dev/null 2>&1; then
  service_loaded=true
else
  service_loaded=false
fi

if [ "$service_loaded" = "true" ]; then
  echo "Status: Installed and loaded"
else
  echo "Status: Installed but not loaded"
fi

if [ -d "$backup_dir" ]; then
  echo "Destination: $backup_dir (available)"
else
  echo "Destination: $backup_dir (unavailable)"
fi

echo "Backup frequency: Every $backup_interval days"
if [ "$auto_cleanup" = "true" ]; then
  echo "Automatic cleanup: Enabled (only the most recent, 10-day, 30-day, 90-day, 180-day, and 365-day-old backups are retained)"
else
  echo "Automatic cleanup: Disabled (backups are retained indefinitely)"
fi

activity_log="$backup_dir/notehold.log"
if [ ! -f "$activity_log" ]; then
  activity_log="$FALLBACK_LOG"
fi

echo
if [ -f "$activity_log" ]; then
  most_recent_activity=$(/usr/bin/awk 'NF { line=$0 } END { print line }' "$activity_log")
  if [ -n "$most_recent_activity" ]; then
    echo "Most recent activity: $most_recent_activity"
  else
    echo "Most recent activity: None recorded"
  fi
else
  echo "Most recent activity: None recorded"
fi

echo
echo "Recent backups:"
if [ ! -d "$backup_dir" ]; then
  echo "  Unable to check because the destination is unavailable."
  exit 0
fi

recent_backups=$(
  /usr/bin/find "$backup_dir" -maxdepth 1 -type f -name 'apple-notes-*.zip' \
    -exec /usr/bin/stat -f '%m|%N' {} \; |
    /usr/bin/sort -rn |
    /usr/bin/head -3 |
    /usr/bin/cut -d '|' -f2-
)

if [ -z "$recent_backups" ]; then
  echo "  None found."
  exit 0
fi

while IFS= read -r archive; do
  [ -n "$archive" ] || continue
  archive_name=$(/usr/bin/basename "$archive")
  archive_size=$(/usr/bin/du -h "$archive" | /usr/bin/awk '{ print $1 }')
  archive_date=$(/usr/bin/stat -f '%Sm' -t '%B %e, %Y at %l:%M %p' "$archive" | /usr/bin/sed 's/  */ /g')
  echo "  $archive_name ($archive_size, $archive_date)"
done <<EOF
$recent_backups
EOF
