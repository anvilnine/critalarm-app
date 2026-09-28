import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs_reader.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_in_app_notice_repository.dart';
import '../fake_local_reminder_scheduler.dart';

class _Privacy implements PrivacyRepository {
  _Privacy({this.fail = false});

  final bool fail;

  @override
  Future<AppResult<PrivacySettings>> getPrivacySettings() async => fail
      ? throw StateError('prefs')
      : const Success(
          PrivacySettings(analyticsEnabled: true, crashReportingEnabled: true),
        );

  @override
  Future<AppResult<Unit>> setAnalyticsEnabled({required bool enabled}) async =>
      const Success(unit);

  @override
  Future<AppResult<Unit>> setCrashReportingEnabled({
    required bool enabled,
  }) async => const Success(unit);
}

class _Plan implements PlanStatusSource {
  int reads = 0;

  @override
  Future<PlanStatus?> read(DeviceTimeZone timeZone) async {
    reads++;
    return null;
  }
}

void main() {
  const manila = DeviceTimeZone(name: 'Asia/Manila', offsetMinutes: 480);
  // 02:00 UTC is 10:00 in Manila.
  final instant = DateTime.utc(2026, 9, 22, 2);

  late SharedPrefsLocalReminderStore store;
  late QuietHoursStore quietHours;
  late FakeLocalReminderScheduler scheduler;
  late FakeInAppNoticeRepository notices;
  late _Plan plan;
  late List<String> polled;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = SharedPrefsLocalReminderStore(prefs);
    quietHours = QuietHoursStore(prefs);
    scheduler = FakeLocalReminderScheduler()..timeZone = manila;
    notices = FakeInAppNoticeRepository();
    plan = _Plan();
    polled = [];
  });

  var topicReads = 0;
  final boom = StateError('boom');

  LocalReminderInputsReader reader({
    List<Topic>? topics,
    List<Incident>? incidents = const [],
    ServerMode? mode = ServerMode.hosted,
    bool proShouldAsk = false,
    Future<ServerMode?> Function()? readServerMode,
    Future<bool> Function(String topic)? topicHasMessages,
    Future<bool> Function()? readIsPaid,
    Future<bool> Function()? readIsSignedIn,
    bool privacyFails = false,
  }) => LocalReminderInputsReader(
    store: store,
    notices: notices,
    quietHours: quietHours,
    scheduler: scheduler,
    planStatus: plan,
    privacy: _Privacy(fail: privacyFails),
    readTopics: () async {
      topicReads++;
      return topics ??
          [
            Topic(
              name: 'prod-db',
              critical: true,
              createdAt: DateTime.utc(2026, 9, 1, 2),
            ),
            const Topic(name: 'fresh'),
            const Topic(name: 'old'),
          ];
    },
    readIncidents: () async => incidents,
    topicHasMessages:
        topicHasMessages ??
        (topic) async {
          polled.add(topic);
          return topic == 'old';
        },
    readServerMode: readServerMode ?? () async => mode,
    readIsPaid: readIsPaid ?? () async => false,
    readIsSignedIn: readIsSignedIn ?? () async => false,
    proShouldAsk: () async => proShouldAsk,
    isWeb: false,
    isIos: true,
    appStoreId: '6700000000',
    clock: () => instant,
  );

  test('works in the phone zone, wall-clock', () async {
    final inputs = (await reader().read())!;
    expect(inputs.timeZone, manila);
    expect(inputs.now, DateTime(2026, 9, 22, 10));
    expect(inputs.topics.first.createdAt, DateTime(2026, 9, 1, 10));
    expect(inputs.isHosted, isTrue);
    expect(inputs.isIos, isTrue);
    expect(inputs.appStoreId, '6700000000');
    expect(inputs.isConsentGiven, isTrue);
  });

  test('maps incidents, marking tests and busy ones', () async {
    final inputs = (await reader(
      incidents: [
        Incident(
          id: 'inc_1',
          topic: 'prod-db',
          state: 'acked',
          openedAt: DateTime.utc(2026, 9, 21, 19),
          messages: const [
            Message(id: 'm', topic: 'prod-db', title: 'Crit Alarm test'),
          ],
        ),
      ],
    ).read())!;
    final incident = inputs.incidents.single;
    expect(incident.isTest, isTrue);
    expect(incident.isOpenOrAcked, isTrue);
    expect(incident.openedAt, DateTime(2026, 9, 22, 3));
  });

  test('gives up when incidents cannot be read', () async {
    expect(await reader(incidents: null).read(), isNull);
  });

  test('no server connection reads as no topics and no incidents', () async {
    topicReads = 0;
    final inputs = await reader(mode: null, incidents: null).read();
    expect(inputs, isNotNull);
    expect(inputs!.topics, isEmpty);
    expect(inputs.incidents, isEmpty);
    expect(topicReads, 0);
  });

  test('a failed server mode read counts as self-hosted', () async {
    final inputs = (await reader(
      readServerMode: () async => throw boom,
    ).read())!;
    expect(inputs.isSelfHosted, isTrue);
    expect(inputs.isHosted, isFalse);
    expect(inputs.topics, isNotEmpty);
    expect(plan.reads, 0);
  });

  test('a failed message poll counts as "has messages"', () async {
    await store.recordTopicCreatedHere('fresh', DateTime.utc(2026, 9, 21, 2));
    final inputs = (await reader(
      topicHasMessages: (_) async => throw boom,
    ).read())!;
    expect(inputs.silentTopicNames, isEmpty);
  });

  test('a failed paid read counts as paid', () async {
    final inputs = (await reader(readIsPaid: () async => throw boom).read())!;
    expect(inputs.isPaid, isTrue);
  });

  test('a failed sign-in read counts as signed in', () async {
    final inputs = (await reader(
      readIsSignedIn: () async => throw boom,
    ).read())!;
    expect(inputs.isSignedIn, isTrue);
  });

  test('failed privacy settings count as the defaults', () async {
    final inputs = (await reader(privacyFails: true).read())!;
    expect(inputs.isConsentGiven, isFalse);
  });

  test('polls only recent topics made here and not yet done', () async {
    await store.recordTopicCreatedHere('fresh', DateTime.utc(2026, 9, 21, 2));
    await store.recordTopicCreatedHere('old', DateTime.utc(2026, 9, 21, 3));
    await store.recordTopicCreatedHere('ancient', DateTime.utc(2026, 8));
    await store.addSilentDone('prod-db');
    final inputs = (await reader().read())!;
    expect(polled.toSet(), {'fresh', 'old'});
    expect(inputs.silentTopicNames, {'fresh'});
  });

  test('self-hosted never reads the plan', () async {
    final inputs = (await reader(mode: ServerMode.selfhosted).read())!;
    expect(inputs.isSelfHosted, isTrue);
    expect(inputs.isHosted, isFalse);
    expect(plan.reads, 0);
  });

  test('"Skip all rules" also skips the Pro rules', () async {
    await store.writeSkipRules(skip: true);
    final inputs = (await reader().read())!;
    expect(inputs.skipRules, isTrue);
    expect(inputs.proShouldAsk, isTrue);
  });

  test(
    'installedAt is always supplied, even with no first-seen stamp',
    () async {
      notices.firstSeenAt = null;
      final inputs = (await reader().read())!;
      expect(inputs.installedAt, isNotNull);
      expect(inputs.installedAt, inputs.now);
    },
  );
}
