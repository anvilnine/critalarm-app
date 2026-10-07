import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/day0_card_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_in_app_notice_repository.dart';
import '../topics/support/home_setup_fakes.dart';

class _MockAccount extends Mock implements AccountRepository {}

class _MockGate extends Mock implements TelemetryGate {}

void main() {
  final now = DateTime(2026, 10, 7, 10);
  late FakeInAppNoticeRepository notices;
  late _MockGate gate;
  late Day0CardCubit cubit;

  setUp(() {
    notices = FakeInAppNoticeRepository()
      ..now = (() => now)
      ..firstRealAcknowledgedAt = now.subtract(const Duration(days: 1));
    final account = _MockAccount();
    when(account.readIsPaid).thenAnswer((_) async => false);
    when(account.readServerMode).thenAnswer((_) async => ServerMode.hosted);
    gate = _MockGate();
    when(() => gate.logEvent(any(), any())).thenAnswer((_) async {});
    cubit = Day0CardCubit(
      rules: Day0CardRules(
        noticeRepository: notices,
        accountRepository: account,
        firstMessageStore: FakeFirstMessageStore()..isReceived = true,
        isWeb: false,
        now: () => now,
      ),
      noticeRepository: notices,
      analytics: Day0CardAnalytics(gate),
    );
  });

  tearDown(() => cubit.close());

  Future<void> open() => cubit.evaluate(isNewOpen: true, isAskDue: false);

  test(
    'the first open shows it, stamps it and sends the shown event',
    () async {
      await open();
      expect(cubit.state, isTrue);
      expect(notices.day0CardShownAt, now);
      expect(notices.day0CardOpenCount, 1);
      verify(() => gate.logEvent(AnalyticsEvents.homeDay0CardShown)).called(1);
    },
  );

  test('it ends for good after three opens without a tap', () async {
    await open();
    await open();
    await open();
    expect(cubit.state, isTrue);
    expect(notices.day0CardOpenCount, 3);
    await open();
    expect(cubit.state, isFalse);
    expect(notices.day0CardEndedAt, isNotNull);
    await open();
    expect(cubit.state, isFalse);
  });

  test('a look that is not an open does not use one up', () async {
    await open();
    await cubit.evaluate(isNewOpen: false, isAskDue: false);
    expect(notices.day0CardOpenCount, 1);
    expect(cubit.state, isTrue);
  });

  test('dismiss ends it for good and sends the dismissed event', () async {
    await open();
    await cubit.dismiss();
    expect(cubit.state, isFalse);
    expect(notices.day0CardEndedAt, isNotNull);
    verify(
      () => gate.logEvent(AnalyticsEvents.homeDay0CardDismissed),
    ).called(1);
    await open();
    expect(cubit.state, isFalse);
  });

  test('See plans ends it for good', () async {
    await open();
    await cubit.seePlans();
    expect(cubit.state, isFalse);
    expect(notices.day0CardEndedAt, isNotNull);
    await open();
    expect(cubit.state, isFalse);
  });

  test('a sheet due in the same visit keeps the card from starting', () async {
    await cubit.evaluate(isNewOpen: true, isAskDue: true);
    expect(cubit.state, isFalse);
    expect(notices.day0CardShownAt, isNull);
  });
}
