import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';

/// 03:00 on the night the fixtures are about.
final DateTime opened = DateTime.utc(2026, 10, 6, 3);

/// Half an hour of ringing later, when the server gave up.
final DateTime expired = opened.add(const Duration(minutes: 30));

/// The phone was installed, set up and connected a week before.
final MissedAlarmCutoffs cutoffsLongAgo = MissedAlarmCutoffs(
  firstLaunchAt: opened.subtract(const Duration(days: 7)),
  setupDoneAt: opened.subtract(const Duration(days: 7)),
  connectedSince: opened.subtract(const Duration(days: 7)),
  topicHeldSince: opened.subtract(const Duration(days: 7)),
);

/// [cutoffsLongAgo] with some of the four moved.
MissedAlarmCutoffs cutoffsWith({
  DateTime? firstLaunchAt,
  DateTime? setupDoneAt,
  DateTime? connectedSince,
  DateTime? topicHeldSince,
  bool noFirstLaunch = false,
  bool noSetup = false,
  bool noConnection = false,
  bool noTopic = false,
}) => MissedAlarmCutoffs(
  firstLaunchAt: noFirstLaunch
      ? null
      : firstLaunchAt ?? cutoffsLongAgo.firstLaunchAt,
  setupDoneAt: noSetup ? null : setupDoneAt ?? cutoffsLongAgo.setupDoneAt,
  connectedSince: noConnection
      ? null
      : connectedSince ?? cutoffsLongAgo.connectedSince,
  topicHeldSince: noTopic
      ? null
      : topicHeldSince ?? cutoffsLongAgo.topicHeldSince,
);

Incident incidentFixture({
  String id = 'inc_1',
  String topic = 'prod',
  String state = IncidentStates.expired,
  DateTime? openedAt,
  DateTime? ackedAt,
  DateTime? closedAt,
  int priority = 5,
  bool hasOpenedAt = true,
}) => Incident(
  id: id,
  topic: topic,
  state: state,
  openedAt: hasOpenedAt ? (openedAt ?? opened) : null,
  ackedAt: ackedAt,
  closedAt: closedAt ?? (state == IncidentStates.expired ? expired : null),
  messages: [Message(id: 'm_$id', topic: topic, priority: priority)],
);

class MemoryMissedAlarmStore implements MissedAlarmStore {
  PhoneRecord record = const PhoneRecord();
  Map<String, DateTime> dismissed = {};
  DateTime? setupDoneAt;
  ConnectedServer? connected;
  Map<String, List<TopicHold>> topicHolds = {};

  /// The start of the open stretch of each topic still held.
  Map<String, DateTime> get topicsHeldSince => {
    for (final entry in topicHolds.entries)
      if (entry.value.last.until == null) entry.key: entry.value.last.since,
  };

  set topicsHeldSince(Map<String, DateTime> since) => topicHolds = {
    for (final entry in since.entries)
      entry.key: [TopicHold(since: entry.value)],
  };
  int serverClears = 0;

  @override
  PhoneRecord readRecord() => record;

  @override
  Future<void> writeRecord(PhoneRecord next) async => record = next;

  @override
  Map<String, DateTime> readDismissed() => dismissed;

  @override
  Future<void> writeDismissed(Map<String, DateTime> next) async =>
      dismissed = next;

  @override
  DateTime? readSetupDoneAt() => setupDoneAt;

  @override
  Future<void> writeSetupDoneAt(DateTime at) async => setupDoneAt = at;

  @override
  ConnectedServer? readConnected() => connected;

  @override
  Future<void> writeConnected(ConnectedServer next) async => connected = next;

  @override
  Map<String, List<TopicHold>> readTopicHolds() => topicHolds;

  @override
  Future<void> writeTopicHolds(Map<String, List<TopicHold>> next) async =>
      topicHolds = next;

  @override
  Future<void> clearServerData() async {
    serverClears++;
    record = const PhoneRecord();
    dismissed = {};
    topicHolds = {};
  }
}
