import 'package:critalarm/features/local_reminders/data/native_local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_pass.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_in_app_notice_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativeLocalReminderScheduler.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object?> answers;

  setUp(() {
    calls = [];
    answers = {};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answers[call.method];
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final request = LocalReminderRequest(
    id: 9100,
    kind: LocalReminderKind.fireDrill,
    fireAt: DateTime(2026, 9, 26, 10, 0, 5),
    title: 'Fire drill',
    body: 'Ring prod-db once.',
    hiddenPreview: 'Crit Alarm reminder',
    channelId: 'reminders_v1',
    faceAsset: 'assets/reminder_faces/curious.png',
    actions: const [LocalReminderAction(id: 'ring', title: 'Ring me now')],
    payload: const {'kind': 'fire_drill', 'topic': 'prod-db'},
  );

  test('schedule sends wall-clock fields, never an instant', () async {
    answers['schedule'] = true;
    await NativeLocalReminderScheduler(channel).schedule(request);
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(calls.single.method, 'schedule');
    expect(args['id'], 9100);
    expect(args['kind'], 'fire_drill');
    expect(args['category'], 'reminder_fire_drill');
    expect(args['channel'], 'reminders_v1');
    expect(
      [
        args['year'],
        args['month'],
        args['day'],
        args['hour'],
        args['minute'],
        args['second'],
      ],
      [2026, 9, 26, 10, 0, 5],
    );
    expect(args['face_asset'], 'assets/reminder_faces/curious.png');
    expect(args['actions'], [
      {'id': 'ring', 'title': 'Ring me now', 'opens_app': true},
    ]);
    expect(args['payload'], {'kind': 'fire_drill', 'topic': 'prod-db'});
  });

  test('schedule throws when the platform answers false', () async {
    answers['schedule'] = false;
    await expectLater(
      NativeLocalReminderScheduler(channel).schedule(request),
      throwsA(isA<LocalReminderScheduleRefused>()),
    );
  });

  test('schedule throws when the platform throws', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'bad_args');
    });
    await expectLater(
      NativeLocalReminderScheduler(channel).schedule(request),
      throwsA(isA<LocalReminderScheduleRefused>()),
    );
  });

  test('schedule throws when the platform has no handler', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      NativeLocalReminderScheduler(channel).schedule(request),
      throwsA(isA<LocalReminderScheduleRefused>()),
    );
  });

  test('a plan pass never records a reminder the platform refused', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
    answers['schedule'] = false;
    await LocalReminderPlanPass(
      store: store,
      scheduler: NativeLocalReminderScheduler(channel),
      settler: LocalReminderSettler(
        store: store,
        notices: FakeInAppNoticeRepository(),
      ),
      readInputs: () async => LocalReminderInputs(
        now: DateTime(2026, 9, 22, 12),
        topics: const [LocalReminderTopic(name: 'prod-db', isCritical: true)],
        lastTestAt: {'prod-db': DateTime(2026, 8, 20)},
      ),
      copy: const LocalReminderCopy(isIos: true),
      isWeb: false,
      clock: () => DateTime.utc(2026, 9, 22, 12),
    ).run();
    expect(calls.map((c) => c.method), contains('schedule'));
    expect(store.readPlanned(), isEmpty);
  });

  test('decodeTap drops a tap with fields of the wrong type', () {
    expect(NativeLocalReminderScheduler.decodeTap({'kind': 3}), isNull);
    expect(
      NativeLocalReminderScheduler.decodeTap({'kind': 'backup', 'action': 7}),
      isNull,
    );
    expect(
      NativeLocalReminderScheduler.decodeTap({'kind': 'backup'})?.actionId,
      LocalReminderActionIds.open,
    );
  });

  test('decodePending keeps the id when the kind has the wrong type', () {
    final pending = NativeLocalReminderScheduler.decodePending({
      'id': 9300,
      'kind': 5,
    });
    expect(pending?.id, 9300);
    expect(pending?.kind, isNull);
  });

  test('cancel sends the ids and skips an empty list', () async {
    final scheduler = NativeLocalReminderScheduler(channel);
    await scheduler.cancel(const []);
    expect(calls, isEmpty);
    await scheduler.cancel(const [9100, 9300]);
    expect(calls.single.arguments, {
      'ids': [9100, 9300],
    });
  });

  test('pending reads the list back', () async {
    answers['pending'] = [
      {
        'id': 9300,
        'kind': 'backup',
        'year': 2026,
        'month': 10,
        'day': 3,
        'hour': 10,
        'minute': 0,
        'second': 0,
      },
      'garbage',
    ];
    final pending = await NativeLocalReminderScheduler(channel).pending();
    expect(pending.single.id, 9300);
    expect(pending.single.kind, LocalReminderKind.backup);
    expect(pending.single.fireAt, DateTime(2026, 10, 3, 10));
  });

  test('reads the time zone and the system state', () async {
    answers['deviceTimeZone'] = {'name': 'Asia/Manila', 'offset_minutes': 480};
    answers['systemState'] = {'notifications_allowed': false};
    final scheduler = NativeLocalReminderScheduler(channel);
    final zone = await scheduler.deviceTimeZone();
    expect(zone.name, 'Asia/Manila');
    expect(zone.offsetMinutes, 480);
    expect((await scheduler.systemState()).notificationsAllowed, isFalse);
  });

  test("falls back to Dart's zone when the platform has no answer", () async {
    final zone = await NativeLocalReminderScheduler(channel).deviceTimeZone();
    expect(zone.offsetMinutes, DateTime.now().timeZoneOffset.inMinutes);
  });

  test('takes a pending tap once, even if it also came live', () async {
    final tap = {
      'kind': 'silent_topic',
      'action': 'curl',
      'tap_id': 'r1',
      'payload': {'topic': 'prod-db'},
    };
    answers['takePendingTap'] = tap;
    final scheduler = NativeLocalReminderScheduler(channel);
    final live = <LocalReminderTap>[];
    scheduler.taps.listen(live.add);

    final taken = await scheduler.takePendingTap();
    expect(taken!.kind, LocalReminderKind.silentTopic);
    expect(taken.actionId, 'curl');
    expect(taken.payload, {'topic': 'prod-db'});

    await messenger.handlePlatformMessage(
      NativeLocalReminderScheduler.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onReminderTap', tap),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(live, isEmpty);
  });

  test('a new live tap reaches the stream', () async {
    final scheduler = NativeLocalReminderScheduler(channel);
    final live = <LocalReminderTap>[];
    scheduler.taps.listen(live.add);
    await messenger.handlePlatformMessage(
      NativeLocalReminderScheduler.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onReminderTap', {
          'kind': 'review_ask',
          'action': 'open',
          'tap_id': 'r7',
        }),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(live.single.kind, LocalReminderKind.reviewAsk);
  });
}
