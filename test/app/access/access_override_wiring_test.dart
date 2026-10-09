import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's real composition root, in the build this test run is: one
/// with no SKIP_PAYWALL, the same as a store build. The phone's saved
/// preferences say every developer switch is on, as they would after a
/// developer build was replaced by a store build on the same phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'dev.access.hosted': 'held',
      'dev.access.pro': 'held',
      'dev.access.server': 'ownServer',
      'dev.pro_mode': true,
      'dev.pro_pack': true,
    });
    await getIt.reset();
    await configureDependencies(useMockApi: true);
  });

  tearDown(getIt.reset);

  test('a store build registers no developer switch', () {
    expect(buildSkipsPaywall, isFalse);
    expect(getIt.isRegistered<DevAccessSwitches>(), isFalse);
    expect(getIt.isRegistered<DevProSwitch>(), isFalse);
    expect(getIt.isRegistered<ProPackDevSwitch>(), isFalse);
    expect(appAccessOverride, isA<NoAccessOverride>());
  });

  test(
    'saved switches force nothing: every feature is as it really is',
    () async {
      final holdings = getIt<Holdings>();
      final access = getIt<FeatureAccess>();
      await access.ready;

      expect(holdings.held, isEmpty);
      for (final holding in Holding.values) {
        expect(holdings.stateOf(holding), HoldingState.notHeld);
      }
      // Connected to nothing, not the forced "own server".
      expect(access.serverMode, isNull);
      expect(access.isOwnServer, isFalse);
      for (final feature in AppFeature.values) {
        expect(
          access.decide(feature),
          isA<FeatureLocked>(),
          reason: '$feature',
        );
      }
    },
  );

  test('Holdings reads every source through the override wrapper', () {
    final sources = getIt<List<OverriddenHoldingSource>>();
    expect(sources.map((source) => source.holding), Holding.values);
    for (final source in sources) {
      expect(source.state, source.realState);
    }
    final mode = getIt<OverriddenServerMode>();
    expect(mode.value, mode.realValue);
  });
}
