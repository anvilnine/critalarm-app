import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';

/// 03:00 on the night the fixtures are about.
final opened = DateTime.utc(2026, 10, 6, 3);

/// Half an hour of ringing later, when the server gave up.
final expired = opened.add(const Duration(minutes: 30));

/// The phone was installed, set up and connected a week before.
final cutoffsLongAgo = MissedAlarmCutoffs(
  firstLaunchAt: opened.subtract(const Duration(days: 7)),
  setupDoneAt: opened.subtract(const Duration(days: 7)),
  connectedSince: opened.subtract(const Duration(days: 7)),
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
}
