import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/update_incident_badge_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PushHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late PushHost host;
  late _StubIncidents incidents;
  late UpdateIncidentBadgeUsecase update;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    host = PushHost();
    incidents = _StubIncidents();
    update = UpdateIncidentBadgeUsecase(incidents, AppBadge(host));
  });

  tearDown(() async {
    await host.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('the badge counts the open incidents', () async {
    incidents.open = [_incident('inc_1'), _incident('inc_2')];

    expect(await update(), 2);
    expect(calls.single.arguments, {'count': 2});
  });

  test('closing the last one clears the badge', () async {
    incidents.open = [];

    expect(await update(), 0);
    expect(calls.single.arguments, {'count': 0});
  });

  test('only open incidents are counted', () async {
    incidents.open = [_incident('inc_1')];

    await update();
    expect(incidents.askedForState, 'open');
  });

  test('a failed read leaves the badge alone', () async {
    incidents.fail = true;

    expect(await update(), isNull);
    expect(calls, isEmpty);
  });
}

Incident _incident(String id) => Incident(
  id: id,
  topic: 'prod-db',
  openedAt: DateTime.utc(2026),
  lastMessageAt: DateTime.utc(2026),
);

class _StubIncidents implements IncidentRepository {
  List<Incident> open = [];
  bool fail = false;
  String? askedForState;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    int? limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async {
    askedForState = state;
    if (fail) return const Failure.unexpected(message: 'offline').toFailure();
    return open.toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
