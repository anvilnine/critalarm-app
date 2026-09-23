import 'dart:async';

import 'package:critalarm/app/push_bindings.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositories that answer with nothing and write down that they were asked,
/// in the order everything else happened.
class _CountingIncidents implements IncidentRepository {
  _CountingIncidents(this.log);

  final List<String> log;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    int? limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async {
    log.add('incidents');
    return const <Incident>[].toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CountingTopics implements TopicRepository {
  _CountingTopics(this.log);

  final List<String> log;

  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    log.add('topics');
    return const <Topic>[].toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PushHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> log;
  late PushHost host;
  late IncidentsCubit incidents;
  late TopicsCubit topics;
  late AppPushBindings bindings;
  late StreamController<List<Incident>> focusList;
  late AlarmFocus focus;
  late String currentLocation;

  /// Puts one open incident on the shared list, which is what turns alarm
  /// focus on.
  Future<void> ringOne() async {
    focusList.add([
      Incident(id: 'inc_1', topic: 'ops', openedAt: DateTime.now()),
    ]);
    await Future<void>.delayed(Duration.zero);
  }

  void answerWith(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  Future<void> sendFromPlatform(String method, Object? arguments) =>
      messenger.handlePlatformMessage(
        PushHost.channelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  setUp(() {
    log = [];
    currentLocation = '/';
    answerWith((_) => null);
    host = PushHost();
    incidents = IncidentsCubit(GetIncidentsUsecase(_CountingIncidents(log)));
    topics = TopicsCubit(GetTopicsUsecase(_CountingTopics(log)));
    focusList = StreamController<List<Incident>>.broadcast();
    focus = AlarmFocus(incidents: focusList.stream);
    bindings = AppPushBindings(
      host,
      incidents,
      topics,
      (location) => log.add('go $location'),
      () => currentLocation,
      (incidentId) => log.add('select $incidentId'),
      focus,
    )..start();
  });

  tearDown(() async {
    await bindings.dispose();
    await focus.dispose();
    await focusList.close();
    await host.dispose();
    await incidents.close();
    await topics.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('a push while the app is open reloads the incidents', () async {
    await sendFromPlatform('onPushReceived', null);
    await Future<void>.delayed(Duration.zero);
    expect(log, ['incidents']);
  });

  test('a push does not send the user anywhere', () async {
    await sendFromPlatform('onPushReceived', null);
    await Future<void>.delayed(Duration.zero);
    expect(log.where((entry) => entry.startsWith('go ')), isEmpty);
  });

  test('a tap that lands while the app is open opens its screen', () async {
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_9a8b7c',
      'tap_id': '1',
    });
    expect(log, ['go /incidents/inc_9a8b7c']);
  });

  test('a tap while /alarm is up selects, not navigates', () async {
    currentLocation = '/alarm';
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_9a8b7c',
      'tap_id': '1',
    });
    expect(log, ['select inc_9a8b7c']);
  });

  test('a tap while an incident is up selects, not navigates', () async {
    currentLocation = '/incidents/inc_showing';
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_9a8b7c',
      'tap_id': '1',
    });
    expect(log, ['select inc_9a8b7c']);
  });

  test('a tap on another topic is dropped while an alarm is up', () async {
    await ringOne();
    await sendFromPlatform('onNotificationTap', {
      'topic': 'ops',
      'tap_id': '1',
    });
    expect(log, isEmpty);
  });

  test('a tap on an incident still opens while an alarm is up', () async {
    await ringOne();
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_9a8b7c',
      'tap_id': '1',
    });
    expect(log, ['go /incidents/inc_9a8b7c']);
  });

  test('a held tap opens before the lists reload', () async {
    answerWith(
      (call) => call.method == 'takePending'
          ? {
              'tap': {'incident_id': 'inc_9a8b7c', 'tap_id': '1'},
            }
          : null,
    );
    await bindings.onResumed();
    expect(log.first, 'go /incidents/inc_9a8b7c');
    expect(log.skip(1), containsAll(<String>['incidents', 'topics']));
  });

  test('coming back with nothing pending still reloads both lists', () async {
    await bindings.onResumed();
    expect(log, containsAll(<String>['incidents', 'topics']));
    expect(log.where((entry) => entry.startsWith('go ')), isEmpty);
  });
}
