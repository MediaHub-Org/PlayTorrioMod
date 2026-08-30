# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md);
this file stays about what is left.

Last reconciled against the tree: **2026-08-30** (v1.1.3+11, dev channel).

## Navigation principle

Three top-level hubs are the core navigation: **Watch**, **Listen**, **Read**.
Each has exactly four sections, the fourth always being Library:

| Hub    | Sections                                    |
|:-------|:--------------------------------------------|
| Watch  | Movies/Series · Anime · Live TV · Library   |
| Listen | Music · Podcasts · Radio · Library          |
| Read   | Audiobooks · Books · Comics/Manga · Library |

Phones show hubs as icon pills in the header and sections in the bottom bar;
tablet and desktop show sections as a chip row instead. Search, filters,
favourites and playback stay consistent across every section — that
cross-cutting consistency is what "unified" means here, not the content.

Any proposal to merge, flatten or collapse distinct content-type sections, or
to make one hub have a different number of sections than the others, should be
checked against this first.

## Blocked on a device

Nothing in this group can be closed from CI. Every item is implemented and
passing `flutter analyze` + the test suite; none has been run on hardware.

| # | Area                                   | What specifically needs checking                                                                                                                                                                                                                                                                          |
|---|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **Media session** (shipped 2026-08-30) | Track title/artist/art in the Android shade; play/pause/skip/stop; audio surviving backgrounding; whether tapping the notification returns to the running app rather than restarting it. iOS lock screen and Control Center likewise.                                                                     |
| 2 | **media_kit/libmpv playback**          | The engine swap (2026-08-28) changed torrent streaming, live IPTV, subtitle rendering, decoder presets and the volume-boost gesture. Needs a hands-on pass across movie / series / anime / IPTV / music / audiobook. The `mediacodec-copy` fix for the Android black screen (2026-08-29) is part of this. |
| 3 | **Resume across sources**              | `ContinueWatchingService` absorbed `PlaybackHistoryService`. Resume across movie / series / anime / torrent paths is unconfirmed on a device.                                                                                                                                                             |
| 4 | **QA on all five platforms**           | Mobile, tablet, desktop, TV. TV needs its own D-pad/remote-input pass. Most work to date has only been exercised on Windows desktop and in CI.                                                                                                                                                            |

Once a build has actually been through this, clear `AppInfo.channel` and the
`(dev)` marker disappears from the app and from release titles.

## Code and consistency

| # | Task                                                                                              | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                       |
|---|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 5 | **Migrate Anime onto `BrowseScaffold`**                                                           | Anime has its own hero carousel and its own row widget that do the same job. `BrowseScaffold` gained row subtitles and desktop scroll arrows (2026-08-30) so the migration no longer costs anime any feature; what is left is the `ContinueWatchingSlider` slot between hero and rows, and the Arabic-mode branch, which doubles every row. Worth doing, but it is 600 lines of churn on a page that cannot be checked without running it. |
| 6 | **35 files do ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)` | 35 independent call sites, no shared risk, no user-visible bug. Migrate opportunistically when a file is touched for another reason, not as a batch pass.                                                                                                                                                                                                                                                                                  |
| 7 | **`music_page.dart` is 5,220 lines**                                                              | Four other files are over 2,000. Splitting is worthwhile but is a refactor with no user-visible payoff, so it waits behind anything that a user would notice.                                                                                                                                                                                                                                                                              |
| 8 | **GitHub Actions may be pinned to Node-20 majors**                                                | Deliberately not bumped blind: verify the current major for each action against its own releases page first, then bump in one commit and watch a full six-platform dispatch.                                                                                                                                                                                                                                                               |

## Content sources

| #  | Task                           | State                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|----|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 9  | **Comics data source**         | `ComicsPage` is an honest empty state, not a placeholder pretending to load. Two leads checked 2026-08-29: `newcomic.info` routes every `.cbr` through `florenfile.com` behind Cloudflare's JS challenge — dead for a server-side fetch. `readcomicsonline.lol` looks structurally right (own CDN, direct `.webp` per page, no archive extraction, same shape as Manga) but its chapter/page data loads client-side and the underlying endpoint did not surface from its JS bundles. Confirming it needs live devtools inspection by a human, not blind guessing. |
| 10 | **Cast photos for Audiobooks** | Movies/Series, Anime and Manga all have them. Audiobooks stays blocked: AniList does not catalog narrators, and AudiobookBay's listing HTML has no narrator field beyond free text. Would need a narrator-photo database that does not appear to exist publicly.                                                                                                                                                                                                                                                                                                  |

## Signing and releases

- **Android release signing needs two repository secrets** — `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`. Until they exist, every build is signed with a throwaway debug key, which means each new APK refuses to install over the last one and the in-app updater cannot work. See [release signing](configuration.md#release-signing). The keystore must be generated locally: it is a long-lived credential and should not pass through a chat transcript or CI logs.
- **No other platform needs signing for updates**, because none of them self-install. See the table in `configuration.md`.

## Declined, so they do not get re-litigated

- **A drawer for mobile hub switching.** Hub pills in the header plus the bottom section bar already cover every width. A drawer would be a third copy of the same control.
- **A unified hub+submenu component.** The header and section bars already read as one stacked unit. The only trigger to reopen is mobile's stacked chrome becoming an actual complaint.
- **Forcing all four playback controllers onto one `PlaybackCoordinator` contract.** Costs a real adapter per controller type to save two duplicated lines, with no current bug. Revisit if a fifth playback type forgets the sync.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field, ~88 mostly-minor channels. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
- **Putting Books on `BrowseScaffold`.** Checked 2026-08-30: `BookResult` carries no cover URL at all — libgen's list view does not expose one — so a hero and poster rows would render as blank rectangles. The current text-row list is the right layout for cover-less metadata. Reopen only if a cover source appears.
- **Replacing Manga's grid with `BrowseScaffold`'s rows.** Manga's grid is infinite-scrolling and its card density is a user setting (`MangaSettings.cardDensity`, with a customizer sheet). Fixed-length rows would remove both. Manga could gain a hero *above* its grid, which is a separate and much smaller change.
