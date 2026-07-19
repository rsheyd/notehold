#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly EMAIL_SCRIPT="$PROJECT_DIR/scripts/send-email.sh"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/notehold-email-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

fake_curl="$work_dir/curl"
request_body="$work_dir/request.json"

/usr/bin/printf '%s\n' \
  '#!/bin/bash' \
  'set -eu' \
  'output=""' \
  'payload=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    -o) output="$2"; shift 2 ;;' \
  '    --data-binary) payload="${2#@}"; shift 2 ;;' \
  '    *) shift ;;' \
  '  esac' \
  'done' \
  '/bin/cp "$payload" "$NOTEHOLD_TEST_REQUEST_BODY"' \
  '/usr/bin/printf '\''{"id":"test-email"}\n'\'' >"$output"' \
  '/usr/bin/printf 200' >"$fake_curl"
/bin/chmod 755 "$fake_curl"

output=$(
  RESEND_EMAIL_TO="s.roman@gmail.com" \
  RESEND_EMAIL_FROM="Notehold <onboarding@resend.dev>" \
  NOTEHOLD_RESEND_API_KEY="re_test" \
  NOTEHOLD_CURL_COMMAND="$fake_curl" \
  NOTEHOLD_TEST_REQUEST_BODY="$request_body" \
    "$EMAIL_SCRIPT" "Backup complete" "The archive is safe."
)

/usr/bin/printf '%s\n' "$output" | /usr/bin/grep -Fq 'Email notification sent to s.roman@gmail.com.'
test "$(/usr/bin/plutil -extract from raw -o - "$request_body")" = "Notehold <onboarding@resend.dev>"
test "$(/usr/bin/plutil -extract to.0 raw -o - "$request_body")" = "s.roman@gmail.com"
test "$(/usr/bin/plutil -extract subject raw -o - "$request_body")" = "Backup complete"
test "$(/usr/bin/plutil -extract text raw -o - "$request_body")" = "The archive is safe."

# With email disabled, the helper exits successfully without needing a key.
"$EMAIL_SCRIPT" "Ignored" "Ignored"

echo "Email tests passed."
