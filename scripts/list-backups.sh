#!/bin/bash

set -eu

readonly BACKUP_DIR="${BACKUP_DIR:-$HOME/Backups/Apple Notes}"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup destination is unavailable: $BACKUP_DIR" >&2
  exit 1
fi

archives=$(
  /usr/bin/find "$BACKUP_DIR" -maxdepth 1 -type f -name 'apple-notes-*.zip' \
    -exec /usr/bin/stat -f '%m|%N' {} \; |
    /usr/bin/sort -rn |
    /usr/bin/cut -d '|' -f2-
)

echo "Notehold backups"
echo "Destination: $BACKUP_DIR"
echo

if [ -z "$archives" ]; then
  echo "No backups found."
  exit 0
fi

while IFS= read -r archive; do
  [ -n "$archive" ] || continue
  archive_name=$(/usr/bin/basename "$archive")
  archive_size=$(/usr/bin/du -h "$archive" | /usr/bin/awk '{ print $1 }')
  archive_date=$(/usr/bin/stat -f '%Sm' -t '%Y-%m-%d %l:%M %p' "$archive" | /usr/bin/sed 's/  */ /g')
  if [ -f "$archive.sha256" ]; then
    checksum_status="checksum present"
  else
    checksum_status="checksum missing"
  fi
  echo "$archive_name  $archive_size  $archive_date  $checksum_status"
done <<EOF
$archives
EOF
