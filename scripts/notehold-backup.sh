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
readonly EMAIL_SCRIPT="$SCRIPT_DIR/send-email.sh"

mkdir -p "$FALLBACK_LOG_DIR"
exec 3>&1
exec >>"$FALLBACK_LOG_FILE" 2>&1

timestamp() { /bin/date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(timestamp) $*"; }

progress() {
  if [ -t 3 ]; then
    /usr/bin/printf '%s\n' "$*" >&3
  fi
}

create_archive() {
  source_dir="$1"
  destination="$2"

  if [ ! -t 3 ]; then
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$source_dir" "$destination"
    return
  fi

  started_at=$(/bin/date '+%s')
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$source_dir" "$destination" &
  archive_pid=$!
  spinner_index=0
  while /bin/kill -0 "$archive_pid" 2>/dev/null; do
    elapsed=$(( $(/bin/date '+%s') - started_at ))
    case "$spinner_index" in
      0) spinner='|' ;;
      1) spinner='/' ;;
      2) spinner='-' ;;
      *) spinner='\' ;;
    esac
    /usr/bin/printf '\r  %s Creating archive… %ss elapsed' "$spinner" "$elapsed" >&3
    spinner_index=$(( (spinner_index + 1) % 4 ))
    /bin/sleep 1
  done

  set +e
  wait "$archive_pid"
  archive_status=$?
  set -e
  archive_pid=""
  /usr/bin/printf '\r%*s\r' 60 '' >&3
  return "$archive_status"
}

send_email_notification() {
  subject="$1"
  body="$2"
  if ! "$EMAIL_SCRIPT" "$subject" "$body"; then
    log "WARNING: email notification could not be delivered."
  fi
}

run_retention_preview() {
  set +e
  retention_output=$("$SCRIPT_DIR/manage-retention.sh" --preview 2>&1)
  retention_status=$?
  set -e
  /usr/bin/printf '%s\n' "$retention_output"
  /usr/bin/printf '%s\n' "$retention_output" >&3
  return "$retention_status"
}

notes_was_open=0
partial_archive=""
partial_checksum=""
archive_pid=""
mode="${1:---force}"

if [ "$mode" != "--force" ] && [ "$mode" != "--if-stale" ] \
  && [ "$mode" != "--retention-preview" ]; then
  echo "Usage: $0 [--force|--if-stale|--retention-preview]" >&2
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
  if [ -n "$archive_pid" ]; then
    /bin/kill "$archive_pid" 2>/dev/null || true
    wait "$archive_pid" 2>/dev/null || true
    archive_pid=""
  fi
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
    send_email_notification \
      "Notehold backup failed on $(/bin/hostname -s)" \
      "Notehold could not create a backup on $(/bin/hostname -s) at $(timestamp). The backup process exited with status $status. Run 'notehold status' and inspect the backup log for details."
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
  run_retention_preview
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
progress "Starting Notehold backup."

if [ ! -d "$NOTES_DIR" ]; then
  log "ERROR: Notes data folder does not exist: $NOTES_DIR"
  exit 1
fi

if /usr/bin/pgrep -x Notes >/dev/null 2>&1; then
  notes_was_open=1
  log "Quitting Notes for a consistent database snapshot."
  progress "Temporarily closing Apple Notes for a consistent snapshot."
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
create_archive "$NOTES_DIR" "$partial_archive"

log "Testing newly created archive."
progress "Verifying the new archive."
/usr/bin/unzip -tqq "$partial_archive"
/bin/mv "$partial_archive" "$archive"
partial_archive=""

checksum=$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')
checksum_file="$archive.sha256"
partial_checksum="$checksum_file.partial"
/usr/bin/printf '%s  %s\n' "$checksum" "$(/usr/bin/basename "$archive")" >"$partial_checksum"
/bin/mv "$partial_checksum" "$checksum_file"
partial_checksum=""

size=$(/usr/bin/du -h "$archive" | /usr/bin/awk '{print $1}')
log "Backup complete: $(/usr/bin/basename "$archive") ($size, SHA-256 $checksum)."
progress "Backup complete: $(/usr/bin/basename "$archive") ($size)."
send_email_notification \
  "Notehold backup completed on $(/bin/hostname -s)" \
  "Notehold created $(/usr/bin/basename "$archive") at $(timestamp). Size: $size. SHA-256: $checksum."

if [ "$AUTO_CLEANUP" = "true" ]; then
  if ! "$SCRIPT_DIR/manage-retention.sh" --apply; then
    log "WARNING: automatic cleanup failed; the verified backup was preserved."
  fi
fi
