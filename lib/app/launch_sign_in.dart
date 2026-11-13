import 'dart:async';

import 'package:critalarm/app/moved_phone_reset.dart';
import 'package:critalarm/features/account/domain/usecases/sign_in_restore.dart';

/// The launch's first step: the moved-phone reset, then the sign-in
/// restore.
///
/// The reset is awaited, because everything after it reads an identity. The
/// restore is not: it asks the server, and nothing at launch waits on who is
/// signed in. On a phone the install marker calls moved the reset drops the
/// sign-in on purpose, so the restore never sends a session in this run of
/// the app. A moved phone holds no session of its own anyway: the token is a
/// ThisDeviceOnly Keychain item and is in no backup.
///
/// Answers what the reset answered.
Future<bool> resetThenRestoreSignIn({
  required MovedPhoneReset reset,
  required SignInRestore restore,
}) async {
  final moved = await reset.run();
  if (moved) {
    restore.skipLink();
    return true;
  }
  unawaited(_quietly(restore.run));
  return false;
}

Future<void> _quietly(Future<Object?> Function() run) async {
  try {
    await run();
  } on Object catch (_) {
    // The account screen and the Settings card ask again when they load.
  }
}
