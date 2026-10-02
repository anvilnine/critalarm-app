# Changelog

User-facing changes to the Crit Alarm app. Versions match `version:` in
`pubspec.yaml`.

## Unreleased

### Added

- A sheet offers the Topics guide the first time Topics opens after
  onboarding, instead of starting it straight away. "Not now" turns off every
  Feature Guide, and the sheet says where to find them again.
- Settings › Feature Guides opens a list of every guide, with what each one
  covers and how many steps it has, plus a button to play them all.
- The App icon screen is now a full-screen showcase. The icons tilt on their
  own, and switching to a new icon plays a short celebration. Pro icons show
  a lock and a Go Pro button for free users.

### Changed

- Create topic: the Next and Create buttons now sit under the form and scroll
  with it, so they no longer cover the Critical delivery card while you type.
  Terms and Privacy sit under the button on step 2. The name placeholders
  start with "e.g." and are lighter.
- "Back up your topics" waits until you own a topic and a day has passed since
  your first one. The backup reminder waits the same day.
- Home shows a one-time battery optimization notice on Android, once you have
  a critical topic. Dismiss it and the setting stays on the Health page.
- Each Feature Guide reads correctly when played on its own. On iPhones that
  cannot ring through silent mode, the critical delivery step no longer says
  they can.
- The onboarding screens before Permissions slide in with their text and
  buttons, the way the later onboarding screens do.

### Fixed

- Create topic no longer shows the Topics list behind it.
