# Changelog
User-facing changes to the Crit Alarm app. Versions match `version:` in `pubspec.yaml`. Entries are added with cider (`make log`), one line each. Rules: `AGENTS.md`, Changelogs. Changes only developers notice go in `dev-notes/CHANGELOG.md`.

## Unreleased
### Added
- The connect step says what the push relay can see, taken from the server's own answer

### Changed
- The paid plan is called Hosted everywhere in the app, including the paywall, Settings, history, notices and reminders.
- Setup no longer waits on the connection. Continue with Crit Alarm Cloud moves on at once and the connection finishes while you answer the permission steps

### Fixed
- Crit Alarm now connects by itself once the phone is back online, as the offline card on the connect step always said
- The welcome screen is ready to tap the moment it opens, with its words and Get started button in place while the animation plays.

## 1.0.0+12 - 2026-10-03
### Added
- Android onboarding asks for the full-screen alarm permission, so pages can ring over the lock screen from the first run.
- A sheet offers the Topics guide the first time Topics opens after onboarding. "Not now" turns off every Feature Guide and says where to find them again.
- Settings › Feature Guides lists every guide, what it covers and how many steps it has, with a button to play them all.
- The App icon screen is a full-screen showcase. Pro icons show a lock and a Go Pro button for Free users.
- Home shows a one-time notice on Android when battery optimization could delay pages, once you have a critical topic.
- Pro users can manage their subscription from the plan card in Settings.
- 14 new built-in alarm sounds: sirens, a klaxon, SOS in Morse on a beeper and on a ship horn, beepers, a red alert and an alarm bell.
- 5 new built-in alarm sounds: musical loops whose pitch or beat seems to climb, fall or speed up forever.
- Sound packs: download 23 more alarm sounds (clocks, bells, buzzers, klaxons) from the App Store or Google Play when you want them. On iPhone this needs iOS 26 or later.

### Changed
- "Back up your topics" waits until you own a topic and a day has passed since your first one. The backup reminder waits the same day.
- History offers only the windows your plan keeps: Free shows 24 hours and 7 days, Pro goes back 90 days.
- Default sound is a direct row in Settings, and Settings pages no longer show the tab bar.
- The dark theme keeps cards, switches and the tab bar visible against the background.
- The built-in alarm sounds are louder, and none has a quiet stretch you could sleep through.

### Fixed
- Android onboarding no longer says your phone needs iOS 26.
- Create topic: the Next button no longer covers the Critical delivery card while you type.
- Pro no longer shows the Free limit of critical topics after you subscribe.
- Create topic no longer shows the Topics list behind it.
- On iPhones that cannot ring through silent mode, the guides and the test alarm no longer say they can.
- Tapping the test alarm during setup no longer shows a Page Not Found screen.
- Connecting to a server no longer shows a false offline notice when your connection is working.
- On Android the alarm sound loops with no gap between its end and its start.
