#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly BACKUP_SCRIPT="$PROJECT_DIR/scripts/backup-apple-notes.sh"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/apple-notes-status-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

test_home="$work_dir/home"
backup_dir="$work_dir/backups"
plist="$test_home/Library/LaunchAgents/io.github.apple-notes-backup.plist"
/bin/mkdir -p "$test_home/Library/LaunchAgents" "$test_home/Library/Logs" "$backup_dir"
/bin/cp "$PROJECT_DIR/io.github.apple-notes-backup.plist" "$plist"
/usr/bin/plutil -replace EnvironmentVariables.BACKUP_DIR -string "$backup_dir" "$plist"
/usr/bin/plutil -replace EnvironmentVariables.BACKUP_INTERVAL_DAYS -string 10 "$plist"
/usr/bin/plutil -replace EnvironmentVariables.AUTO_CLEANUP -string true "$plist"

for day in 10 11 12 13; do
  archive="$backup_dir/apple-notes-2026-07-$day.zip"
  /usr/bin/printf 'backup %s\n' "$day" >"$archive"
  /usr/bin/touch -t "202607${day}1200" "$archive"
done
/usr/bin/printf '2026-07-13 12:01:00 Backup complete: apple-notes-2026-07-13.zip.\n' \
  >"$backup_dir/apple-notes-backup.log"

status_output=$(
  HOME="$test_home" STATUS_SERVICE_LOADED_FOR_TESTS=true RENDER_API_KEY=must-not-appear \
    "$BACKUP_SCRIPT" --status
)

/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'Status: Installed and loaded'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'Notehold'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq "Destination: $backup_dir (available)"
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'Backup frequency: Every 10 days'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'Automatic cleanup: Enabled (only the most recent, 10-day, 30-day, 90-day, 180-day, and 365-day-old backups are retained)'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'Most recent activity: 2026-07-13 12:01:00 Backup complete'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'apple-notes-2026-07-13.zip'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'apple-notes-2026-07-12.zip'
/usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'apple-notes-2026-07-11.zip'
if /usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'apple-notes-2026-07-10.zip'; then
  echo "Status displayed more than three backups." >&2
  exit 1
fi
if /usr/bin/printf '%s\n' "$status_output" | /usr/bin/grep -Fq 'must-not-appear'; then
  echo "Status exposed an unrelated environment variable." >&2
  exit 1
fi

missing_dir="$work_dir/missing"
/usr/bin/plutil -replace EnvironmentVariables.BACKUP_DIR -string "$missing_dir" "$plist"
missing_output=$(HOME="$test_home" STATUS_SERVICE_LOADED_FOR_TESTS=false "$BACKUP_SCRIPT" --status)
/usr/bin/printf '%s\n' "$missing_output" | /usr/bin/grep -Fq "Destination: $missing_dir (unavailable)"
/usr/bin/printf '%s\n' "$missing_output" | /usr/bin/grep -Fq 'Unable to check because the destination is unavailable.'

echo "Status tests passed."
