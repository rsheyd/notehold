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

The release process requires Git and an authenticated [GitHub CLI](https://cli.github.com/). Set `VERSION` to a new version number without a leading `v`, commit the release-ready changes on `main`, and push them to `origin`.

Then create and verify a draft release with:

```sh
scripts/publish-release.sh
```

After reviewing its generated release notes, publish it with:

```sh
scripts/publish-release.sh --publish
```

The helper requires a clean `main` synchronized with `origin/main`. It runs the complete test suite; creates and pushes the annotated tag; builds the archive from that tag; creates or resumes the draft GitHub Release; uploads and downloads the archive and checksum; and verifies the checksum and extracted version before publishing. It is safe to rerun after an interrupted release as long as the existing tag points to the current commit.

Published tags are immutable. If a correction is needed after publishing, increment `VERSION` and create another release instead of moving an existing tag.

### Releasing with Codex

Use this prompt from the Notehold workspace:

```text
Publish the version in VERSION to GitHub Releases. Review the release diff, run the tests, commit and push the release-ready changes if needed, then run scripts/publish-release.sh --publish and verify the published assets.
```

Codex should still summarize the release contents before committing and should not reuse an existing published version number.
