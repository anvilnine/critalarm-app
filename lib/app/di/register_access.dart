import 'dart:async';
import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/access/observed_api_session_store.dart';
import 'package:critalarm/app/access/pro_holding_source.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/diagnostics/quietly.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/pro_pack/data/prefs_pro_pack_dev_switch.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer plan switches, in a build that skips the store.
void registerDevAccessSwitches(
  GetIt getIt, {
  required SharedPreferences prefs,
}) {
  if (buildSkipsPaywall) {
    // The one store behind every developer plan switch: a state per
    // holding and a server mode, set by the Plans and features lab. The
    // only place it is handed to the rest of the app. In a store build
    // appAccessOverride is a NoAccessOverride and this call does nothing.
    if (!getIt.isRegistered<DevAccessSwitches>()) {
      getIt.registerSingleton<DevAccessSwitches>(DevAccessSwitches(prefs));
    }
    final accessSwitches = getIt<DevAccessSwitches>();
    appAccessOverride.watch(accessSwitches);

    // The two older toggles are "force held" on that same store. The older
    // override classes hear it too, for the three readers that are not
    // Holdings, the Settings plan row among them. In a store build both are
    // compiled as the No variant.
    if (!getIt.isRegistered<DevProSwitch>()) {
      getIt.registerSingleton<DevProSwitch>(DevProSwitch(accessSwitches));
    }
    appProOverride.watch(getIt<DevProSwitch>());
    if (!getIt.isRegistered<ProPackDevSwitch>()) {
      getIt.registerSingleton<ProPackDevSwitch>(
        PrefsProPackDevSwitch(accessSwitches),
      );
    }
    appProPackOverride.watch(getIt<ProPackDevSwitch>());
  }
}

/// What this install holds, and whether each feature is open.
void registerAccess(GetIt getIt) {
  // What this install holds. One source per thing a person can buy, and
  // the sources are the only readers of the store, the relay's answer and
  // the developer switches.
  getIt
    ..registerLazySingleton<HostedHoldingSource>(
      () => HostedHoldingSource(
        readIdentity: () => getIt<DeviceIdentityStore>().readOrCreate(),
        // The source keeps the last tier it read. Every write to the store
        // makes it read again, so a sign-out or a deleted account never
        // leaves the old tier standing.
        identityChanges: [
          appAccountIdentityChanges,
          getIt<DeviceIdentityStore>().changes,
        ],
        readStore: buildSkipsPaywall ? null : getIt.get<SubscriptionRepository>,
        // The developer switch is not read in here. It reaches Holdings
        // through the wrapper below, so this source says what the server
        // and the store say.
        proOverride: const NoProOverride(),
      ),
    )
    // Each source with the developer override in front of it: the one seam
    // that can force a holding's state, for every holding. A store build
    // compiles the override as a NoAccessOverride, and each wrapper then
    // answers with its source's own state.
    ..registerLazySingleton<List<OverriddenHoldingSource>>(
      () => [
        OverriddenHoldingSource(getIt<HostedHoldingSource>()),
        OverriddenHoldingSource(
          ProHoldingSource(getIt<ProPackAccess>(), countsDevSwitch: false),
        ),
      ],
    )
    ..registerLazySingleton<Holdings>(
      () => Holdings(getIt<List<OverriddenHoldingSource>>()),
    )
    // The saved session's server mode, with the same override in front.
    ..registerLazySingleton<OverriddenServerMode>(
      () => OverriddenServerMode(getIt<ObservedApiSessionStore>().mode),
    )
    // Whether a feature is open. The server mode comes from the saved
    // session: the one on disk at launch, then every connect that writes a
    // new one.
    ..registerLazySingleton<FeatureAccess>(() {
      final sessions = getIt<ObservedApiSessionStore>();
      final mode = getIt<OverriddenServerMode>();
      final access = FeatureAccess(
        holdings: getIt<Holdings>(),
        serverMode: mode.value,
        // `ready` waits for this, so nothing is taken away from a phone on
        // its own server before the saved session says so.
        serverModeRead: sessions.read().then<void>(
          (_) {},
          onError: (Object e) => noteQuiet('access.serverModeRead', e),
        ),
      );
      mode.changes.addListener(() => access.setServerMode(mode.value));
      return access;
    });
}

/// Makes the mock relay follow the developer switches.
void linkDevSwitchesToMockRelay(GetIt getIt, {required bool useMockApi}) {
  if (buildSkipsPaywall && useMockApi) {
    // In a mock build the developer switch also makes the mock relay hold
    // the pack, so the read from it and the two pack routes answer the same
    // as the switch.
    final devSwitch = getIt<ProPackDevSwitch>();
    void applyToMock() {
      final granted = getIt<MockServer>().grantedPacks;
      if (devSwitch.value) {
        granted.add(proPackId);
      } else {
        granted.remove(proPackId);
      }
      unawaited(getIt<ProPackAccess>().refresh(force: true));
    }

    devSwitch.addListener(applyToMock);
    applyToMock();

    // The same for Hosted: the mock relay goes by the fixture account's
    // tier for the weekly check, so the switch sets it.
    final hostedSwitch = getIt<DevProSwitch>();
    void applyTierToMock() {
      getIt<MockServer>().accountTier = hostedSwitch.value ? 'hosted' : 'free';
      unawaited(getIt<WeeklyCheckMonitor>().refresh(force: true));
    }

    hostedSwitch.addListener(applyTierToMock);
    applyTierToMock();
  }
}
