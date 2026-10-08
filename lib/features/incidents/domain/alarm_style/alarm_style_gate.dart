import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_rule.dart';

/// Answers, for the alarm screen and the pages that preview it, which look
/// to draw.
///
/// It gathers what [alarmStyleFor] needs and decides nothing itself. It
/// never throws: anything that goes wrong reads as the standard look, so
/// the alarm screen always draws.
///
/// It also keeps the one note the rule reads while the plan cannot be
/// read: whether the last sure answer was "open". [check] writes it, on a
/// sure answer only, under the account the answer was for. A note for
/// another account, or read before this phone's account is known, counts
/// as no note.
class AlarmStyleGate {
  AlarmStyleGate({
    required this._choices,
    required this._decide,
    required this._decideOnceReady,
    required this._readAccountId,
    required Future<void> planRead,
    this._changes = const [],
    this._isOwnLookReady,
  }) {
    unawaited(
      planRead.then<void>((_) => _isPlanRead = true, onError: (Object _) {}),
    );
  }

  final AlarmStyleChoices _choices;

  /// The access layer's answer for alarm screen styles, right now.
  final FeatureDecision Function() _decide;

  /// The same answer, asked once the plan was read. Throws when nobody
  /// knows.
  final Future<FeatureDecision> Function() _decideOnceReady;

  /// The account this phone is on, or null when it has none yet.
  final Future<String?> Function() _readAccountId;

  /// The tag of that account, once [check] has read it.
  String? _accountTag;

  /// Whether the person's own photo is decoded and held in memory right
  /// now. Left out, the own look is never ready. It must answer at once:
  /// the alarm screen asks it while it rings.
  final bool Function()? _isOwnLookReady;

  /// Each fires when the answer may have changed.
  final List<Stream<Object?>> _changes;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _isPlanRead = false;
  bool _running = false;
  bool _askedAgain = false;

  /// The look to draw for [topicName], or the phone's own look when it is
  /// null. [isSetupAlarm] is the alarm screen's own knowledge of the
  /// incident.
  AlarmStyleId styleFor(String? topicName, {bool isSetupAlarm = false}) {
    try {
      return alarmStyleFor(
        saved: _choices.assignments,
        topicName: topicName,
        decision: _decide(),
        isPlanRead: _isPlanRead,
        wasOpenWhenLastSure: openNoteCountsFor(
          noteTag: _choices.openNote,
          accountTag: _accountTag,
        ),
        isSetupAlarm: isSetupAlarm,
        isOwnLookReady: _isOwnLookReady?.call() ?? false,
      );
    } on Object catch (_) {
      return AlarmStyleId.standard;
    }
  }

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

  /// Writes the note when a sure answer changes it. One run at a time: a
  /// change that lands during a run starts one more after it, so the last
  /// answer is the one written.
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
    // First, and on its own: the note counts only once the account is
    // known, and that must not wait for the plan.
    try {
      _accountTag = alarmStyleAccountTag(await _readAccountId());
    } on Object catch (_) {
      // An account that cannot be read is not known. What was read before
      // stays.
    }
    FeatureDecision? decision;
    try {
      decision = await _decideOnceReady();
    } on Object catch (_) {
      // Nobody knows what this phone holds right now, or the question
      // itself failed. The note stays as it is.
      decision = null;
    }
    try {
      final written = _choices.openNote;
      final next = openNoteAfter(
        written: written,
        decision: decision,
        accountTag: _accountTag,
      );
      if (next != written) await _choices.writeOpenNote(next);
    } on Object catch (_) {
      // A failed read or write leaves the old note, and the next change,
      // resume or launch tries again.
    }
  }
}
