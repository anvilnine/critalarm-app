import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_rounds_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_check_fakes.dart';

void main() {
  late FakeWeeklyCheckApi api;
  late MemoryWeeklyCheckStore store;
  late List<String?> refusedPacks;
  late bool isSelfHosted;

  WeeklyCheckCubit build() => WeeklyCheckCubit(
    monitor: WeeklyCheckMonitor(
      api: api,
      store: store,
      readDeviceId: () async => 'dev_1',
      onPackRefused: (pack) async => refusedPacks.add(pack),
    ),
    readIsSelfHosted: () async => isSelfHosted,
  );

  setUp(() {
    api = FakeWeeklyCheckApi();
    store = MemoryWeeklyCheckStore();
    refusedPacks = [];
    isSelfHosted = false;
  });

  group('the row', () {
    test(
      'load reads the check and whether the server is self-hosted',
      () async {
        isSelfHosted = true;
        api.check = const WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.received,
        );
        final cubit = build();
        expect(cubit.state.check, isNull);
        await cubit.load();
        expect(cubit.state.check!.state, WeeklyCheckState.received);
        expect(cubit.state.isSelfHosted, isTrue);
        await cubit.close();
      },
    );

    test('switching on with the pack turns the row on', () async {
      final cubit = build();
      final outcome = await cubit.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.done);
      expect(cubit.state.check!.enabled, isTrue);
      expect(cubit.state.isBusy, isFalse);
      expect(cubit.state.didFail, isFalse);
      await cubit.close();
    });

    test('switching on without the pack hands the 403 on', () async {
      api.hasPack = false;
      final cubit = build();
      final outcome = await cubit.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.packRefused);
      expect(refusedPacks, ['pro']);
      expect(cubit.state.check!.enabled, isFalse);
      // It is the pack list that locks the row, so this is not a failure.
      expect(cubit.state.didFail, isFalse);
      await cubit.close();
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
