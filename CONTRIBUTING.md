# Developing and releasing Notehold

Notehold is a small macOS command-line utility. Keep `main` release-ready, update `VERSION` for every release, and never reuse a published version number for different files. The installer treats released versions as immutable so upgrades remain predictable.

## Test local changes

Run the complete test suite from the repository root:

```sh
for test in tests/test-*.sh; do
  bash "$test"
done
```

Also run a manual backup or status check when a change affects macOS permissions, launchd behavior, the Notes database, or installed paths.

## Publish a GitHub release

The release process requires Git and an authenticated [GitHub CLI](https://cli.github.com/). The commands below assume the release-ready commit is on `main` and has been pushed to `origin`.

### 1. Prepare the version

Set `VERSION` to the new version number without a leading `v`, update the documentation, and commit the release-ready changes. Then run the tests and confirm that the working tree and remote branch agree:

```sh
version=$(tr -d '\n' < VERSION)
tag="v$version"

git status --short
git fetch origin
test "$(git branch --show-current)" = "main"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
./notehold version
```

`git status --short` should print nothing, and `notehold version` should report the version in `VERSION`.

### 2. Tag the release

Create an annotated tag at the release commit and push it:

```sh
git tag -a "$tag" -m "Notehold $version"
git push origin "$tag"
```

Published tags are immutable. If a correction is needed after publishing, increment `VERSION` and create another release instead of moving the existing tag.

### 3. Build and verify the assets

Create the installation archive from the tag, not from uncommitted files or the working tree:

```sh
git archive \
  --format=tar.gz \
  --prefix="notehold-$version/" \
  --output="/tmp/notehold-$version.tar.gz" \
  "$tag"

(
  cd /tmp
  shasum -a 256 "notehold-$version.tar.gz" \
    > "notehold-$version.tar.gz.sha256"
  shasum -a 256 -c "notehold-$version.tar.gz.sha256"
)

tar -tzf "/tmp/notehold-$version.tar.gz"
```

Confirm that the checksum succeeds and the archive contains one top-level `notehold-VERSION` directory with the expected program files.

### 4. Create and publish the release

Create a draft release with both assets attached:

```sh
gh release create "$tag" \
  "/tmp/notehold-$version.tar.gz" \
  "/tmp/notehold-$version.tar.gz.sha256" \
  --title "Notehold $version" \
  --generate-notes \
  --draft
```

Review the draft on the [Notehold releases page](https://github.com/rsheyd/notehold/releases). Edit the generated notes so they briefly cover user-visible changes, installation or upgrade implications, and any changed safety defaults. Then publish it in GitHub, or run:

```sh
gh release edit "$tag" --draft=false
```

### 5. Verify the published release

Confirm that GitHub shows the correct tag and both assets:

```sh
gh release view "$tag"

release_test=$(mktemp -d)
gh release download "$tag" --dir "$release_test"
(
  cd "$release_test"
  shasum -a 256 -c "notehold-$version.tar.gz.sha256"
  tar -xzf "notehold-$version.tar.gz"
  "notehold-$version/notehold" version
)
```

The checksum must pass and the extracted command must report the published version. For significant installer changes, also test `./notehold install` from the extracted archive on macOS.
