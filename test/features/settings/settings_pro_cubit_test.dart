import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';

void main() {
  group('SettingsCubit Pro state', () {
    late TestAccess access;
    late SettingsCubit cubit;

    setUp(() {
      access = TestAccess();
      cubit = SettingsCubit(holdings: access.holdings);
    });

    tearDown(() async {
      await cubit.close();
      await access.dispose();
    });

    test('is not read before the screen loads, so no row is drawn', () {
      expect(cubit.state.proState, isNull);
    });

    test('is not read when there are no holdings to ask', () async {
      final bare = SettingsCubit();
      await bare.load();

      expect(bare.state.proState, isNull);
      await bare.close();
    });

    test('reads where Pro stands once the phone has been asked', () async {
      await cubit.load();

      expect(cubit.state.proState, HoldingState.notHeld);
    });

    test('follows Holdings from not owned to checking to owned', () async {
      await cubit.load();

      access.pro.set(HoldingState.pending);
      await settle();
      expect(cubit.state.proState, HoldingState.pending);

      access.pro.set(HoldingState.held);
      await settle();
      expect(cubit.state.proState, HoldingState.held);
    });

    test('reads an unknown Pro as unknown, not as not owned', () async {
      access.pro.set(HoldingState.unknown);
      await cubit.load();

      expect(cubit.state.proState, HoldingState.unknown);
    });

    test('moves with Pro alone: Hosted stays as it was', () async {
      await cubit.load();
      expect(cubit.state.holdsHosted, isFalse);

      access.pro.set(HoldingState.held);
      await settle();

      expect(cubit.state.holdsHosted, isFalse);

      access.hosted.set(HoldingState.held);
      await settle();

      expect(cubit.state.holdsHosted, isTrue);
      expect(cubit.state.proState, HoldingState.held);
    });
  });
}
