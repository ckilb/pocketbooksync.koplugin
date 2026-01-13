# KOReader Pocketbook Sync

A KOReader plugin that syncs reading progress from KOReader to PocketBook
Library, primarily to make the book progress bars on PocketBook's home screen
accurate.

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

## Fork Changes

This custom fork has following changes:

* After deleting the file, it's also deleted from the Pocketbook database, so there's no ghost entries on the home screen for the removed books.
* Plugin keeps the open page snapshot, the same way the built-in reader does it, so you can configure the device to display it during the power up process.
