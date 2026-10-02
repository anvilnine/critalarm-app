# Changelog
User-facing changes to the Crit Alarm app. Versions match `version:` in `pubspec.yaml`. Entries are added with cider (`make log`), one line each. Rules: `AGENTS.md`, Changelogs. Changes only developers notice go in `dev-notes/CHANGELOG.md`.

## Unreleased
### Added
- Android onboarding asks for the full-screen alarm permission, so pages can ring over the lock screen from the first run.
- A sheet offers the Topics guide the first time Topics opens after onboarding. "Not now" turns off every Feature Guide and says where to find them again.
- Settings › Feature Guides lists every guide, what it covers and how many steps it has, with a button to play them all.
- The App icon screen is a full-screen showcase. Pro icons show a lock and a Go Pro button for Free users.
- Home shows a one-time notice on Android when battery optimization could delay pages, once you have a critical topic.
- Pro users can manage their subscription from the plan card in Settings.

### Changed
- "Back up your topics" waits until you own a topic and a day has passed since your first one. The backup reminder waits the same day.
- History offers only the windows your plan keeps: Free shows 24 hours and 7 days, Pro goes back 90 days.
- Default sound is a direct row in Settings, and Settings pages no longer show the tab bar.
- The dark theme keeps cards, switches and the tab bar visible against the background.

### Fixed
- Android onboarding no longer says your phone needs iOS 26.
- Create topic: the Next button no longer covers the Critical delivery card while you type.
- Pro no longer shows the Free limit of critical topics after you subscribe.
- Create topic no longer shows the Topics list behind it.
- On iPhones that cannot ring through silent mode, the guides and the test alarm no longer say they can.
- Tapping the test alarm during setup no longer shows a Page Not Found screen.
