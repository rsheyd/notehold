#!/bin/bash

set -eu

readonly BACKUP_DIR="${BACKUP_DIR:-$HOME/Backups/Apple Notes}"
readonly NOTIFY_RETENTION="${NOTIFY_RETENTION:-true}"
readonly TARGET_AGES="10 20 30 90 180 365"
readonly mode="${1:---preview}"

timestamp() { /bin/date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(timestamp) $*"; }

if [ "$mode" != "--preview" ] && [ "$mode" != "--apply" ]; then
  echo "Usage: $0 [--preview|--apply]" >&2
  exit 2
fi

if [ "$NOTIFY_RETENTION" != "true" ] && [ "$NOTIFY_RETENTION" != "false" ]; then
  echo "NOTIFY_RETENTION must be true or false." >&2
  exit 2
fi

if [ ! -d "$BACKUP_DIR" ]; then
  log "ERROR: backup destination is unavailable: $BACKUP_DIR"
  exit 1
fi

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/apple-notes-retention.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

candidates="$work_dir/candidates.tsv"
selected="$work_dir/selected.txt"
deletions="$work_dir/deletions.txt"
deleted_names="$work_dir/deleted-names.txt"
: >"$candidates"
: >"$selected"
: >"$deletions"
: >"$deleted_names"

today=$(/bin/date '+%Y-%m-%d')
today_epoch=$(/bin/date -j -f '%Y-%m-%d' "$today" '+%s')
/usr/bin/find "$BACKUP_DIR" -maxdepth 1 -type f -name 'apple-notes-*.zip' -print |
  while IFS= read -r archive; do
    checksum_file="$archive.sha256"
    archive_name=$(/usr/bin/basename "$archive")

    if [ ! -f "$checksum_file" ]; then
      log "Retention protected $archive_name: matching checksum file is missing."
      continue
    fi

    expected_checksum=$(/usr/bin/awk 'NR == 1 { print $1 }' "$checksum_file")
    recorded_name=$(/usr/bin/awk 'NR == 1 { print $2 }' "$checksum_file")
    if ! /usr/bin/printf '%s\n' "$expected_checksum" | /usr/bin/grep -Eq '^[[:xdigit:]]{64}$' \
      || [ "$recorded_name" != "$archive_name" ]; then
      log "Retention protected $archive_name: checksum metadata is invalid or mismatched."
      continue
    fi

    archive_date=$(/usr/bin/printf '%s\n' "${archive_name#apple-notes-}" | /usr/bin/cut -c1-10)
    if ! /usr/bin/printf '%s\n' "$archive_date" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
      log "Retention protected $archive_name: archive date cannot be read from its filename."
      continue
    fi
    if ! archive_epoch=$(/bin/date -j -f '%Y-%m-%d' "$archive_date" '+%s' 2>/dev/null); then
      log "Retention protected $archive_name: archive date in filename is invalid."
      continue
    fi

    modified=$(/usr/bin/stat -f '%m' "$archive")
    age_days=$(( (today_epoch - archive_epoch) / 86400 ))
    if [ "$age_days" -lt 0 ]; then
      age_days=0
    fi
    /usr/bin/printf '%s\t%s\t%s\n' "$age_days" "$modified" "$archive" >>"$candidates"
  done

if [ ! -s "$candidates" ]; then
  log "Retention: no valid archive/checksum pairs found; nothing to do."
  exit 0
fi

newest=$(/usr/bin/sort -t "$(/usr/bin/printf '\t')" -k2,2nr "$candidates" | /usr/bin/head -1 | /usr/bin/awk -F '\t' '{ print $3 }')
/usr/bin/printf '%s\n' "$newest" >>"$selected"

for target in $TARGET_AGES; do
  choice=$(
    /usr/bin/awk -F '\t' -v target="$target" '
      NR == FNR { selected[$0] = 1; next }
      !selected[$3] {
        difference = $1 - target
        if (difference < 0) difference = -difference
        if (!found || difference < best_difference || (difference == best_difference && $2 > best_modified)) {
          found = 1
          best_difference = difference
          best_modified = $2
          best_path = $3
        }
      }
      END { if (found) print best_path }
    ' "$selected" "$candidates"
  )
  if [ -n "$choice" ]; then
    /usr/bin/printf '%s\n' "$choice" >>"$selected"
  fi
done

/usr/bin/awk -F '\t' '
  NR == FNR { selected[$0] = 1; next }
  !selected[$3] { print $3 }
' "$selected" "$candidates" >"$deletions"

log "Retention plan: protecting the newest archive plus backups nearest 10, 20, 30, 90, 180, and 365 days old."
while IFS= read -r archive; do
  [ -n "$archive" ] || continue
  age_days=$(/usr/bin/awk -F '\t' -v path="$archive" '$3 == path { print $1; exit }' "$candidates")
  log "Retention keep: $(/usr/bin/basename "$archive") (approximately $age_days days old)."
done <"$selected"

if [ ! -s "$deletions" ]; then
  log "Retention: no redundant valid archive pairs found."
  exit 0
fi

if [ "$mode" = "--preview" ]; then
  while IFS= read -r archive; do
    [ -n "$archive" ] || continue
    log "Retention preview would delete: $(/usr/bin/basename "$archive") and its checksum."
  done <"$deletions"
  log "Retention preview only: no files were deleted."
  exit 0
fi

deleted_count=0
while IFS= read -r archive; do
  [ -n "$archive" ] || continue
  checksum_file="$archive.sha256"
  archive_name=$(/usr/bin/basename "$archive")
  expected_checksum=$(/usr/bin/awk 'NR == 1 { print $1 }' "$checksum_file")
  actual_checksum=$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{ print $1 }')

  if [ "$actual_checksum" != "$expected_checksum" ]; then
    log "Retention protected $archive_name: checksum verification failed before deletion."
    continue
  fi

  if /bin/rm -f "$archive"; then
    /bin/rm -f "$checksum_file"
    deleted_count=$((deleted_count + 1))
    /usr/bin/printf '%s\n' "$archive_name" >>"$deleted_names"
    log "Retention deleted: $archive_name and its checksum."
  else
    log "ERROR: retention could not delete $archive_name; its checksum was preserved."
  fi
done <"$deletions"

if [ "$deleted_count" -gt 0 ] && [ "$NOTIFY_RETENTION" = "true" ]; then
  if [ "$deleted_count" -eq 1 ]; then
    notification_body="Deleted 1 redundant archive: $(/usr/bin/head -1 "$deleted_names")."
  else
    notification_body="Deleted $deleted_count redundant archives. See the backup log for filenames."
  fi
  /usr/bin/osascript \
    -e 'use scripting additions' \
    -e 'on run arguments' \
    -e 'set notificationBody to item 1 of arguments' \
    -e 'display notification notificationBody with title "Apple Notes backup retention"' \
    -e 'end run' \
    -- "$notification_body" || log "WARNING: could not display retention notification."
fi

log "Retention complete: deleted $deleted_count redundant archive pair(s)."
