# Changelog
User-facing changes to the Crit Alarm app. Versions match `version:` in `pubspec.yaml`. Entries are added with cider (`make log`), one line each. Rules: `AGENTS.md`, Changelogs. Changes only developers notice go in `dev-notes/CHANGELOG.md`.

## Unreleased
### Added
- On Android phones that put background apps to sleep, setup offers to let Crit Alarm run in the background so pages are not late. You can skip it, and it stays in Settings under Health.
- The first topic you create shows what Critical delivery does before you choose, and offers a chip for the tool that will send to it.
- The connect step says what the push relay can see, taken from the server's own answer
- Setup ends with a ready curl line for your new topic and waits for your first message.
- Home shows a short setup checklist until your first message arrives.
- The Finish setting up list can be closed for good.
- With VoiceOver or TalkBack on, the ringing alarm starts on I'm up, says which topic is ringing and for how long, and on iPhone a two-finger double tap acknowledges
- The welcome screen has a Stop animation button, and it holds still when your phone asks for reduced motion.

### Changed
- The paid plan is called Hosted everywhere in the app, including the paywall, Settings, history, notices and reminders.
- Setup no longer waits on the connection. Continue with Crit Alarm Cloud moves on at once and the connection finishes while you answer the permission steps
- The setup test alarm now comes from your server, so it tests the whole path.
- Setup says less on every screen and shows a different Crit face for each moment.
- Your first topic in setup is one screen: pick a tool, name it, decide on ringing through silent mode, create. The address and token show on the next steps, where you use them.
- Setup problems are a short title and one line, and the test of this phone only is a plain button.
- Hook up your tool shows your tool's own fields first when it has a form, in one tidy list.
- The Finish setting up list on Home is lighter and shorter, and the widgets card leads with Hosted when widgets need it.
- Ring me for real counts down 5 seconds before it sends, so there is time to lock the phone. Cancel stops it.
- The face on the acknowledged screen has its dark outline and features back.
- The Hosted offer sheet now lists what Hosted adds, says alarms keep ringing on Free with no limit, and that running your own server costs nothing.

### Fixed
- Crit Alarm now connects by itself once the phone is back online, as the offline card on the connect step always said
- The welcome screen is ready to tap the moment it opens, with its words and Get started button in place while the animation plays.
- The reminders sheet no longer opens right after setup, and the walkthrough offer comes first.
- The Connected note in setup no longer sits on top of the permission step dots.
- Hook up your tool no longer says it is waiting for a message when no token could be made.
- The Finish setting up list no longer finishes behind an alarm screen: its last tick and the celebration wait until you are looking at Home.
- A first message sent from a topic page before going back to Home now ticks the list, and so does one on a fourth or later topic.
- The acknowledged screen no longer breaks its title in the middle of a word, draws its hint over the details, or turns dark and muddy after At my desk.
- The Android app no longer closes the moment you open it.
- Setup steps fit at the largest text size: the face shrinks first, titles keep whole words, and a page that still does not fit scrolls, including the server choice.
- The critical topics count card on the new topic screen wraps cleanly at large text sizes, and no longer shows before you own a critical topic.

### Removed
- The QR button on the own-server form, until QR connect exists. Paste stays.

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
