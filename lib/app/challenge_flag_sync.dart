import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';

/// Keeps the one flag per topic that native code reads,
/// `topic_challenge_owed.<topic>`, in step with whether that topic owes a
/// wake-up challenge.
///
/// The Android acknowledged card and the iOS Live Activity draw their Done
/// button with no Dart running, so they cannot ask the access layer. They
/// read this flag and nothing else about plans: set, Done opens the app on
/// the incident; not set, Done closes it as it always has.
///
/// A flag is set only on a sure answer. While the plan cannot be read (a
/// locked Keychain on a background launch), or before the access layer has
/// read anything, what is written stays. A phone that never had a sure
/// "open" has no flag, so without the plan no flag is ever set. The one
/// thing that needs no plan is taking a flag away from a topic that has no
/// challenge chosen any more.
///
/// Whatever a flag says, "I'm up" stops the ring with one tap. The flag is
/// about the button that closes an incident already acknowledged.
class ChallengeFlagSync {
  ChallengeFlagSync({
    required this._decide,
    required this._changes,
    required this._readChoices,
    required this._readWritten,
    required this._write,
    required this._publish,
    this._redraw,
  });

  /// The decision for wake-up challenges, asked once the access layer is
  /// ready. Throws [HoldingUnreadable] when nobody knows.
  final Future<FeatureDecision> Function() _decide;

  /// Each fires when the answer may have changed: the plan, a choice.
  final List<Stream<Object?>> _changes;

  /// The topics that have a challenge chosen.
  final Set<String> Function() _readChoices;

  /// The topics flagged now. A read that throws counts as none, and the
  /// next sure answer writes what is missing.
  final Set<String> Function() _readWritten;

  final Future<void> Function(String topic, {required bool isOwed}) _write;

  /// Hands the flags on to the iOS Live Activity, which cannot read the
  /// app's own preferences. True once that copy is made, and true where
  /// there is no copy to make.
  final Future<bool> Function() _publish;

  /// Asks the surfaces that draw a Done button from the flag to draw it
  /// again, once a changed flag has reached where they read it. Today that
  /// is the home screen widgets, through the snapshot rewrite they already
  /// have. Null where there is nothing to redraw.
  final void Function()? _redraw;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _running = false;
  bool _askedAgain = false;

  /// A flag was written and the Live Activity's copy was not made yet.
  /// Every check tries again until it is. Kept in memory only: the app
  /// makes the copy at every launch, from what is written.
  bool _publishOwed = false;

  /// Whether a written flag still has to reach the Live Activity.
  bool get isPublishOwed => _publishOwed;

  /// Checks now, and again on every change.
  void start() {
    if (_subscriptions.isEmpty) {
      for (final stream in _changes) {
        _subscriptions.add(stream.listen((_) => unawaited(check())));
      }
    }
    unawaited(check());
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Writes the flags a sure answer changes, and makes a copy that is
  /// still owed. One run at a time: a change that lands during a run
  /// starts one more run after it, so the last answer is the one written.
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
    FeatureDecision? decision;
    try {
      decision = await _decide();
    } on HoldingUnreadable {
      // Nobody knows what this phone holds right now. Flags for topics
      // that still have a challenge chosen stay as they are.
      decision = null;
    } on Object catch (_) {
      // The question itself failed. Same answer.
      decision = null;
    }
    final Set<String> chosen;
    try {
      chosen = _readChoices();
    } on Object catch (_) {
      // What is chosen could not be read, so nothing here is sure.
      return;
    }
    final changes = challengeFlagChangesFor(
      topicsWithChoice: chosen,
      written: _written(),
      decision: decision,
    );
    for (final topic in changes.clear) {
      await _writeOne(topic, isOwed: false);
    }
    for (final topic in changes.set) {
      await _writeOne(topic, isOwed: true);
    }
    if (!_publishOwed) return;
    try {
      if (!await _publish()) return;
      _publishOwed = false;
    } on Object catch (_) {
      // Still owed. The next check tries again.
      return;
    }
    try {
      _redraw?.call();
    } on Object catch (_) {
      // A surface that could not be redrawn keeps the button it has until
      // its next redraw of its own.
    }
  }

  Future<void> _writeOne(String topic, {required bool isOwed}) async {
    try {
      await _write(topic, isOwed: isOwed);
      _publishOwed = true;
    } on Object catch (_) {
      // A failed write leaves the old value, and the next change, resume
      // or launch tries again.
    }
  }

  Set<String> _written() {
    try {
      return _readWritten();
    } on Object catch (_) {
      return const <String>{};
    }
  }
}
