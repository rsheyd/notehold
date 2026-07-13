#!/bin/bash

set -eu

readonly NOTES_DIR="${NOTES_DIR:-$HOME/Library/Group Containers/group.com.apple.notes}"
readonly BACKUP_DIR="${BACKUP_DIR:-$HOME/Backups/Apple Notes}"
readonly FALLBACK_LOG_DIR="$HOME/Library/Logs"
readonly FALLBACK_LOG_FILE="$FALLBACK_LOG_DIR/notehold.log"
readonly BACKUP_LOG_FILE="$BACKUP_DIR/notehold.log"
readonly LOCK_DIR="${TMPDIR:-/tmp}/io.github.rsheyd.notehold.lock"
readonly STAGING_DIR="${TMPDIR:-/tmp}/io.github.rsheyd.notehold-staging"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
readonly BACKUP_INTERVAL_DAYS="${BACKUP_INTERVAL_DAYS:-10}"
readonly AUTO_CLEANUP="${AUTO_CLEANUP:-true}"

mkdir -p "$FALLBACK_LOG_DIR"
exec 3>&1
exec >>"$FALLBACK_LOG_FILE" 2>&1

timestamp() { /bin/date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(timestamp) $*"; }

run_manual_retention() {
  retention_mode="$1"
  set +e
  retention_output=$("$SCRIPT_DIR/manage-retention.sh" "$retention_mode" 2>&1)
  retention_status=$?
  set -e
  /usr/bin/printf '%s\n' "$retention_output"
  /usr/bin/printf '%s\n' "$retention_output" >&3
  return "$retention_status"
}

notes_was_open=0
partial_archive=""
partial_checksum=""
mode="${1:---force}"

if [ "$mode" != "--force" ] && [ "$mode" != "--if-stale" ] \
  && [ "$mode" != "--retention-preview" ] && [ "$mode" != "--apply-retention" ]; then
  echo "Usage: $0 [--force|--if-stale|--retention-preview|--apply-retention]" >&2
  exit 2
fi

if [ "$AUTO_CLEANUP" != "true" ] && [ "$AUTO_CLEANUP" != "false" ]; then
  echo "AUTO_CLEANUP must be true or false." >&2
  exit 2
fi

case "$BACKUP_INTERVAL_DAYS" in
  ''|*[!0-9]*)
    echo "BACKUP_INTERVAL_DAYS must be a positive whole number." >&2
    exit 2
    ;;
esac
if [ "$BACKUP_INTERVAL_DAYS" -lt 1 ]; then
  echo "BACKUP_INTERVAL_DAYS must be at least 1." >&2
  exit 2
fi

