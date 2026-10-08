import 'dart:async';

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:flutter/foundation.dart';

/// [MissedAlarmFeed] over the missed alarm reader and its record of closed
/// entries, with the rule the notice cubit uses.
///
/// The pieces arrive as functions, as they do for the notice cubit.
/// `lib/app/di.dart` hands over the `MissedAlarmReader` and the
/// `MissedAlarmStore` the notice is wired to, so the two views read one
/// record.
class ReaderMissedAlarmFeed implements MissedAlarmFeed {
  ReaderMissedAlarmFeed({
    required Future<List<MissedAlarm>?> Function() readMissed,
    required Set<String> Function() readDismissed,
    required Future<void> Function(List<String> incidentIds) writeDismissed,
    required Iterable<Incident> Function() readIncidents,
    required Future<bool> Function() isSetupDone,
    Stream<void>? incidentChanges,
    DateTime Function()? clock,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readMissed = readMissed,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _readDismissed = readDismissed,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _writeDismissed = writeDismissed,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _readIncidents = readIncidents,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone,
       _clock = clock ?? DateTime.now {
    _incidentSub = incidentChanges?.listen((_) => _changes.add(null));
  }

  final Future<List<MissedAlarm>?> Function() _readMissed;
  final Set<String> Function() _readDismissed;
  final Future<void> Function(List<String> incidentIds) _writeDismissed;
  final Iterable<Incident> Function() _readIncidents;
  final Future<bool> Function() _isSetupDone;
  final DateTime Function() _clock;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<void>? _incidentSub;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MissedFact?> read() async {
    final List<MissedAlarm>? missed;
    final bool isSetupDone;
    try {
      isSetupDone = await _isSetupDone();
      if (!isSetupDone) return null;
      missed = await _readMissed();
    } on Object catch (error) {
      // A failed read is "nothing to say", never an error on Home.
      debugPrint('MissedAlarmFeed: read failed: $error');
      return null;
    }
    final notice = MissedAlarmNoticeRule.noticeFor(
      isSetupDone: isSetupDone,
      missed: missed,
      dismissedIds: _readDismissed(),
      now: _clock(),
    );
    if (notice == null) return null;
    return MissedFact(notice: notice, ringDuration: _ringDuration(notice));
  }

  /// `closedAt - openedAt` of the newest missed incident, or null when either
  /// time is missing or they run backwards.
  Duration? _ringDuration(MissedAlarmNotice notice) {
    final newestId = notice.incidentIds.first;
    for (final incident in _readIncidents()) {
      if (incident.id != newestId) continue;
      final openedAt = incident.openedAt;
      final closedAt = incident.closedAt;
      if (openedAt == null || closedAt == null) return null;
      final gap = closedAt.difference(openedAt);
      return gap.isNegative ? null : gap;
    }
    return null;
  }

  @override
  Future<void> dismiss(Iterable<String> incidentIds) async {
    await _writeDismissed(incidentIds.toList());
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Stops listening. The app's feed lives as long as the app.
  Future<void> close() async {
    await _incidentSub?.cancel();
    await _changes.close();
  }
}
