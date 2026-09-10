# MediaRescue v1.0.7 — Complete Premium UI/UX Redesign

This document outlines the technical plan for a comprehensive, application-wide visual and user-experience transformation of **MediaRescue v1.0.7**. 

The goal is to elevate MediaRescue into a **premium, modern, confident, and commercial-grade Android application** while preserving **100% of all underlying scan, rescue, Shizuku, storage access, state management, and file functionality**.

---

## 🚨 Non-Negotiable Preservation Guarantees
- **Zero Functionality Loss**: Storage scanning, hidden media scanner, large file filtering, Shizuku AIDL user service, file copy/rescue, search indexing, media metadata extraction, and notifications remain strictly intact.
- **Zero Package Breakage**: No SDK, Kotlin, Gradle, or state management rewrites.
- **Lightweight Grid/List Performance**: High-performance scrolling and lazy thumbnail loading preserved with zero per-item backdrop filter overhead.

---

## User Review Required

> [!IMPORTANT]
> - **Icon Library Integration**: Upgraded app icons to `hugeicons` (v1.1.7) for clean, uniform stroke-based iconography across all tabs, actions, file types, and status cards.
> - **Design System Architecture**: Introducing centralized design tokens (`app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_shadows.dart`) used across all light and dark mode surfaces.
> - **Navigation Redesign**: Replacing default Material 3 NavigationBar with a modern floating elevated navigation bar in `ScaffoldWithNavBar`.

---

## Proposed Changes

### 1. Centralized Design System (`lib/app/theme/`)

#### [NEW] [app_colors.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/app/theme/app_colors.dart)
- Define sophisticated dark palette: Deep Slate (`#0B0F17`), Card Surface (`#141C2B`), Elevated (`#1E293B`), Border (`#293548`), Accent (`#38BDF8` Electric Cyan & `#6366F1` Indigo).
- Define refined light palette: Soft Zinc (`#F8FAFC`), White Surface (`#FFFFFF`), Muted Slate (`#F1F5F9`), Border (`#E2E8F0`), Accent (`#0284C7` Ocean & `#4F46E5` Indigo).
- Define category accents: Images (Violet/Purple), Videos (Sky Blue), Audio (Emerald Green), Documents (Amber/Orange), Other (Slate/Zinc).

#### [NEW] [app_typography.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/app/theme/app_typography.dart)
- Text styles: `displayLarge`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `labelSmall`, `codeMono`.

#### [NEW] [app_spacing.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/app/theme/app_spacing.dart) & [app_radius.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/app/theme/app_radius.dart)
- Standardized spacing tokens (`xs: 4`, `sm: 8`, `md: 12`, `lg: 16`, `xl: 24`, `xxl: 32`).
- Standardized radii (`xs: 6`, `sm: 10`, `md: 14`, `lg: 20`, `pill: 999`).

#### [MODIFY] [app_theme.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/app/theme/app_theme.dart)
- Connect light and dark `ThemeData` to use `AppColors`, custom card theme, input decoration theme, dialog theme, bottom sheet theme, and chip themes.

---

### 2. Reusable Visual Components (`lib/widgets/`)

#### [NEW] [app_card.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/app_card.dart)
- Reusable surface container with subtle border, optional gradient highlight, clean elevation, and press state ink response.

#### [NEW] [app_button.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/app_button.dart)
- Primary filled, secondary outline, ghost, and dangerous button components with HugeIcons support.

#### [NEW] [app_badge.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/app_badge.dart)
- Status chips for scan state, Shizuku connection state, file size tags, and count badges.

#### [MODIFY] [selection_bottom_bar.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/selection_bottom_bar.dart)
- Redesign floating selection action bar with selection count, quick select/deselect, rescue button, and delete action.

#### [MODIFY] [file_actions_sheet.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/file_actions_sheet.dart) & [media_info_sheet.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/media_info_sheet.dart) & [smart_filter_sheet.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/widgets/smart_filter_sheet.dart)
- Upgrade bottom sheet dialogs to use smooth top drag indicator, modern rounded corners, HugeIcons, and clear typography.

---

### 3. Application Shell & Global Navigation (`lib/screens/`)

#### [MODIFY] [scaffold_with_nav_bar.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/scaffold_with_nav_bar.dart)
- Redesign bottom navigation with floating pill container, custom active indicators, and HugeIcons (`Home`, `Folder`, `Gallery`, `Search`, `Settings`).

