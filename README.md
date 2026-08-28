# MediaRescue

MediaRescue — Android file & media manager built with Flutter

MediaRescue helps you find, preview, and manage large and duplicate media and files on Android devices. It provides an offline-first, privacy-friendly experience for scanning storage, previewing images, videos, PDF and audio, and performing batch operations like copy, move, delete and rename.

Why this project matters: it's lightweight, open-source (MIT), and designed to run without network access — ideal for privacy-conscious users and app stores like F-Droid and Google Play.

---

## Table of Contents

- [Badges](#badges)
- [Features](#features)
- [Screenshots / Demo](#screenshots--demo)
- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
  - [From Release (APK)](#from-release-apk)
  - [From F-Droid](#from-f-droid)
  - [From Google Play Store](#from-google-play-store)
- [Build from Source](#build-from-source)
  - [Prerequisites](#prerequisites)
  - [Clone & Install](#clone--install)
  - [Run (Debug)](#run-debug)
  - [Build Release APK](#build-release-apk)
  - [Build Release AAB (Play Store)](#build-release-aab-play-store)
- [App Features & Usage Guide](#app-features--usage-guide)
- [Permissions](#permissions)
- [Architecture & Developer Notes](#architecture--developer-notes)
  - [Project Structure](#project-structure)
  - [Key Files](#key-files)
  - [Tech Stack](#tech-stack)
- [Testing](#testing)
- [Contributing](#contributing)
- [Releases & Distribution](#releases--distribution)
- [Changelog](#changelog)
- [Roadmap](#roadmap)
- [FAQ](#faq)
- [License](#license)

---

## Badges

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/github/license/everythingfreee/MediaRescue?color=green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/everythingfreee/MediaRescue?color=blue)](https://github.com/everythingfreee/MediaRescue/releases)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen)](https://github.com/everythingfreee/MediaRescue/pulls)
[![F-Droid](https://img.shields.io/badge/F--Droid-Planned-1976D2?logo=fdroid&logoColor=white)]()
[![Google Play](https://img.shields.io/badge/Google%20Play-Planned-414141?logo=googleplay&logoColor=white)]()

---

## Features

### Full Storage Scanning

- Recursively scans shared storage (`/storage/emulated/0`) and removable roots (SD cards).
- Fast background scanning with real-time progress events and incremental results.
- Scans can be saved and loaded locally to avoid re-scanning the same storage repeatedly.

### Intelligent Gallery View

- Files are automatically grouped by folder, image, video, audio, PDF and other file types.
- Thumbnail generation for smoother, faster browsing of media-heavy directories.

### Built-in Media Previews

- **Images** — pinch-to-zoom and pan with a polished viewer (`photo_view`).
- **Videos** — smooth in-app playback (`video_player`).
- **PDFs** — native-style PDF rendering (`flutter_pdfview`).
- **Audio** — in-app audio playback.

### Batch Operations

- Multi-select files with a dedicated selection UI.
- Perform **copy**, **move**, **delete**, and **rename** operations on multiple files at once.
- Bottom action bar makes bulk actions quick and intuitive.

### Large Files Finder

- Dedicated Large Files view to identify files that consume the most space.
- Filter by file size and reclaim storage quickly.

### Search

- Fast search across scanned file names and paths.
- Locate files instantly without browsing through folders manually.

### Smart Filters

> **New in v1.0.2**

- **Combinable filters** — narrow thousands of discovered files by narrowing multiple criteria at once (e.g. `videos` **+** `> 500 MB` **+** `modified within 1 year` **+** `hidden`).
- Filter by **file type** (images, videos, audio, documents, PDFs, archives), **file size** (> 10 MB / > 100 MB / > 500 MB / > 1 GB), **modified date** (today / 7 days / 30 days / 1 year) and **storage location** (internal storage / SD card).
- Compatible with search — filters and the text query compose together over the scanned index.
- **Zero re-scanning** — filters operate purely on the already-indexed `FileItem` metadata (path, name, size, mimeType, modifiedDate), so changing a filter is instant.
- Live feedback: filter button badge shows how many filter groups are active, and active filters appear as removable chips above the results.

### Folder Picker & Browser

- Browse directories manually with a folder picker.
- Directory listing and file info screens with detailed metadata (size, type, modified date, path).

### Modern UI / UX

- Light & Dark themes with Material 3 design.
- Fast, declarative navigation powered by GoRouter.
- Clean onboarding flow with permission guidance.

### Privacy First

- 100% offline — all scanning and processing happens locally on your device.
- No network calls, no analytics, no cloud uploads, no tracking.

---

## Screenshots / Demo

> Screenshots: See a preview of the app before installing...

| Onboarding | Home / Library | Gallery | Preview |
|---|---|---|---|
| <img src="fastlane/metadata/android/en-US/images/1.png"> | <img src="fastlane/metadata/android/en-US/images/2.png"> | <img src="fastlane/metadata/android/en-US/images/3.png"> | <img src="fastlane/metadata/android/en-US/images/4.png"> |

| Large Files | Search | Browse | Settings |
|---|---|---|---|
| <img src="fastlane/metadata/android/en-US/images/5.png"> |<img src="fastlane/metadata/android/en-US/images/6.png"> | <img src="fastlane/metadata/android/en-US/images/7.png"> | <img src="fastlane/metadata/android/en-US/images/8.png"> |

**Demo video:** coming soon

> Contributors welcome: If you'd like to help capture screenshots or record a demo, please see [Contributing](#contributing). Recommended screenshot size: 1080 × 1920 px (PNG). Demo format: optimized GIF or MP4.

---

## Supported Platforms

| Platform | Status |
|---|---|
| **Android** | Primary target (API 21+) |
| iOS | Not supported in this release |
| Desktop / Web | Not supported (uses Android-native storage APIs) |

> Note: MediaRescue relies on Android-native APIs for storage access and thumbnails. It is designed for Android phones and tablets.

---

## Installation

MediaRescue is distributed through multiple channels — pick whichever works best for you.

### From Release (APK)

1. Go to the [GitHub Releases](https://github.com/everythingfreee/MediaRescue/releases) page.
2. Download the latest `.apk` file.
3. On your Android device, allow installation from unknown sources if prompted.
4. Open the downloaded APK to install MediaRescue.

> Tip: Always verify the APK checksum listed in the release notes to ensure authenticity.

### From F-Droid

> Status: Planned

Once published, MediaRescue will be available directly from the [F-Droid](https://f-droid.org) store. F-Droid users can install it like any other app:

1. Install the [F-Droid client](https://f-droid.org/) (if not already installed).
2. Search for **"MediaRescue"**.
3. Tap **Install**.

### From Google Play Store

> Status: Planned

MediaRescue will be published on the Google Play Store as a free, open-source app. Search for **"MediaRescue"** once it's live.

---

## Build from Source

Want to build the app yourself? Great — it's fully open source. Follow the steps below.

### Prerequisites

| Tool | Version | Link |
|---|---|---|
| **Flutter SDK** | 3.x (with Dart 3.x) | [flutter.dev](https://flutter.dev) |
| **Android SDK** | API 21+ (compile SDK 35) | [developer.android.com](https://developer.android.com/studio) |
| **Android Studio** | Latest (recommended) | [Android Studio](https://developer.android.com/studio) |
| **Java** | 17+ (bundled with Android Studio) | — |

### Clone & Install

```bash
git clone https://github.com/everythingfreee/MediaRescue.git
cd MediaRescue
flutter pub get
```

### Run (Debug)

```bash
# List connected devices/emulators
flutter devices

# Run in debug mode on a specific device
flutter run -d <device-id>
```

### Build Release APK

```bash
flutter build apk --release
```

The APK will be generated at:

```
build/app/outputs/flutter-apk/app-release.apk
```

### Build Release AAB (Play Store)

```bash
flutter build appbundle --release
```

The AAB will be generated at:

```
build/app/outputs/bundle/release/app-release.aab
```

> Note for F-Droid: To publish to F-Droid, you'll need to provide reproducible build metadata and follow the [F-Droid packaging guidelines](https://f-droid.org/en/docs/Packaging_Applications/). This includes metadata files, build scripts, and compatible licenses.

---

## App Features & Usage Guide

### 1. Grant Storage Permission

On first launch, MediaRescue will guide you through granting storage access:

- On **Android 11+**, you'll be prompted to enable **"All files access"** (Settings → Special app access → All files access → MediaRescue).
- On **Android 10 and below**, MediaRescue uses legacy external storage permissions (`READ`/`WRITE_EXTERNAL_STORAGE`).

### 2. Scan Storage

- From the **Home** screen, tap **Start Scan** to scan the entire shared storage.
- Progress is shown live with the current directory, files discovered, and directories scanned.
- Scanning runs in the background — you can keep using the app.

### 3. Browse & Filter

- Switch between views: **Gallery** (media grouped by type), **Folders** (directory browser), and **Large Files**.
- Filter files by type: images, video, audio, PDF, and other formats.

### 4. Preview Files

Tap any file to open a built-in preview:

- **Images** → zoom & pan viewer.
- **Videos** → in-app video player.
- **PDFs** → PDF viewer.
- **Audio** → audio player.

### 5. Select & Manage Files

- **Long-press** any file to enter selection mode.
- Select multiple files, then use the **bottom action bar** to:
  - **Copy**
  - **Move**
  - **Delete**
  - **Rename**

### 6. Save & Load Scans

- **Save** a scan result to quickly re-open it later without rescanning.
- **Load** previously saved scans from the browse screen.
- **Clear** scan data when you no longer need it.

### 7. Find Large Files

- Navigate to the **Large Files** tab.
- Sort by file size to quickly find storage hogs.
- Delete or move large files in bulk to free up space.

### 8. Search

- Use the **Search** screen to find files by name anywhere in the scanned storage.

### 9. Smart Filters (v1.0.2)

- On the **Search** screen, tap the **filter** icon in the top-right corner to open **Smart Filters**.
- Combine multiple criteria — file type, size, modified date, and storage location.
- Results update instantly as you change filters; a badge on the filter button shows how many filter groups are active.
- Tap the **×** on any active filter chip above the results to remove it, or **Clear all** inside the sheet to reset everything.
- Filters work together with the search box — no re-scan is triggered.

---

## Permissions

MediaRescue requires storage access to scan and manage files. Here's exactly what's used and why:

| Permission | Android Version | Purpose |
|---|---|---|
| `MANAGE_EXTERNAL_STORAGE` | Android 11+ | **"All files access"** — required for full storage scanning & management |
| `READ_EXTERNAL_STORAGE` | Android 5–10 (maxSdk 32) | Read public media and files |
| `WRITE_EXTERNAL_STORAGE` | Android ≤ 9 (maxSdk 29) | Copy / move / delete files |

### Privacy Guarantee

> **MediaRescue performs all scanning and processing locally on your device.**
>
> - No network requests
> - No analytics or telemetry
> - No cloud uploads
> - 100% offline-first

Your files never leave your device.

---

## Architecture & Developer Notes

### Project Structure

```
mediarescue/
├── android/                          # Android platform wrapper
│   ├── app/
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   # Permissions & app config
│   │       └── kotlin/               # Native Kotlin code (MethodChannel)
│   └── build.gradle.kts
├── lib/
│   ├── main.dart                     # App entrypoint
│   ├── app/
│   │   ├── app.dart                  # Root MaterialApp.router + theme
│   │   ├── routes.dart               # go_router route definitions
│   │   └── theme/
│   │       └── app_theme.dart        # Light/dark theme definitions
│   ├── models/
│   │   ├── file_item.dart            # File & folder data model
│   │   └── smart_filter.dart         # Smart Filters state & filter enums
│   ├── providers/                    # Riverpod state management
│   │   ├── browser_provider.dart     # Directory browsing state
│   │   ├── filter_provider.dart      # Smart Filters state & filter engine
│   │   ├── gallery_provider.dart     # Gallery grouping & filtering state
│   │   ├── scanner_provider.dart     # Scan progress & results state
│   │   ├── selection_provider.dart   # Multi-select state
│   │   └── storage_provider.dart     # Storage roots state
│   ├── screens/
│   │   ├── scaffold_with_nav_bar.dart# Root scaffold with bottom navigation
│   │   ├── home/                     # Home screen
│   │   ├── browse/                   # Folder browser screen
│   │   ├── gallery/                  # Gallery, file info, folder picker
│   │   ├── large_files/              # Large files screen
│   │   ├── search/                   # File search screen
│   │   ├── preview/                  # Image, video, PDF, audio viewers
│   │   ├── settings/                 # Settings screen
│   │   └── onboarding/               # Permission onboarding screen
│   ├── services/
│   │   └── storage_service.dart      # MethodChannel bridge to native APIs
│   └── widgets/
│       ├── selection_bottom_bar.dart # Bottom action bar for bulk operations
│       ├── smart_filter_sheet.dart   # Smart Filters bottom-sheet UI
│       └── thumbnail_image.dart      # Cached thumbnail widget
├── test/
│   └── widget_test.dart              # Widget tests
├── pubspec.yaml                      # Dependencies & app metadata
├── README.md                         # You are here
├── LICENSE                           # MIT license
└── CHANGELOG.md                      # Version history
```

### Key Files

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry point; boots Riverpod `ProviderScope` + `MediaRescueApp` |
| `lib/app/app.dart` | Root widget; theme, router, and global configuration |
| `lib/app/routes.dart` | Centralized `go_router` route table |
| `lib/services/storage_service.dart` | Storage abstraction + MethodChannel implementation (`MethodChannelStorageService`) |
| `lib/providers/` | Riverpod providers for scanning, gallery, selection, and browser state |
| `lib/screens/` | All UI screens (gallery, browse, preview, settings, etc.) |
| `lib/models/file_item.dart` | `FileItem` model (path, name, size, type, MIME, modified date) |
| `lib/models/smart_filter.dart` | `SmartFilterState` + filter enums (type, size, date) |
| `lib/providers/filter_provider.dart` | `smartFilterProvider` + `applySmartFilters()` filter engine (in-memory, no re-scan) |
| `lib/widgets/smart_filter_sheet.dart` | Smart Filters bottom-sheet UI (chips, radios, storage checkboxes) |

### Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) 3.x |
| **Language** | [Dart](https://dart.dev) 3.x |
| **State Management** | [Riverpod (flutter_riverpod ^3.x)](https://riverpod.dev) |
| **Navigation** | [go_router ^17.x](https://pub.dev/packages/go_router) |
| **Image Viewer** | [photo_view ^0.15.x](https://pub.dev/packages/photo_view) |
| **Video Player** | [video_player ^2.x](https://pub.dev/packages/video_player) |
| **PDF Viewer** | [flutter_pdfview ^1.4.x](https://pub.dev/packages/flutter_pdfview) |
| **Native Bridge** | Android MethodChannel (Kotlin) |
| **UI** | Material 3 (light/dark themes) |

---

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

---

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are greatly appreciated.

### Ways to Contribute

- **Report bugs** — open a [GitHub Issue](https://github.com/everythingfreee/MediaRescue/issues) with steps to reproduce and device details.
- **Suggest features** — open a feature request issue.
- **Submit PRs** — bug fixes, performance improvements, UI enhancements.
- **Translate** — add new languages / improve existing translations.
- **Accessibility** — help improve a11y support.
- **Screenshots & demos** — help us build the screenshot gallery.

### Getting Started

```bash
# 1. Fork the repository
#    Click "Fork" at https://github.com/everythingfreee/MediaRescue

# 2. Clone your fork
git clone git@github.com:<your-username>/MediaRescue.git
cd MediaRescue

# 3. Create a feature branch
git checkout -b feat/your-feature

# 4. Install dependencies
flutter pub get

# 5. Make your changes & run the app
flutter run

# 6. Run tests
flutter test

# 7. Commit & push
git add .
git commit -m "feat: add your awesome feature"
git push --set-upstream origin feat/your-feature

# 8. Open a Pull Request against the upstream repository
```

### Guidelines

- Keep PRs small and focused — one feature/fix per PR.
- Follow the existing code style (`dart format`, effective Dart).
- Add/update tests for new functionality.
- Include screenshots or recordings for UI changes.
- Keep everything offline-first and privacy-friendly.
- Be kind and respectful.

---

## Changelog

### v1.0.2 — Smart Filters

**Added: Smart Filters for Search**

- New combinable, in-memory **Smart Filters** layer on the Search screen, letting users quickly narrow thousands of discovered files without browsing manually.
- Filter by **file type**: Images, Videos, Audio, Documents, PDFs, Archives, and Hidden files.
- Filter by **file size**: any / > 10 MB / > 100 MB / > 500 MB / > 1 GB.
- Filter by **modified date**: any / today / 7 days / 30 days / 1 year.
- Filter by **storage location**: internal storage (`/storage/emulated/0`) and/or SD card.
- All filters are **combinable (ANDed)** — e.g. `type = video` + `size > 500 MB` + `modified within 1 year` + `hidden` — fully compatible with the existing text search.
- Filters operate on the **already-indexed `FileItem` metadata** (path, name, size, mimeType, modifiedDate). **No filesystem re-scan** happens when a filter changes.
- UI improvements:
  - Filter button in the Search app bar with an **active-filter badge**.
  - **Active filter chips** above the results with one-tap removal and a "Clear all" action in the sheet.

**New files**

- `lib/models/smart_filter.dart` — `SmartFilterState`, `SmartTypeFilter`, `FileSizeFilter`, `ModifiedDateFilter`.
- `lib/providers/filter_provider.dart` — `smartFilterProvider` + `applySmartFilters()` filter engine.
- `lib/widgets/smart_filter_sheet.dart` — Smart Filters UI (bottom sheet + radio/chip controls).

**Modified**

- `lib/providers/scanner_provider.dart` — `searchResultsProvider` now composes the text query with the Smart Filters.
- `lib/screens/search/search_screen.dart` — filter button, active-filter chip bar, and filter-aware results/empty states.

---

## Releases & Distribution

MediaRescue distributes via three channels:

| Channel | Status | Artifact |
|---|---|---|
| **GitHub Releases** | Active | `.apk` + `.aab` + changelog |
| **F-Droid** | Planned | F-Droid metadata & reproducible build |
| **Google Play Store** | Planned | Signed `.aab` |

### Release Checklist

When publishing a new release:

1. Bump `version` in `pubspec.yaml`.
2. Update `CHANGELOG.md` with notable changes.
3. Build signed artifacts:
   ```bash
   flutter build appbundle --release   # for Play Store
   flutter build apk --release         # for GitHub Releases / F-Droid
   ```
4. Create a [GitHub Release](https://github.com/everythingfreee/MediaRescue/releases/new) with:
   - Version tag (e.g., `v1.0.0`)
   - Release title
   - Changelog notes
   - Attached APK/AAB files
5. Upload the AAB to Google Play Console.
6. Update F-Droid metadata (if applicable).

> Security: Never commit `key.properties` or keystore files. See `android/.gitignore`.

---

## Roadmap

### v1.0 (Current)

- Full storage scanning
- Gallery, folder browsing, large files view, search
- Image/video/PDF/audio previews
- Batch copy / move / delete / rename
- Save/load scans
- Light/dark themes
- Permission onboarding

### v1.x (Upcoming)

- Improved duplicate detection (content hashing, grouping)
- Better heuristics for media grouping
- Storage analytics & charts (usage visualization)
- Export scan reports (CSV)

### v2.0 (Future)

- Optional cloud-optimized features (opt-in backups)
- Enhanced tagging & search
- Disk usage heatmap
- Translations (i18n)

---

## FAQ

### Q: Is my data uploaded anywhere?

**A:** No. MediaRescue performs all scanning and processing locally on your device. There are zero network calls made by the app. Your files never leave your device.

### Q: Will this run on my device?

**A:** MediaRescue targets Android devices (API 21+). Some features rely on Android-native APIs and may behave differently on heavily modified OEM skins (Xiaomi, Samsung, etc.).

### Q: Why does the app need "All files access" on Android 11+?

**A:** Because Android 11+ restricts broad external-storage access, a file manager app needs the `MANAGE_EXTERNAL_STORAGE` permission ("All files access") to scan the entire shared storage and perform file operations on any file.

### Q: Is the app really free?

**A:** Yes! MediaRescue is 100% free and open source under the MIT License. No ads, no IAPs, no data collection.

### Q: How can I help test on different devices?

**A:** Open a GitHub issue mentioning your device model, Android version, and a short description of the test case. Any feedback is appreciated!

### Q: Can I contribute even if I'm not a developer?

**A:** Absolutely! You can help with translations, screenshots, documentation, testing, and spreading the word. See [Contributing](#contributing).

### Q: Where can I report bugs or request features?

**A:** Please open an issue on the [GitHub Issues page](https://github.com/everythingfreee/MediaRescue/issues).

---

## License

**MediaRescue** is released under the **MIT License** — a permissive open-source license that allows commercial use, modification, distribution, and private use, with attribution.

You are free to:

- Use the app commercially
- Modify the source code
- Distribute it
- Use it privately

The only requirement is that you include the original copyright notice and license text in your copies or substantial portions of the software.

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

The full license text is available in the [LICENSE](LICENSE) file at the root of this repository.

---

## Support MediaRescue

If you find MediaRescue useful, please consider:

- **Star** this repository on GitHub
- **Fork** it and contribute
- **Share** it with friends who might benefit
- **Report** bugs or suggest features

Your support helps keep this project alive and improving!

---

**Made with Flutter**

[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)