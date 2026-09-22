import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AlarmHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('hands the text to the notification extension', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });

    await AlarmHost(channel).cacheIncidentContent(
      incidentId: 'inc_9a8b7c',
      title: 'Database down',
      body: 'db01 is unreachable',
      tags: const ['rotating_light'],
      click: 'https://status.example.com/db01',
      topic: 'prod-db',
      lastMessageAt: 1700000000,
    );

    expect(seen?.method, 'cacheIncidentContent');
    expect(seen?.arguments, {
      'incident_id': 'inc_9a8b7c',
      'title': 'Database down',
      'body': 'db01 is unreachable',
      'tags': ['rotating_light'],
      'click': 'https://status.example.com/db01',
      'topic': 'prod-db',
      'last_message_at': 1700000000,
    });
  });

  test('leaves out what the incident did not come with', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });

    await AlarmHost(
      channel,
    ).cacheIncidentContent(incidentId: 'inc_1', title: 'Up', body: 'All good');

    expect(seen?.arguments, {
      'incident_id': 'inc_1',
      'title': 'Up',
      'body': 'All good',
      'tags': <String>[],
    });
  });

  test('a platform with no such idea is not an error', () async {
    await AlarmHost(
      channel,
    ).cacheIncidentContent(incidentId: 'inc_1', title: 'Up', body: 'All good');
  });
}
