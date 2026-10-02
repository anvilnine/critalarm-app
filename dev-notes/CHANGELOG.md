# Dev notes
Changes developers need to know about: new tokens and components, prefs keys, build flags, tooling, tests, refactors and small UI polish too minor for the user changelog. Added with cider (`make devlog`), one line each. Versions match the app's `pubspec.yaml`. This repo is public: no prices, keys, task numbers or planning links.

## Unreleased
### Added
- Prefs keys `home_prompt_first_topic_at` (first time the user owned a topic, set once) and `home_prompt_battery_dismissed_at` (battery notice dismissed for good).
- `InAppNoticeType.batteryOptimization`, priority 3, between critical health and Pro ending.
- Colour tokens `segmentSelected`, `switchOff`, `switchThumbOff`, `tabBar` and `tabBarLine`; dark `cream` is now `#312823`.
- `AppButtonVariant.cream` for primary actions on the acknowledged canvas, and `AppStepBullet` numbered discs in `sheets.dart`.
- `yearlySavingPercent` in `lib/features/paywall/domain/entities/plan_saving.dart`, with tests.
- `HistoryWindow.shownDays` and `HistoryWindows.isLocked`; the history filter default window is 90 days, shown as the widest window the plan allows.
- `make log`, `make devlog` and `make changelog-release` wrap cider for both changelogs.

### Changed
- Onboarding step 1 on Android asks for notifications only; the full-screen intent is its own step 2 through `DevicePermissionsRepository`.
- Settings sub-page routes sit on the root navigator and are opaque, like `/app-icon`, so the tab bar is hidden there. `/settings/alarms` now holds Storage.
- `AppKeyValueRow` keeps labels at full width, ellipsizes values, and stacks the two when they do not fit.
- `AppListRow` subtitles wrap to two lines; About shows URLs without the scheme.
- Search results list with the best match next to the search bar; no-results shows a face card with example searches.
- List section headers go through `AppSectionHeader`.
- `AppTextField` hints use `ink3` at 60% in every field.
- `AppButtonVariant.destructive` uses `inkFixed` text, so every destructive dialog changes.
- Calm ambient profiles use only `#FFB21F` and `#FFE08A`, at half opacity on dark canvases.
- The Feature Guide card has no close X and no large shadow; "Skip guide" is the one exit.
- The in-app paywall has one heading, Yearly and Monthly plan titles, and no cobalt ring on the face.
- The onboarding screens before Permissions slide in with their text and buttons.

### Fixed
- The PRO badge uses `inkFixed`, so it stays ink on yellow in dark.
- Unselected radios use the card surface and a theme ink ring instead of a canvas-filled dot.
