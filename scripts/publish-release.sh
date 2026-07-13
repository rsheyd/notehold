#!/bin/bash

set -eu

publish=false
case "${1:-}" in
  '') ;;
  --publish) publish=true ;;
  -h|--help)
    cat <<'EOF'
Usage: scripts/publish-release.sh [--publish]

Create or resume a verified draft GitHub release for the version in VERSION.
Pass --publish to publish it after verification.
EOF
    exit 0
    ;;
  *)
    echo "Usage: scripts/publish-release.sh [--publish]" >&2
    exit 2
    ;;
esac

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$PROJECT_DIR"

for command_name in git gh shasum tar; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command_name" >&2
    exit 1
  fi
done

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree must be clean before publishing a release." >&2
  exit 1
fi

if [ "$(git branch --show-current)" != "main" ]; then
  echo "Releases must be published from main." >&2
  exit 1
fi

gh auth status >/dev/null
git fetch origin --tags

if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "Local main and origin/main must point to the same commit." >&2
  exit 1
fi

version=$(/usr/bin/tr -d '\n' < VERSION)
case "$version" in
  ''|*[!0-9A-Za-z._-]*)
    echo "VERSION contains unsupported characters: $version" >&2
    exit 1
    ;;
esac
readonly version
readonly tag="v$version"

if [ "$(./notehold version)" != "Notehold $version" ]; then
  echo "notehold version does not match VERSION." >&2
  exit 1
fi

for test_file in tests/test-*.sh; do
  echo "Running $test_file"
  /bin/bash "$test_file"
done

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  if [ "$(git rev-parse "$tag^{}")" != "$(git rev-parse HEAD)" ]; then
    echo "$tag already exists at a different commit." >&2
    exit 1
  fi
else
  git tag -a "$tag" -m "Notehold $version"
fi
git push origin "refs/tags/$tag"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/notehold-release.XXXXXX")
trap '/bin/rm -rf "$work_dir"' EXIT HUP INT TERM
readonly archive="$work_dir/notehold-$version.tar.gz"
readonly checksum="$archive.sha256"

verify_downloaded_release() {
  download_dir="$work_dir/download"
  /bin/rm -rf "$download_dir"
  /bin/mkdir -p "$download_dir"
  gh release download "$tag" --dir "$download_dir" \
    --pattern "notehold-$version.tar.gz" \
    --pattern "notehold-$version.tar.gz.sha256"
  (
    cd "$download_dir"
    /usr/bin/shasum -a 256 -c "notehold-$version.tar.gz.sha256"
    /usr/bin/tar -xzf "notehold-$version.tar.gz"
    test "$("notehold-$version/notehold" version)" = "Notehold $version"
  )
}

release_is_draft=$(gh release view "$tag" --json isDraft --jq '.isDraft' 2>/dev/null || true)
if [ "$release_is_draft" = "false" ]; then
  verify_downloaded_release
  echo "Notehold $version is already published and verified."
  exit 0
fi

git archive \
  --format=tar.gz \
  --prefix="notehold-$version/" \
  --output="$archive" \
  "$tag"
(
  cd "$work_dir"
  /usr/bin/shasum -a 256 "notehold-$version.tar.gz" \
    > "notehold-$version.tar.gz.sha256"
  /usr/bin/shasum -a 256 -c "notehold-$version.tar.gz.sha256"
  /usr/bin/tar -tzf "notehold-$version.tar.gz" >/dev/null
)

if [ -z "$release_is_draft" ]; then
  gh release create "$tag" \
    --title "Notehold $version" \
    --generate-notes \
    --draft
fi

gh release upload "$tag" "$archive" "$checksum" --clobber
verify_downloaded_release

if [ "$publish" = "true" ]; then
  gh release edit "$tag" --draft=false
  echo "Published and verified Notehold $version."
else
  echo "Created and verified draft release Notehold $version."
  echo "Publish it with: scripts/publish-release.sh --publish"
fi

gh release view "$tag"
