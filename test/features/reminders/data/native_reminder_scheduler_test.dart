import 'package:critalarm/features/reminders/data/native_reminder_scheduler.dart';
import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_pass.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_home_prompt_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativeReminderScheduler.channelName);
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

  final request = ReminderRequest(
    id: 9100,
    kind: ReminderKind.fireDrill,
    fireAt: DateTime(2026, 9, 26, 10, 0, 5),
    title: 'Fire drill',
    body: 'Ring prod-db once.',
    hiddenPreview: 'Crit Alarm reminder',
    channelId: 'reminders_v1',
    faceAsset: 'assets/reminder_faces/curious.png',
    actions: const [ReminderAction(id: 'ring', title: 'Ring me now')],
    payload: const {'kind': 'fire_drill', 'topic': 'prod-db'},
  );

  test('schedule sends wall-clock fields, never an instant', () async {
    answers['schedule'] = true;
    await NativeReminderScheduler(channel).schedule(request);
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
      NativeReminderScheduler(channel).schedule(request),
      throwsA(isA<ReminderScheduleRefused>()),
    );
  });

  test('schedule throws when the platform throws', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'bad_args');
    });
    await expectLater(
      NativeReminderScheduler(channel).schedule(request),
      throwsA(isA<ReminderScheduleRefused>()),
    );
  });

  test('schedule throws when the platform has no handler', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      NativeReminderScheduler(channel).schedule(request),
      throwsA(isA<ReminderScheduleRefused>()),
    );
  });

  test('a plan pass never records a reminder the platform refused', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsReminderStore(
      await SharedPreferences.getInstance(),
    );
    answers['schedule'] = false;
    await ReminderPlanPass(
      store: store,
      scheduler: NativeReminderScheduler(channel),
      settler: ReminderSettler(
        store: store,
        prompts: FakeHomePromptRepository(),
      ),
      readInputs: () async => ReminderInputs(
        now: DateTime(2026, 9, 22, 12),
        topics: const [ReminderTopic(name: 'prod-db', isCritical: true)],
        lastTestAt: {'prod-db': DateTime(2026, 8, 20)},
      ),
      copy: const ReminderCopy(isIos: true),
      isWeb: false,
      clock: () => DateTime.utc(2026, 9, 22, 12),
    ).run();
    expect(calls.map((c) => c.method), contains('schedule'));
    expect(store.readPlanned(), isEmpty);
  });

  test('decodeTap drops a tap with fields of the wrong type', () {
    expect(NativeReminderScheduler.decodeTap({'kind': 3}), isNull);
    expect(
      NativeReminderScheduler.decodeTap({'kind': 'backup', 'action': 7}),
      isNull,
    );
    expect(
      NativeReminderScheduler.decodeTap({'kind': 'backup'})?.actionId,
      ReminderActionIds.open,
    );
  });

  test('decodePending keeps the id when the kind has the wrong type', () {
    final pending = NativeReminderScheduler.decodePending({
      'id': 9300,
      'kind': 5,
    });
    expect(pending?.id, 9300);
    expect(pending?.kind, isNull);
  });

  test('cancel sends the ids and skips an empty list', () async {
    final scheduler = NativeReminderScheduler(channel);
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
    final pending = await NativeReminderScheduler(channel).pending();
    expect(pending.single.id, 9300);
    expect(pending.single.kind, ReminderKind.backup);
    expect(pending.single.fireAt, DateTime(2026, 10, 3, 10));
  });

  test('reads the time zone and the system state', () async {
    answers['deviceTimeZone'] = {'name': 'Asia/Manila', 'offset_minutes': 480};
    answers['systemState'] = {'notifications_allowed': false};
    final scheduler = NativeReminderScheduler(channel);
    final zone = await scheduler.deviceTimeZone();
    expect(zone.name, 'Asia/Manila');
    expect(zone.offsetMinutes, 480);
    expect((await scheduler.systemState()).notificationsAllowed, isFalse);
  });

  test("falls back to Dart's zone when the platform has no answer", () async {
    final zone = await NativeReminderScheduler(channel).deviceTimeZone();
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
    final scheduler = NativeReminderScheduler(channel);
    final live = <ReminderTap>[];
    scheduler.taps.listen(live.add);

    final taken = await scheduler.takePendingTap();
    expect(taken!.kind, ReminderKind.silentTopic);
    expect(taken.actionId, 'curl');
    expect(taken.payload, {'topic': 'prod-db'});

    await messenger.handlePlatformMessage(
      NativeReminderScheduler.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onReminderTap', tap),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(live, isEmpty);
  });

  test('a new live tap reaches the stream', () async {
    final scheduler = NativeReminderScheduler(channel);
    final live = <ReminderTap>[];
    scheduler.taps.listen(live.add);
    await messenger.handlePlatformMessage(
      NativeReminderScheduler.channelName,
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
    expect(live.single.kind, ReminderKind.reviewAsk);
  });
}
