import 'dart:async';

import 'package:critalarm/core/access/holding.dart';

/// Keeps the one flag native code reads, `alarm_sound_own_locked`, in step
/// with whether own sounds are open.
///
/// The Android alarm service and the iOS notification extension ring with
/// no Dart running, so they cannot ask the access layer. They read this
/// flag and nothing else about plans.
///
/// The flag changes only on a sure answer. While the plan cannot be read
/// (a locked Keychain on a background launch), or before the access layer
/// has read anything, the last written value stays. A phone that never had
/// a sure answer has no flag, and native reads no flag as "not locked".
///
/// Whatever the flag says, an alarm still rings: locked only swaps an own
/// sound for a bundled one.
class SoundLockSync {
  SoundLockSync({
    required this._isLocked,
    required this._changes,
    required this._readWritten,
    required this._write,
    required this._publish,
  });

  /// Whether own sounds are locked, asked once the access layer is ready.
  /// Throws [HoldingUnreadable] when nobody knows.
  final Future<bool> Function() _isLocked;

  /// Fires when the answer may have changed.
  final Stream<Object?> _changes;

  /// The flag as last written. Null when it never was.
  final bool? Function() _readWritten;

  final Future<void> Function({required bool locked}) _write;

  /// Hands the new value on to the iOS notification extension, which
  /// cannot read the app's own preferences.
  final Future<void> Function() _publish;

  StreamSubscription<Object?>? _subscription;
  bool _running = false;
  bool _askedAgain = false;

  /// Checks now, and again on every change.
  void start() {
    _subscription ??= _changes.listen((_) => unawaited(check()));
    unawaited(check());
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Writes the flag if a sure answer differs from what is written. One
  /// run at a time: a change that lands during a run starts one more run
  /// after it, so the last answer is the one written.
  Future<void> check() async {
    if (_running) {
      _askedAgain = true;
      return;
    }
    _running = true;
    try {
      do {
        _askedAgain = false;
        await _checkOnce();
      } while (_askedAgain);
    } finally {
      _running = false;
    }
  }

  Future<void> _checkOnce() async {
    final bool locked;
    try {
      locked = await _isLocked();
    } on HoldingUnreadable {
      // Nobody knows what this phone holds right now. The flag stays as it
      // is: a guess could take a paying person's sound away, or hand one
      // out.
      return;
    } on Object catch (_) {
      // The question itself failed. Same answer: change nothing.
      return;
    }
    if (_readWritten() == locked) return;
    try {
      await _write(locked: locked);
      await _publish();
    } on Object catch (_) {
      // A failed write leaves the old value, and the next change or
      // launch tries again.
    }
  }
}
