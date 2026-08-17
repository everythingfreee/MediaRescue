# MediaRescue

MediaRescue — Android file & media manager built with Flutter

MediaRescue helps you find, preview, and manage large and duplicate media and files on Android devices. It provides an offline-first, privacy-friendly experience for scanning storage, previewing images, videos, PDF and audio, and performing batch operations like copy, move, delete and rename.

Why this project matters: it's lightweight, open-source (MIT), and designed to run without network access — ideal for privacy-conscious users and app stores like F‑Droid and Google Play.

Table of Contents
- Features
- Quick demo (screenshots)
- Supported platforms
- Install & Try
- Build from source
- App features & usage
- Permissions
- Developer notes (architecture)
- Contributing
- Releases & distribution (Play Store, F‑Droid, GitHub)
- License (MIT)

## Features

- Full storage scanning: recursively scan shared storage (/storage/emulated/0) and removable roots.
- Fast background scanning with progress events and incremental results.
- Intelligent gallery view: grouped by folder, image, video, audio, PDF and other file types.
- Preview viewers: images (zoom & pan), videos (playback), PDFs and audio playback.
- Thumbnails: generates fast thumbnails for smoother browsing.
- Batch operations: select multiple files and copy, move, delete, or rename them.
- Save/load scans: persist scan results locally to speed up repeated inspections.
- Large-files view: find and filter by file size to reclaim space quickly.
- Folder picker & directory listing for manual file management.
- Permission helpers: request 'All files access' and guide the user to settings when needed.
- Modern Flutter UI with light/dark themes and fast navigation using `go_router`.

## Quick demo

Add screenshots and short GIFs to this section to improve discoverability. Recommended sizes: 1080×1920 PNG for screenshots and optimized GIF/MP4 for demos.

## Supported platforms

- Android (primary)
- Desktop/web support is not included in this release — Android-focused native APIs are used for storage access and thumbnails.

## Install & Try

The app will be distributed via Google Play Store, F‑Droid, and GitHub Releases. Until binaries are published, build from source:

Prerequisites
- Flutter SDK (see https://flutter.dev)
- Android SDK & platform tools
- A connected Android device or emulator

Build and run (debug):

```bash
flutter pub get
flutter run -d <device-id>
```

Build a release AAB (recommended for Play Store):

```bash
flutter build appbundle --release
```

Build an APK (for testing / GitHub Releases):

```bash
flutter build apk --release
```

Note: To publish to F‑Droid you'll need to provide reproducible build metadata and follow F‑Droid packaging guidelines (metadata, build scripts, and compatible licenses). See the official F‑Droid docs: https://f-droid.org/en/docs/Packaging_Applications/

## App features & usage

1. Scan storage
	- From the home screen, start a full scan. Progress updates appear in the UI.
2. Browse & filter
	- Switch between folders, large files, or media-specific views (images, video, audio, PDF).
3. Preview files
	- Tap an item to view images (zoom/pan), play videos, open PDFs, or listen to audio.
4. Select & act
	- Long-press or use the selection UI to pick multiple files. Use the bottom action bar to copy, move, delete, or rename.
5. Save & load scans
	- Save scan results to quickly re-open previous results without re-scanning.

## Permissions

MediaRescue requires access to device storage to scan and manage files. On Android:
- Uses the `MANAGE_EXTERNAL_STORAGE` (All files access) flow for broad access on Android 11+ when needed. The app gracefully falls back to scoped access where available.
- The app will guide users to system settings to grant All files access when required.

Privacy note: MediaRescue performs all scanning and processing locally on-device; no network or cloud uploads are performed by default.

## Developer notes (architecture)

- Flutter + Riverpod: UI state is managed with `flutter_riverpod`.
- Platform integration: `MethodChannelStorageService` bridges native Android storage APIs (see `lib/services/storage_service.dart`).
- Routing: `go_router` is used for navigation.
- Key files to explore:
  - `lib/main.dart` — app entrypoint
  - `lib/app/app.dart` — theme & router provider
  - `lib/services/storage_service.dart` — storage abstraction and method channel
  - `lib/providers/` — Riverpod providers for scanning, selection and gallery state
  - `lib/screens/` — UI screens (gallery, browse, preview, settings)

## Contributing

Contributions are welcome! Good ways to help:
- Report issues in GitHub Issues with steps to reproduce and device details.
- Open pull requests for bug fixes, performance improvements, or UI enhancements.
- Add translations or accessibility improvements.

Suggested workflow

```bash
git fork https://github.com/<yourname>/mediarescue
git clone git@github.com:<yourname>/mediarescue.git
git checkout -b feat/your-feature
flutter pub get
# make changes, run the app and tests
git commit -am "Add feature X"
git push --set-upstream origin feat/your-feature
# open PR against upstream repository
```

Please follow the repository's code style and create small, focused PRs. Include screenshots or recordings for UI changes.

## Releases & distribution

- GitHub Releases: binary APKs/AABs and changelogs will be attached to release entries.
- Google Play Store: planned public release. Use an `appbundle` (`.aab`) for Play publishing.
- F‑Droid: planned inclusion — ensure F‑Droid metadata is added and build reproducibility is addressed.

When publishing, attach both the signed AAB/APK and a short release note describing notable changes.

## Roadmap

- v1.0: Stable scanning, previews, and batch operations (current)
- v1.x: Improved duplicate detection, better heuristics for media grouping
- v2.0: Cloud-optional features (opt-in backups), enhanced tagging & search

## FAQ

Q: Is my data uploaded anywhere?
A: No — MediaRescue performs all scanning and processing locally.

Q: Will this run on my device?
A: MediaRescue targets Android devices. Some features rely on Android native APIs and may not work on all OEM-modified platforms.

Q: How can I help test on different devices?
A: Open an issue and mention device model, Android version, and a short description of the test case.

## License

MediaRescue is released under the MIT License.

```
MIT License

Copyright (c) 2026 MediaRescue contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Add a top-level `LICENSE` file with the full MIT text when ready.

---

If you want, I can now:
- Add `LICENSE` file containing the MIT text
- Insert screenshot placeholders and badges (Play Store / F‑Droid / GitHub Releases)
- Create a sample GitHub Release draft with suggested changelog notes

Tell me which you'd like next and I will proceed.
