import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_rounds_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_check_fakes.dart';

void main() {
  late FakeWeeklyCheckApi api;
  late MemoryWeeklyCheckStore store;
  late int tierReads;

  WeeklyCheckCubit build() => WeeklyCheckCubit(
    monitor: WeeklyCheckMonitor(
      api: api,
      store: store,
      readDeviceId: () async => 'dev_1',
      readAccess: () => WeeklyCheckAccess.open,
      onTierRefused: () async => tierReads++,
    ),
  );

  setUp(() {
    api = FakeWeeklyCheckApi();
    store = MemoryWeeklyCheckStore();
    tierReads = 0;
  });

  group('the row', () {
    test('load reads the check', () async {
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
      );
      final cubit = build();
      expect(cubit.state.check, isNull);
      await cubit.load();
      expect(cubit.state.check!.state, WeeklyCheckState.received);
      await cubit.close();
    });

    test('switching on with Hosted turns the row on', () async {
      final cubit = build();
      final outcome = await cubit.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.done);
      expect(cubit.state.check!.enabled, isTrue);
      expect(cubit.state.isBusy, isFalse);
      expect(cubit.state.didFail, isFalse);
      await cubit.close();
    });

    test('switching on without Hosted hands the 403 on', () async {
      api.tier = 'free';
      final cubit = build();
      final outcome = await cubit.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.tierRefused);
      expect(tierReads, 1);
      expect(cubit.state.check!.enabled, isFalse);
      // The relay was reached, so this is not "could not reach the relay".
      expect(cubit.state.didFail, isFalse);
      // The row says why in one line, and the switch ends up off.
      expect(cubit.state.switchOutcome, WeeklyCheckSwitchOutcome.tierRefused);
      expect(
        weeklyCheckSwitchLineKey(cubit.state.switchOutcome),
        LocaleKeys.weekly_check_switch_needs_hosted,
      );
      expect(cubit.state.isBusy, isFalse);
      final standing = weeklyCheckStanding(
        check: cubit.state.check,
        access: WeeklyCheckAccess.open,
        missedByClock: cubit.state.missedByClock,
      );
      expect(standing.isOn, isFalse);
      expect(
        weeklyCheckBodyView(
          standing: standing,
          check: cubit.state.check,
          now: DateTime(2026, 10, 9),
        ).isOn,
        isFalse,
      );
      await cubit.close();
    });

    test('an account on the `relay` tier counts as Hosted on the phone and '
        'is refused by the relay: the row says it needs Hosted, switch '
        'off', () async {
      api.tier = 'relay';
      final cubit = build();
      await cubit.load();
      await cubit.setEnabled(enabled: true);
      expect(
        weeklyCheckSwitchLineKey(cubit.state.switchOutcome),
        LocaleKeys.weekly_check_switch_needs_hosted,
      );
      expect(cubit.state.check!.enabled, isFalse);
      await cubit.close();
    });

    test('a refusal with no tier named, as a relay before 1.19.0 sends, '
        'says the relay did not accept it, switch off', () async {
      api
        ..tier = 'free'
        ..answersAsBefore119 = true;
      final cubit = build();
      await cubit.setEnabled(enabled: true);
      expect(cubit.state.switchOutcome, WeeklyCheckSwitchOutcome.refused);
      expect(cubit.state.didFail, isFalse);
      expect(
        weeklyCheckSwitchLineKey(cubit.state.switchOutcome),
        LocaleKeys.weekly_check_switch_refused,
      );
      expect(cubit.state.check!.enabled, isFalse);
      await cubit.close();
    });

    test('the line goes with the next tap, and a tap that works leaves '
        'none', () async {
      api.tier = 'free';
      final cubit = build();
      await cubit.setEnabled(enabled: true);
      expect(cubit.state.switchOutcome, isNotNull);
      api.tier = 'hosted';
      await cubit.setEnabled(enabled: true);
      expect(cubit.state.switchOutcome, isNull);
      expect(weeklyCheckSwitchLineKey(cubit.state.switchOutcome), isNull);
      expect(cubit.state.check!.enabled, isTrue);
      await cubit.close();
    });

    test('every way a tap can end has its own line, and only a relay that '
        'could not be reached says so', () {
      final lines = {
        for (final outcome in WeeklyCheckSwitchOutcome.values)
          outcome: weeklyCheckSwitchLineKey(outcome),
      };
      expect(lines[WeeklyCheckSwitchOutcome.done], isNull);
      expect(
        lines.entries
            .where((e) => e.value == LocaleKeys.weekly_check_switch_failed)
            .map((e) => e.key),
        [WeeklyCheckSwitchOutcome.failed],
      );
      expect(
        lines.values.whereType<String>().toSet(),
        hasLength(WeeklyCheckSwitchOutcome.values.length - 1),
      );
    });

    test('switching off', () async {
      final cubit = build();
      await cubit.setEnabled(enabled: true);
      await cubit.setEnabled(enabled: false);
      expect(api.puts, [true, false]);
      expect(cubit.state.check!.enabled, isFalse);
      await cubit.close();
    });

    test(
      'a tap that cannot reach the relay says so and changes nothing',
      () async {
        final cubit = build();
        await cubit.setEnabled(enabled: true);
        api.isDown = true;
        await cubit.setEnabled(enabled: false);
        expect(cubit.state.didFail, isTrue);
        expect(cubit.state.check!.enabled, isTrue);
        // The next tap clears the line.
        api.isDown = false;
        await cubit.setEnabled(enabled: false);
        expect(cubit.state.didFail, isFalse);
        await cubit.close();
      },
    );

    test('the phone telling by its own clock reaches the row', () async {
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        // Long past: this phone's clock says two rounds were missed.
        noticeAfter: 1000,
      );
      final cubit = build();
      await cubit.load();
      expect(cubit.state.check!.state, WeeklyCheckState.received);
      expect(cubit.state.missedByClock, isTrue);
      await cubit.close();
    });

    test('with notice_after ahead the clock says nothing', () async {
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: 4000000000,
      );
      final cubit = build();
      await cubit.load();
      expect(cubit.state.missedByClock, isFalse);
      await cubit.close();
    });

    test('a forced load reads again inside the one-minute window', () async {
      final cubit = build();
      await cubit.load();
      await cubit.load();
      expect(api.reads, 1);
      await cubit.load(force: true);
      expect(api.reads, 2);
      await cubit.close();
    });

    test('one tap at a time', () async {
      final cubit = build();
      final first = cubit.setEnabled(enabled: true);
      expect(await cubit.setEnabled(enabled: false), isNull);
      await first;
      expect(api.puts, [true]);
      await cubit.close();
    });
  });

  group('the list of rounds', () {
    test('newest first, as the relay sent them', () async {
      api.rounds = const [
        WeeklyCheckRound(
          id: 'rnd_2',
          openedAt: 200,
          result: WeeklyCheckResult.missed,
        ),
        WeeklyCheckRound(
          id: 'rnd_1',
          openedAt: 100,
          result: WeeklyCheckResult.received,
        ),
      ];
      final cubit = WeeklyCheckRoundsCubit(api);
      await cubit.load();
      expect(
        [for (final round in cubit.state.rounds!) round.id],
        [
          'rnd_2',
          'rnd_1',
        ],
      );
      expect(api.limits, [WeeklyCheckRoundsCubit.limit]);
      expect(cubit.state.didFail, isFalse);
      await cubit.close();
    });

    test('a read that fails says so and keeps what it had', () async {
      final cubit = WeeklyCheckRoundsCubit(api);
      api.isDown = true;
      await cubit.load();
      expect(cubit.state.rounds, isNull);
      expect(cubit.state.didFail, isTrue);

      api
        ..isDown = false
        ..rounds = const [WeeklyCheckRound(id: 'rnd_1', openedAt: 100)];
      await cubit.load();
      expect(cubit.state.rounds, hasLength(1));
      expect(cubit.state.didFail, isFalse);

      api.isDown = true;
      await cubit.load();
      expect(cubit.state.rounds, hasLength(1));
      expect(cubit.state.didFail, isTrue);
      await cubit.close();
    });
  });
}
