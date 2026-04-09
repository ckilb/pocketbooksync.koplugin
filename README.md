# KOReader Pocketbook Sync

A KOReader plugin that syncs reading progress from KOReader to PocketBook
Library, primarily to make the book progress bars on PocketBook's home screen
accurate.

Optionally (toggle in the Plugins menu), books marked as finished will be
hidden from the home screen.

## Installation

Copy the folder *pocketbooksync.koplugin* to */applications/koreader/plugins* on your PocketBook device.\
Please mind to keep the folder name as it is.

## Usage

After you've installed the KOReader plugin, syncing will happen silently with each page update.

Note that the sync is only one way (from KOReader), and it only syncs the
progress bars to Library. It is not meant to sync the reading position between
KOReader and PBReader.

For further information, read the corresponding thread on MobileRead:
https://www.mobileread.com/forums/showthread.php?t=354026

## Boot logo: Current page

If the Boot Logo in PocketBook's Personalize settings is set to "Current
Page", this plugin calls a native PocketBook function to snapshot the last
page just before going to sleep. This allows one to resume reading much sooner
after powering the device back on after automatic power-off.

To avoid the "Opening file …" screen, copy
[2-skip-first-repaint.lua](patches/2-skip-first-repaint.lua) to
`/applications/koreader/patches`.

## Development

This project uses [release-please][] to automate releases.
When new commits are pushed to the main branch, release-please automatically opens a release pull request.
Once the release PR is merged, a new release is created and the changelog is updated.

Note that release-please requires commits to follow the [Conventional Commits][] specification and will silently skip other commits.

[release-please]: https://github.com/googleapis/release-please
[Conventional Commits]: https://www.conventionalcommits.org/
