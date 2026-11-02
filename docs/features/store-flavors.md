# Store flavors

Moved out of AGENTS.md on 2026-11-02 (added to main on 2026-10-28, after the split branch left). Read before changing this area.

**Store flavors.** Every Android build names a store: `--flavor play|galaxy|huawei`
and the same name as `--dart-define=STORE`, read once in `lib/app/di.dart` into
`StoreKind` (`lib/core/platform/store_kind.dart`). The Make targets pass both,
`STORE=play` by default, and leave them out for an iPhone, whose store is
`apple`. A bare `fvm flutter run` on Android stops and asks for a flavor.
`play` is `app.critalarm`; `galaxy` and `huawei` add `.galaxy` and `.huawei`.
Play-only native code (Play Asset Delivery, `SoundPackChannel`) lives in
`android/app/src/play/` and comes in with `playImplementation`; the other two
flavors have their own `SoundPackChannel` that answers `unavailable`. The play
release bundle is `build/app/outputs/bundle/playRelease/app-play-release.aab`.

**Commands.** The Make targets pass the flavor and `STORE` for you.

- Another store's app, to check it: `make build-store-apk STORE=galaxy` (or `huawei`; `play`
  is the default) and `make build-store-appbundle STORE=...`.
- Buy for real on a device (sandbox or licence tester): `make run-store DEVICE=<id>`.
  `run-release` skips the store.
- Store leak check: `make check-store-leaks` (builds under `build/`), or
  `sh tool/store_leak_check.sh <apk-or-aab> <play|galaxy|huawei> [mapping.txt]`.

**Desk builds.** `make run-store`, `make build-store-apk` and `make build-store-appbundle`
send no analytics and are never uploaded.

- The two build targets delete `build/release-android.stamp`, so
  `release-android.sh --upload-only` refuses until a real release build.
- An iOS archive for the store comes only from `make release-ios`, never from a manual Xcode
  archive after `make run-store`.
- Store uploads go only through `make release-android` and `make release-ios`.

**Firebase files in worktrees.** Git ignores these files, so `.claude/hooks/worktree-prep.sh`
copies them from the main checkout into a new worktree.

- The `play` `google-services.json` goes to `android/app/src/play/` on a branch that has the
  store flavors, and to `android/app/google-services.json` on an older branch. Either layout in
  the main checkout feeds either kind of branch.
- Without the `play` file, a play build fails at `:app:processPlayReleaseGoogleServices`.
- Gradle refuses a copy left at `android/app/` on a flavored branch.
- The `galaxy` and `huawei` files (`android/app/src/<flavor>/`) are symlinks into `secrets/` in
  the main checkout. The hook copies what they point at.
- `ios/Runner/GoogleService-Info.plist` is copied the same way.
- `make quality` runs the Play leak check (`check-play-leaks`).

The table of packages and Firebase paths is in `README.md` under "Store flavors".
