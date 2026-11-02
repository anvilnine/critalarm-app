# Backups and restores

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Backups and restores.** A restored phone starts as a phone the relay has
never seen, and a person's own alarm photo and own sounds are in no backup.

- Android restores nothing. The manifest sets `android:allowBackup="false"`
  and points at `res/xml/data_extraction_rules.xml` and
  `res/xml/backup_rules.xml`, which leave every domain out. The rules files
  are needed: on Android 12 and later `allowBackup="false"` alone does not
  stop a phone to phone transfer. The main preferences file holds identity
  next to taste, so no part of it is let through. `BackupRulesTest` reads
  the three files.
- An iPhone backup carries the preferences, the app group and, in an
  encrypted computer backup or a phone to phone transfer, the Keychain. So
  the app asks at launch whether the install moved. `InstallMarker`
  (`ios/Runner/BackupGuard.swift`) keeps one random id in the preferences
  and in a Keychain item of class `AfterFirstUnlockThisDeviceOnly`, which
  no other phone can restore. The two disagreeing means the install moved.
  A Keychain that cannot be asked decides nothing.
- `MovedPhoneReset` (`lib/app/moved_phone_reset.dart`) is the first thing
  `main` waits for. On a moved install it runs `AccountData.forget()`, and
  that is the only thing that drops account data. Then it drops the device
  identity, the record of the push token last sent, and, on every server
  but one of the person's own, the session and the connection, because both
  hold the old phone's device token. It ends with a `BackgroundConnect` to
  the same server, the path a fresh install takes. The synced account item
  stays, so the phone joins the person's account as a new device. Taste
  (theme, chosen sound, quiet hours) stays.
- A value that names this phone to the relay, or a flag written on a sure
  answer about the plan, either goes on the `AccountData` list or is
  dropped by `MovedPhoneReset`. Add it there when you add one.
- The own photo folder `alarm_look` carries `isExcludedFromBackup`, set by
  `FileOwnLookStore` when it makes the folder and at each launch sweep. Own
  sounds share `Library/Sounds` with the bundled and pack sounds, so each
  `user_` file is flagged on its own, at import and at launch
  (`BackupExclusion.excludeOwnSounds`). A file that is written again has
  lost the flag, which is why both run at every launch.
- A backup carries the photo record and the own sound list but not the
  files. Both then name a file that is not there, which the app already
  treats as nothing to draw and nothing to ring.

