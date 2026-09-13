import 'dart:async';

import 'helpers/load_translations.dart';

/// Runs once before every test file under `test/`.
///
/// Loads the English strings so `LocaleKeys.x.tr()` returns real text instead
/// of the key path when a cubit builds a user-facing string.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadTestTranslations();
  await testMain();
}
