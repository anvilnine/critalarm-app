// The draft is set field by field, so cascades would hide the steps.
// ignore_for_file: cascade_invocations

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';

final DateTime now = DateTime(2026, 10, 9, 12);

const weeklyCheckId = ReliabilityCheckId('weekly_check');

ReliabilityCheck check(
  ReliabilityCheckId id, {
  ReliabilityState state = ReliabilityState.fine,
  String? reason,
  ReliabilityFix? fix,
}) => ReliabilityCheck(id: id, state: state, reason: reason, fix: fix);

/// The checks a phone gives, by platform and how many sources apply. All fine.
List<ReliabilityCheck> androidChecks(int count) {
  const ids = [
    ReliabilityCheckIds.notifications,
    ReliabilityCheckIds.fullScreenAlarm,
    ReliabilityCheckIds.batteryOptimization,
    ReliabilityCheckIds.pushTokenConfirmed,
    ReliabilityCheckIds.lastPushReceived,
    ReliabilityCheckIds.systemUpdate,
    ReliabilityCheckIds.missedAlarm,
    ReliabilityCheckIds.phoneMaker,
    weeklyCheckId,
  ];
  return [for (final id in ids.take(count)) check(id)];
}

List<ReliabilityCheck> iphoneChecks(int count) {
  const ids = [
    ReliabilityCheckIds.notifications,
    ReliabilityCheckIds.timeSensitive,
    ReliabilityCheckIds.pushTokenConfirmed,
    ReliabilityCheckIds.lastPushReceived,
    ReliabilityCheckIds.systemUpdate,
    ReliabilityCheckIds.missedAlarm,
    weeklyCheckId,
    ReliabilityCheckIds.alarms,
  ];
  return [for (final id in ids.take(count)) check(id)];
}

/// [checks] with the check at [index] replaced.
List<ReliabilityCheck> withCheckAt(
  List<ReliabilityCheck> checks,
  int index,
  ReliabilityState state, {
  String? reason,
  ReliabilityFix? fix,
}) => [
  for (var i = 0; i < checks.length; i++)
    if (i == index)
      check(checks[i].id, state: state, reason: reason, fix: fix)
    else
      checks[i],
];

const setupAfterServer = SetupChecklist(
  isVisible: true,
  hasServer: true,
  hasTopics: true,
  hasCriticalTopic: false,
  hasFirstMessage: false,
);

const setupFirstMessageOpen = SetupChecklist(
  isVisible: true,
  hasServer: true,
  hasTopics: true,
  hasCriticalTopic: true,
  hasFirstMessage: false,
);

MissedFact missedFact({
  int count = 1,
  Duration? ringDuration = const Duration(minutes: 10),
}) => MissedFact(
  notice: MissedAlarmNotice(
    incidentIds: [for (var i = 0; i < count; i++) 'm$i'],
    topic: 'prod-db',
    at: DateTime(2026, 10, 9, 3, 12),
    reason: MissedReason.rangUnanswered,
  ),
  ringDuration: ringDuration,
);

/// A mutable draft of a [HomeCardInput], so a test says only what differs
/// from a quiet, healthy phone with three topics.
class Draft {
  DateTime at = now;
  bool isLoading = false;
  bool hasServer = true;
  bool isStale = false;
  bool loadFailed = false;
  DateTime? lastKnownGoodAt;
  int topicCount = 3;
  RingingFact? ringing;
  AcknowledgedFact? acknowledged;
  HandledFact? handled;
  MissedFact? missed;
  int warningCount = 0;
  bool loaded = true;
  bool incomplete = false;
  List<ReliabilityCheck> checks = androidChecks(7);
  SetupChecklist? setup;
  String? firstTopic = 'prod-db';
  String? watchedTopic = 'prod-db';
  DateTime? newestMessageAt;
  DateTime? lastAlarmAt;
  bool hasCriticalTopic = true;

  HomeCardInput build() => HomeCardInput(
    now: at,
    isLoading: isLoading,
    hasServer: hasServer,
    isStale: isStale,
    loadFailed: loadFailed,
    lastKnownGoodAt: lastKnownGoodAt,
    topicCount: topicCount,
    ringing: ringing,
    acknowledged: acknowledged,
    handled: handled,
    missed: missed,
    warningCount: warningCount,
    readiness: ReadinessInput(
      loaded: loaded,
      incomplete: incomplete,
      checks: checks,
    ),
    setup: setup,
    firstTopic: firstTopic,
    watchedTopic: watchedTopic,
    newestMessageAt: newestMessageAt,
    lastAlarmAt: lastAlarmAt,
    hasCriticalTopic: hasCriticalTopic,
  );
}

/// For each kind, what to set on a [Draft] so that kind's condition holds.
/// Setting one kind never switches another kind's condition off, except that
/// setup and waiting read the same checklist and exclude each other.
final Map<HomeCardKind, void Function(Draft)> satisfy = {
  HomeCardKind.loading: (d) => d.isLoading = true,
  HomeCardKind.ringing: (d) => d.ringing = RingingFact(
    incidentId: 'inc-ring',
    topic: 'prod-db',
    openedAt: now.subtract(const Duration(minutes: 2, seconds: 17)),
  ),
  HomeCardKind.acknowledged: (d) => d.acknowledged = AcknowledgedFact(
    incidentId: 'inc-ack',
    topic: 'prod-db',
    deadline: now.add(const Duration(minutes: 9)),
  ),
  HomeCardKind.handled: (d) => d.handled = HandledFact(
    topic: 'prod-db',
    closedAt: now.subtract(const Duration(seconds: 5)),
    answeredAfter: const Duration(seconds: 11),
  ),
  HomeCardKind.missed: (d) => d.missed = missedFact(),
  HomeCardKind.noServer: (d) => d.hasServer = false,
  HomeCardKind.stale: (d) {
    d.isStale = true;
    d.lastKnownGoodAt = DateTime(2026, 10, 8, 23, 10);
  },
  HomeCardKind.loadFailed: (d) => d.loadFailed = true,
  HomeCardKind.noTopics: (d) => d.topicCount = 0,
  HomeCardKind.issueBroken: (d) {
    d.checks = [
      ...d.checks,
      check(
        ReliabilityCheckIds.alarms,
        state: ReliabilityState.broken,
        reason: 'denied',
      ),
    ];
  },
  HomeCardKind.issueLook: (d) {
    d.checks = [
      ...d.checks,
      check(
        ReliabilityCheckIds.batteryOptimization,
        state: ReliabilityState.needsLook,
        reason: 'denied',
      ),
    ];
  },
  HomeCardKind.warning: (d) => d.warningCount = 2,
  HomeCardKind.setup: (d) => d.setup = setupAfterServer,
  HomeCardKind.waiting: (d) => d.setup = setupFirstMessageOpen,
  HomeCardKind.quiet: (d) =>
      d.newestMessageAt = now.subtract(const Duration(days: 8)),
  HomeCardKind.idle: (d) {},
};

Incident incident({
  String id = 'i1',
  String topic = 'prod-db',
  String state = IncidentStates.open,
  DateTime? openedAt,
  DateTime? ackedAt,
  DateTime? closedAt,
  DateTime? deskTimerFiresAt,
  List<Message> messages = const [],
}) => Incident(
  id: id,
  topic: topic,
  state: state,
  openedAt: openedAt,
  ackedAt: ackedAt,
  closedAt: closedAt,
  deskTimerFiresAt: deskTimerFiresAt,
  messages: messages,
);

Message message({int priority = 3, String topic = 'prod-db'}) =>
    Message(id: 'm-$priority', topic: topic, priority: priority);
