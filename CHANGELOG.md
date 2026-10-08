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
- VoiceOver and TalkBack start on I'm up and read the topic and ring time. On iPhone, a two-finger double tap acknowledges the alarm.
- You can stop the welcome animation. It also holds still when reduced motion is on.
- Setup works at the largest text sizes. The face shrinks first, and a step scrolls when it has to.
- After your first real alarm, Home shows what Free keeps and what Hosted adds. Close the card and it stays closed.
- On your own server, Settings says so: no limits, no charge.
- Settings opens with a Will it wake me? screen that lists what could stop an alarm, with a fix beside each. After your phone updates, Home offers a test alarm once.
- Settings has a Priorities page that says what priorities 1 to 5 do on this phone, with a button to hear the alarm sound in the app.
- Opening a connect link shows the server and asks before it connects.
- On Samsung, Xiaomi, Redmi, Poco, Oppo, Realme, OnePlus, Huawei and Honor phones, Will it wake me? has a Sleep settings row with short steps that stop the phone putting Crit Alarm to sleep.
- Home tells you when this phone missed an alarm, with what the phone recorded about it, and Will it wake me? lists it.
- Pro, a paid pack separate from Hosted: a weekly delivery check. Switch it on in Will it wake me? and the relay checks once a week that a push still reaches this phone. Home says so if two checks in a row are missed.
- Will it wake me? has a sheet where Pro can be bought once it is on sale, with Restore.
- Will it wake me? counts the weekly delivery check while it is switched on. Two missed checks or a refused push token show as Take a look, with one button to act on it.
- A missed alarm on Will it wake me? names the topic and time, offers a test, and can be closed there. Closing it clears it from Home.
- A permission you were never asked for can be allowed from Will it wake me? without opening system settings.
- On a phone that uses your own server, the Pro row and the Pro sheet say before you pay that the weekly check covers the push relay to the phone, and says nothing about your server.
- Setup shows where you are with three bars, and Back takes you one step back until your first topic is made
- Setup now shows your first topic landing on the Topics screen, then points at it once when setup ends.

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
- The Hosted sheet lists what the plan adds and what Free keeps.
- The permissions screen is called Permissions. It was called Health.
- Home says an alarm was missed in one place, the notice, with a button for what to do: Ring a test, or See the alarm. The big face no longer says All clear above it.
- Will it wake me? no longer asks for a look when an alarm rang and nobody answered.
- The sleep settings steps for Oppo, Realme and OnePlus are three steps, with the Realme and older OxygenOS routes as notes under them.
- The connect sheet keeps the server name whole at large text, shows the full address whenever the name alone does not say it all, says Replaces Crit Alarm Cloud when it does, and reads Close when the server refuses.
- A connect link refuses a server that reports a different address, path or scheme than the one shown, and a server address with invisible characters, a query or a fragment.
- Screen readers read the full server address in the connect sheet.
- Will it wake me? is a plain list now. What needs fixing sits in one card at the top, and each line says what the blocked setting costs you.
- Home no longer says All clear while a notice about missed alarms, missed checks or a phone update is showing.
- Home cards close with a plain x and share one look.
- The keyboard stays up while you scroll search results and goes away when you drag the list down.
- The welcome screen shows what the app does: a phone that rings until you tap I'm up, which alerts ring and which stay quiet, and one command from your own tools ringing your phone. Tap I'm up in the picture to stop it yourself.
- Pick a server draws the two ways an alert reaches your phone, through Crit Alarm Cloud or through your own server, and lights the one you pick.
- The welcome screen is now three pages. Swipe between them or tap Next, and the last page starts setup. The curl that rings a phone is the third page, so the separate screen for it is gone.
- The Topics screen has a new look: one card answers whether your alarms will wake you, and your topics sit below it in one list.

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
- The critical topics count card on the new topic screen wraps cleanly at large text sizes, and no longer shows before you own a critical topic.
- The message on a ringing alarm no longer sits behind the buttons on a small phone or at a large text size. The face shrinks to make room, and the message scrolls clear of the buttons when it is long.
- Setup steps at large text sizes no longer print their buttons and the app name over the text behind them.
- A list scrolled under the Topics, Settings or New topic title blurs more as it goes under, so it no longer runs sharp through the title.
- At large text sizes, Home and Will it wake me? keep the first action in view and the title no longer draws over the list.
- The Android back button closes search instead of leaving the app.

### Removed
- The QR button on the own-server form, until QR connect exists. Paste stays.
- Setup no longer shows a Stop animation button on the welcome screen or a close button on the first topic step.

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
