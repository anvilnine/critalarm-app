import 'dart:async';

import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/in_app_notices/domain/system_update_notice_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
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
  late AccountIdentityChanges identityChanges;
  late bool stopped;
  late bool setupDone;
  late int dismissals;
  late StreamController<void> changes;

  final now = DateTime(2026, 10, 7, 9);

  InAppNoticeCubit build({
    Future<List<MissedAlarm>?> Function()? readMissedAlarms,
    Future<SystemUpdateReading?> Function()? readSystemUpdate,
  }) => InAppNoticeCubit(
    getConnectionUsecase: getConnection,
    shellCubit: FakeShellCubit(),
    identityRepository: FakeIdentityRepo(identityChanges),
    accountRepository: FakeAccountRepo(),
    noticeRepository: notices,
    readTopics: () async => const [Topic(name: 'prod', critical: true)],
    clock: () => now,
    identityChanges: identityChanges,
    isSetupDone: () async => setupDone,
    readMissedAlarms: readMissedAlarms,
    readSystemUpdate: readSystemUpdate,
    readWeeklyCheckStopped: () async => stopped,
    dismissWeeklyCheck: () async {
      dismissals++;
      stopped = false;
    },
    weeklyCheckChanges: changes.stream,
  );

  setUp(() {
    notices = FakeInAppNoticeRepository()..now = (() => now);
    getConnection = FakeGetConnectionUsecase()
      ..result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
    identityChanges = AccountIdentityChanges();
    stopped = true;
    setupDone = true;
    dismissals = 0;
    changes = StreamController<void>.broadcast();
  });

  tearDown(() => changes.close());

  test('shows when weekly checks stopped arriving', () async {
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.weeklyCheck);
    await cubit.close();
  });

  test('shows nothing while checks arrive', () async {
    stopped = false;
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, isNot(InAppNoticeType.weeklyCheck));
    await cubit.close();
  });

  test('waits for setup like every other notice', () async {
    setupDone = false;
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.none);

    setupDone = true;
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.weeklyCheck);
    await cubit.close();
  });

  test('closing it tells the weekly check and it stays gone', () async {
    final cubit = build();
    await cubit.load();
    await cubit.dismissCurrent();
    expect(dismissals, 1);
    expect(cubit.state.noticeType, InAppNoticeType.none);
    await cubit.close();

    final next = build();
    await next.onAppResumed();
    expect(next.state.noticeType, isNot(InAppNoticeType.weeklyCheck));
    await next.close();
  });

  test('a later run of misses shows it again', () async {
    final cubit = build();
    await cubit.load();
    await cubit.dismissCurrent();
    stopped = true;
    await cubit.onAppResumed();
    expect(cubit.state.noticeType, InAppNoticeType.weeklyCheck);
    await cubit.close();
  });

  test('a change in the weekly check is looked at again', () async {
    stopped = false;
    final cubit = build();
    await cubit.load();
    expect(cubit.state.noticeType, isNot(InAppNoticeType.weeklyCheck));

    stopped = true;
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.noticeType, InAppNoticeType.weeklyCheck);
    await cubit.close();
  });

  test('a missed alarm comes first', () async {
    final cubit = build(
      readMissedAlarms: () async => [
        MissedAlarm(
          incidentId: 'a',
          topic: 'prod',
          at: now.subtract(const Duration(hours: 6)),
          reason: MissedReason.unanswered,
        ),
      ],
    );
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.missedAlarm);
    await cubit.close();
  });

  test('it comes before the phone update notice', () async {
    final cubit = build(
      readSystemUpdate: () async =>
          const SystemUpdateReading(needsLook: true, osMajor: 27),
    );
    await cubit.load();
    expect(cubit.state.noticeType, InAppNoticeType.weeklyCheck);
    await cubit.close();
  });

  test('a read that throws is nothing to say', () async {
    final cubit = InAppNoticeCubit(
      getConnectionUsecase: getConnection,
      shellCubit: FakeShellCubit(),
      identityRepository: FakeIdentityRepo(identityChanges),
      accountRepository: FakeAccountRepo(),
      noticeRepository: notices,
      readTopics: () async => const [Topic(name: 'prod', critical: true)],
      clock: () => now,
      identityChanges: identityChanges,
      readWeeklyCheckStopped: () async => throw StateError('disk'),
    );
    await cubit.load();
    expect(cubit.state.noticeType, isNot(InAppNoticeType.weeklyCheck));
    await cubit.close();
  });
}