cleanup() {
  status=$?
  if [ -n "$partial_archive" ] && [ -e "$partial_archive" ]; then
    /bin/rm -f "$partial_archive"
  fi
  if [ -n "$partial_checksum" ] && [ -e "$partial_checksum" ]; then
    /bin/rm -f "$partial_checksum"
  fi
  /bin/rmdir "$LOCK_DIR" 2>/dev/null || true

  if [ "$notes_was_open" -eq 1 ]; then
    /usr/bin/open -a Notes
    log "Reopened Notes."
  fi

  if [ "$status" -ne 0 ]; then
    log "ERROR: backup failed with status $status."
  fi
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
  log "Another backup appears to be running; exiting."
  exit 0
fi

if [ ! -d "$BACKUP_DIR" ]; then
  log "ERROR: backup destination is unavailable: $BACKUP_DIR"
  /usr/bin/osascript \
    -e 'use scripting additions' \
    -e 'on run arguments' \
    -e 'set notificationBody to "Backup destination unavailable: " & item 1 of arguments' \
    -e 'display notification notificationBody with title "Notehold backup failed"' \
    -e 'end run' \
    -- "$BACKUP_DIR" || log "WARNING: could not display failure notification."
  exit 1
fi

exec >>"$BACKUP_LOG_FILE" 2>&1

if [ "$mode" = "--retention-preview" ]; then
  run_manual_retention --preview
  exit 0
fi

if [ "$mode" = "--apply-retention" ]; then
  run_manual_retention --apply
  exit 0
fi

if [ "$mode" = "--if-stale" ]; then
  recent_archive=$(
    /usr/bin/find "$BACKUP_DIR" -maxdepth 1 -type f -name 'apple-notes-*.zip' \
      -mtime -"$BACKUP_INTERVAL_DAYS" -print -quit
  )
  if [ -n "$recent_archive" ]; then
    log "Backup check: a successful archive is less than $BACKUP_INTERVAL_DAYS days old; nothing to do."
    exit 0
  fi
fi

log "Starting Notehold backup."

if [ ! -d "$NOTES_DIR" ]; then
  log "ERROR: Notes data folder does not exist: $NOTES_DIR"
  exit 1
fi

if /usr/bin/pgrep -x Notes >/dev/null 2>&1; then
  notes_was_open=1
  log "Quitting Notes for a consistent database snapshot."
  /usr/bin/osascript -e 'tell application id "com.apple.Notes" to quit'

  attempts=0
  while /usr/bin/pgrep -x Notes >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      log "ERROR: Notes did not quit within 30 seconds."
      exit 1
    fi
    /bin/sleep 1
  done
fi

date_stamp=$(/bin/date '+%Y-%m-%d')
archive="$BACKUP_DIR/apple-notes-$date_stamp.zip"
if [ -e "$archive" ]; then
  archive="$BACKUP_DIR/apple-notes-$date_stamp-$(( $(/bin/date '+%s') )).zip"
fi
/bin/mkdir -p "$STAGING_DIR"
partial_archive="$STAGING_DIR/$(/usr/bin/basename "$archive").partial"

log "Creating $(/usr/bin/basename "$archive") in local staging."
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$NOTES_DIR" "$partial_archive"

log "Testing newly created archive."
/usr/bin/unzip -tqq "$partial_archive"
/bin/mv "$partial_archive" "$archive"
partial_archive=""

checksum=$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')
checksum_file="$archive.sha256"
partial_checksum="$checksum_file.partial"
/usr/bin/printf '%s  %s\n' "$checksum" "$(/usr/bin/basename "$archive")" >"$partial_checksum"
/bin/mv "$partial_checksum" "$checksum_file"
partial_checksum=""

random_archive=$(
  /usr/bin/find "$BACKUP_DIR" -maxdepth 1 -type f -name 'apple-notes-*.zip' ! -path "$archive" -print |
    /usr/bin/awk 'BEGIN { srand() } { if (rand() < 1 / NR) selected=$0 } END { print selected }'
)

if [ -z "$random_archive" ]; then
  random_archive="$archive"
fi

log "Random integrity test: $(/usr/bin/basename "$random_archive")."

random_checksum_file="$random_archive.sha256"
if [ ! -f "$random_checksum_file" ]; then
  log "ERROR: stored checksum is missing for $(/usr/bin/basename "$random_archive")."
  exit 1
fi

expected_checksum=$(/usr/bin/awk 'NR == 1 { print $1 }' "$random_checksum_file")
if ! /usr/bin/printf '%s\n' "$expected_checksum" | /usr/bin/grep -Eq '^[[:xdigit:]]{64}$'; then
  log "ERROR: stored checksum is invalid for $(/usr/bin/basename "$random_archive")."
  exit 1
fi

actual_checksum=$(/usr/bin/shasum -a 256 "$random_archive" | /usr/bin/awk '{print $1}')
if [ "$actual_checksum" != "$expected_checksum" ]; then
  log "ERROR: checksum mismatch for $(/usr/bin/basename "$random_archive")."
  exit 1
fi
log "Checksum verified for $(/usr/bin/basename "$random_archive")."
/usr/bin/unzip -tqq "$random_archive"

size=$(/usr/bin/du -h "$archive" | /usr/bin/awk '{print $1}')
log "Backup complete: $(/usr/bin/basename "$archive") ($size, SHA-256 $checksum)."

if [ "$AUTO_CLEANUP" = "true" ]; then
  if ! "$SCRIPT_DIR/manage-retention.sh" --apply; then
    log "WARNING: automatic cleanup failed; the verified backup was preserved."
  fi
fi
