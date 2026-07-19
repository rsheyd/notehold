#!/bin/bash

set -eu

readonly KEYCHAIN_SERVICE="io.github.rsheyd.notehold.resend"
readonly EMAIL_TO="${RESEND_EMAIL_TO:-}"
readonly EMAIL_FROM="${RESEND_EMAIL_FROM:-}"
readonly API_URL="${NOTEHOLD_RESEND_API_URL:-https://api.resend.com/emails}"
readonly CURL_COMMAND="${NOTEHOLD_CURL_COMMAND:-/usr/bin/curl}"

log() { echo "$*"; }

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 SUBJECT BODY" >&2
  exit 2
fi

if [ -z "$EMAIL_TO" ] || [ -z "$EMAIL_FROM" ]; then
  exit 0
fi

api_key="${NOTEHOLD_RESEND_API_KEY:-}"
if [ -z "$api_key" ]; then
  api_key=$(
    /usr/bin/security find-generic-password \
      -a "$(/usr/bin/id -un)" \
      -s "$KEYCHAIN_SERVICE" \
      -w 2>/dev/null || true
  )
fi
if [ -z "$api_key" ]; then
  log "WARNING: email notification was not sent because the Resend API key is unavailable."
  exit 1
fi

payload=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/notehold-email.XXXXXX")
response=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/notehold-email-response.XXXXXX")
cleanup() {
  /bin/rm -f "$payload" "$response"
}
trap cleanup EXIT HUP INT TERM

/usr/bin/plutil -create xml1 "$payload"
/usr/bin/plutil -insert from -string "$EMAIL_FROM" "$payload"
/usr/bin/plutil -insert to -json '[]' "$payload"
/usr/bin/plutil -insert to.0 -string "$EMAIL_TO" "$payload"
/usr/bin/plutil -insert subject -string "$1" "$payload"
/usr/bin/plutil -insert text -string "$2" "$payload"
/usr/bin/plutil -convert json "$payload"

set +e
http_status=$(
  "$CURL_COMMAND" -sS \
    -o "$response" \
    -w '%{http_code}' \
    -X POST "$API_URL" \
    -H "Authorization: Bearer $api_key" \
    -H 'Content-Type: application/json' \
    --data-binary "@$payload"
)
curl_status=$?
set -e

if [ "$curl_status" -ne 0 ]; then
  log "WARNING: Resend email notification failed to connect (curl status $curl_status)."
  exit 1
fi

case "$http_status" in
  2??)
    log "Email notification sent to $EMAIL_TO."
    ;;
  *)
    error_summary=$(/usr/bin/tr '\n' ' ' <"$response" | /usr/bin/cut -c1-300)
    log "WARNING: Resend rejected the email notification (HTTP $http_status): $error_summary"
    exit 1
    ;;
esac