---

### 4. Screen Redesigns (`lib/screens/`)

#### [MODIFY] [home_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/home/home_screen.dart)
- **Header**: Brand title with pulse activity badge & quick storage rescan action button.
- **Scan Card**: Active scan status with file discovery counter & code-styled path preview.
- **Storage Overview**: Visual category bar chart (Images, Videos, Audio, Documents, Other) with exact file size breakdowns.
- **Quick Actions Grid**: 6 prominent tiles using HugeIcons with subtle background tints.
- **Cleanup Suggestions**: Actionable recommendation cards leading directly to target screens.

#### [MODIFY] [gallery_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/gallery/gallery_screen.dart), [folder_picker_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/gallery/folder_picker_screen.dart) & [file_info_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/gallery/file_info_screen.dart)
- Redesign folder picker with suggested media directory tiles.
- Redesign media filter bar with pill choice chips & view switcher (Grid / List).
- Redesign file detail card with visual metadata list and prominent rescue button.

#### [MODIFY] [browse_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/browse/browse_screen.dart)
- Interactive breadcrumb navigation bar with home icon.
- File and directory row tiles with HugeIcons, item counts, size labels, and long-press selection support.

#### [MODIFY] [search_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/search/search_screen.dart)
- Sleek search input bar with instant clear action.
- Search result stats, filter tags, and empty search placeholder state.

#### [MODIFY] [large_files_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/large_files/large_files_screen.dart)
- Redesign threshold selector dropdown (10MB, 50MB, 100MB, 500MB, 1GB).
- File item rows with size highlights & batch deletion confirmation dialog.

#### [MODIFY] [hidden_media_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/hidden_media/hidden_media_screen.dart)
- Feature hero banner explaining hidden media discovery.
- Scan state indicator and grid/list of discovered hidden media.

#### [MODIFY] [advanced_scan_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/advanced_scan/advanced_scan_screen.dart) & [shizuku_guide_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/advanced_scan/shizuku_guide_screen.dart)
- Status card showing Shizuku connection state (Running / Not running / Permission denied).
- Step-by-step Shizuku setup guide with structured instruction cards and HugeIcons.

#### [MODIFY] [settings_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/settings/settings_screen.dart), [about_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/settings/about_screen.dart), [contact_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/settings/contact_screen.dart) & [privacy_policy_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/settings/privacy_policy_screen.dart)
- Settings grouped into visual cards: Appearance, Storage, Rescue Destination, Notifications, Navigation, Advanced Scanning, About.
- Redesign theme selection tiles (System, Light, Dark) with active radio checks.
- Redesign rescue destination single vs multi-folder configuration.
- About page with app icon, version chip, developer link cards, and license info.

#### [MODIFY] [permission_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/onboarding/permission_screen.dart)
- Modern onboarding layout with illustrations, security note, and high-contrast "Grant Storage Permission" primary button.

---

### 5. Media Preview System Redesign (`lib/screens/preview/`)

#### [MODIFY] [immersive_media_viewer_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/preview/immersive_media_viewer_screen.dart)
- Overlay toolbar with glass surface background, back button, file details toggle, rescue button, and media index text (`3 of 42`).
- Smooth full-screen gesture zoom for images and video player integration.

#### [MODIFY] [audio_player_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/preview/audio_player_screen.dart)
- Redesign audio player with large stylized music artwork/icon, animated pulse, waveform visualizer placeholder, seek bar, time display, play/pause controls, and rescue FAB.

#### [MODIFY] [pdf_viewer_screen.dart](file:///Users/macbookpro/Desktop/Flutter_Projects/mediarescue/lib/screens/preview/pdf_viewer_screen.dart)
- Redesign top bar with page count (`Page X of Y`), jump-to-page button, and rescue action.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure zero compilation or lint errors.
- Run existing Flutter unit/widget tests (`flutter test`) to verify logic stability.

### Manual Verification
- Launch application build and test all navigation branches (Home, Browse, Gallery, Search, Settings).
- Test scan initiation, progress display, completion, and rescan.
- Test theme toggling between Light, Dark, and System modes.
- Verify previews for Images, Videos, Audio, and PDFs.
- Verify selection mode, rescue copying, and large file deletion dialog.
- Verify Shizuku guide screen and status indicators.
