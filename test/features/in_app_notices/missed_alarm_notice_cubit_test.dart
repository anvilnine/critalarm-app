import 'dart:async';

import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/in_app_notices/domain/system_update_notice_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_in_app_notice_repository.dart';
import 'in_app_notice_cubit_test.dart'
    show
        FakeAccountRepo,
        FakeGetConnectionUsecase,
        FakeIdentityRepo,
        FakeShellCubit;

void main() {
  late FakeInAppNoticeRepository notices;
  late FakeGetConnectionUsecase getConnection;
  late FakeShellCubit shell;
  late AccountIdentityChanges identityChanges;
  late List<MissedAlarm>? missed;
  late Set<String> dismissed;
  late bool setupDone;
  late int reads;
  late StreamController<void> changes;

  final now = DateTime(2026, 10, 7, 9);

  MissedAlarm alarm(
    String id, {
    Duration ago = const Duration(hours: 6),
    MissedReason reason = MissedReason.unanswered,
  }) => MissedAlarm(
    incidentId: id,
    topic: 'prod',
    at: now.subtract(ago),
    reason: reason,
  );

  InAppNoticeCubit build({
    Future<SystemUpdateReading?> Function()? readSystemUpdate,
  }) => InAppNoticeCubit(
    getConnectionUsecase: getConnection,
    shellCubit: shell,
    identityRepository: FakeIdentityRepo(identityChanges),
    accountRepository: FakeAccountRepo(),
    noticeRepository: notices,
    readTopics: () async => const [Topic(name: 'prod', critical: true)],
    clock: () => now,
    identityChanges: identityChanges,
    isSetupDone: () async => setupDone,
    readSystemUpdate: readSystemUpdate,
    readMissedAlarms: () async {
      reads++;
      return missed;
    },
    readDismissedMissedAlarms: () => dismissed,
    dismissMissedAlarms: (ids) async => dismissed = {...dismissed, ...ids},
    missedAlarmChanges: changes.stream,
  );

  setUp(() {
    notices = FakeInAppNoticeRepository()..now = (() => now);
    getConnection = FakeGetConnectionUsecase()
      ..result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
    shell = FakeShellCubit();
    identityChanges = AccountIdentityChanges();
    missed = [alarm('a')];
    dismissed = {};
    setupDone = true;
    reads = 0;
    changes = StreamController<void>.broadcast();
  });

  tearDown(() => changes.close());

  test('shows the entry for a missed alarm', () async {
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.missedAlarm);
    expect(cubit.state.missedAlarm!.incidentIds, ['a']);
    await cubit.close();
  });

  test('three missed alarms are one entry with a count', () async {
    missed = [
      alarm('a'),
      alarm('b', ago: const Duration(hours: 1)),
      alarm('c', ago: const Duration(days: 1)),
    ];
    final cubit = build();
    await cubit.load();
    expect(cubit.state.missedAlarm!.count, 3);
    expect(cubit.state.missedAlarm!.incidentIds.first, 'b');
    await cubit.close();
  });

  test('nothing shows, and nothing is read, before setup is done', () async {
    setupDone = false;
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.none);
    expect(reads, 0);
    await cubit.close();
  });

  test('no server comes first', () async {
    getConnection = FakeGetConnectionUsecase();
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.noServer);
    await cubit.close();
  });

  test('a broken permission comes first', () async {
    shell.setHealth(
      const ShellHealth(
        missing: [
          DevicePermissionItem(
            type: DevicePermissionType.notifications,
            status: DevicePermissionStatus.denied,
            title: 'Notifications',
            description: 'Required for alerts',
            canFix: true,
          ),
        ],
      ),
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.criticalHealth);
    await cubit.close();
  });

  test('it comes before the system update notice', () async {
    final cubit = build(
      readSystemUpdate: () async =>
          const SystemUpdateReading(needsLook: true, osMajor: 27),
    );
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.missedAlarm);
    await cubit.close();
  });

  test(
    'closing it stores every alarm it stood for and it stays gone',
    () async {
      missed = [alarm('a'), alarm('b', ago: const Duration(hours: 1))];
      final cubit = build();
      await cubit.load();
      await cubit.dismissCurrent();
      expect(dismissed, {'a', 'b'});
      expect(cubit.state.noticeType, InAppNoticeType.none);
      await cubit.close();

      // The next launch: a new cubit over what was stored.
      final next = build();
      await next.onAppResumed();
      expect(next.state.noticeType, isNot(InAppNoticeType.missedAlarm));
      await next.close();
    },
  );

  test('a new missed alarm after a close shows on its own', () async {
    dismissed = {'a'};
    missed = [alarm('a'), alarm('b', ago: const Duration(minutes: 30))];
    final cubit = build();
    await cubit.load();
    expect(cubit.state.missedAlarm!.incidentIds, ['b']);
    await cubit.close();
  });

  test('a read that throws shows nothing and no error', () async {
    final cubit = InAppNoticeCubit(
      getConnectionUsecase: getConnection,
      shellCubit: shell,
      identityRepository: FakeIdentityRepo(identityChanges),
      accountRepository: FakeAccountRepo(),
      noticeRepository: notices,
      readTopics: () async => const <Topic>[],
      clock: () => now,
      identityChanges: identityChanges,
      readMissedAlarms: () async => throw StateError('no list'),
    );
    await cubit.load();
    expect(cubit.state.noticeType, isNot(InAppNoticeType.missedAlarm));
    await cubit.close();
  });

  test('it asks again when an incident runs out', () async {
    missed = const [];
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, isNot(InAppNoticeType.missedAlarm));

    missed = [alarm('a')];
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.noticeType, InAppNoticeType.missedAlarm);
    await cubit.close();
  });

  test('a cubit with no missed alarm wiring behaves as before', () async {
    final cubit = InAppNoticeCubit(
      getConnectionUsecase: getConnection,
      shellCubit: shell,
      identityRepository: FakeIdentityRepo(identityChanges),
      accountRepository: FakeAccountRepo(),
      noticeRepository: notices,
      readTopics: () async => const <Topic>[],
      clock: () => now,
      identityChanges: identityChanges,
    );
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.none);
    await cubit.close();
  });
}
