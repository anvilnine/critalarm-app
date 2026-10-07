import 'dart:async';
import 'package:critalarm/app/app.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/reliability/data/platform_phone_capture.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/sources/system_update_source.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/gen/assets.gen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Registers the bundled font faces' OFL licenses so they surface in
/// Settings > Acknowledgements (`showLicensePage`). Bundled asset fonts need
/// this done by hand.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'Anton': 'assets/fonts/Anton-OFL.txt',
      'Archivo': 'assets/fonts/Archivo-OFL.txt',
      'IBM Plex Mono': 'assets/fonts/IBMPlexMono-OFL.txt',
    }.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}

/// Credits every sound in the downloadable packs in Settings >
/// Acknowledgements, whether or not this phone has downloaded them.
void _registerSoundPackCredits() {
  LicenseRegistry.addLicense(() async* {
    for (final pack in SoundPacks.all) {
      yield LicenseEntryWithLineBreaks([
        'Sound pack: ${pack.englishName}',
      ], pack.creditsText);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  _registerSoundPackCredits();
  await EasyLocalization.ensureInitialized();
  await configureDependencies();
  // The iOS ACK action runs with no engine and writes straight to the queue
  // Dart drains. Listen before asking for the backlog, or the one waiting from
  // a cold launch is missed.
  final pushHost = getIt<PushHost>();
  pushHost.queuedAcks.listen((_) => unawaited(getIt<AckQueue>().flush()));

  // iOS reads alarm and notification sounds by name out of the app bundle or
  // Library/Sounds, and Flutter assets are in neither. This copies every
  // bundled sound somewhere the OS can find them. Android does nothing here.
  unawaited(
    getIt<SoundHost>().prepareBundledSounds(
      BundledSounds.catalogue(platform: defaultTargetPlatform),
    ),
  );

  if (kDebugMode) {
    // Needed to aim a real APNs push at this handset. `flutter run` prints
    // this; the matching NSLog in AppDelegate only shows up in Xcode.
    final apnsToken = await pushHost.apnsToken();
    if (apnsToken != null) debugPrint('CritAlarm: apns_token=$apnsToken');
  }

  // The gate starts with collection off every launch, so the saved choice has
  // to be put back before anything is reported.
  final privacy = await getIt<GetPrivacySettingsUsecase>()(const NoParams());
  final analyticsOn = privacy.getOrNull()?.analyticsEnabled ?? false;
  await getIt<TelemetryGate>().setAnalyticsEnabled(analyticsOn);
  // Setup events waiting for an answer are sent, deleted or aged out. With
  // analytics off and no answer this makes no analytics call at all.
  unawaited(getIt<OnboardingFunnel>().start(analyticsOn: analyticsOn));

  // A notification tapped while the app was closed opens its own screen. iOS
  // hands that route over on a channel; Android sets the platform route name.
  final tappedRoute = await pushHost.takePendingRoute();
  final initialLocation = await getIt<InitialRouteResolver>()(
    deepLink: tappedRoute,
  );
  // Crash reporting is put back here as well, so a crash on a launch where
  // Settings is never opened still gets reported.
  final crashReportingOn = privacy.getOrNull()?.crashReportingEnabled ?? false;
  await getIt<TelemetryGate>().setCrashlyticsEnabled(crashReportingOn);

  // The missed alarm check keeps its own copy of those rows. It reads the
  // list on this line, before the drain below empties it.
  getIt<PlatformPhoneCapture>()
    ..start()
    ..holdPendingRows();

  // Anything the native push handler recorded while Dart was asleep. Reported
  // only if the user turned analytics on.
  unawaited(getIt<PushEventDrain>().drain());
  unawaited(getIt<MissedAlarmReader>().record());

  // Acks queued offline go out as soon as the network is back.
  unawaited(getIt<AckQueue>().start());

  // The first tool alarm's own acknowledged screen is owed once. If it was
  // acknowledged in an earlier run, that moment is over. Awaited, so no
  // alarm screen of this run can read the old record.
  try {
    await getIt<SetupTestRing>().settleFirstToolAtLaunch();
  } on Object catch (_) {
    // The phone would not save it. The alarm screen checks again itself.
  }

  // A setup test the server would not close last time would ring again as
  // a real alarm, so it is closed now that the app is open again.
  unawaited(getIt<EndSetupTestUsecase>().closeLeftovers());

  // A connect the last run left waiting, for a network that was not there,
  // is picked up again.
  unawaited(getIt<BackgroundConnect>().resumeSaved());

  if (!buildUsesMockApi) {
    // api.md §4.2: register on launch, and again whenever the push token
    // rotates. Failures are retried on the next launch.
    unawaited(getIt<DeviceTokenRegistry>().start());

    // The Live Activity tokens go up the same way. A push-to-start token that
    // never arrives shows as "not ready" and is asked for again next launch.
    unawaited(getIt<LiveActivityTokenRegistry>().start());
  }

  // api.md §4.2: the account's packs, read from the relay on every launch.
  // The last answer is on the phone already, so nothing waits on this.
  unawaited(getIt<ProPackAccess>().refresh());

  // A phone that was updated since the last launch is stamped now, so the
  // reliability check counts tests from the real moment of the update.
  unawaited(getIt<SystemUpdateSource>().recordVersionAtLaunch());

  // The server is the truth on launch: any card still up for an incident it
  // has finished with comes down, and any alarm still set for one stops.
  final alarms = getIt<IncidentAlarmController>();
  unawaited(alarms.start());
  unawaited(alarms.reconcile());

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      fallbackLocale: const Locale('en'),
      path: Assets.translations.path,
      child: CritAlarmApp(initialLocation: initialLocation),
    ),
  );
}
