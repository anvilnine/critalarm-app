import 'dart:async';
import 'package:critalarm/app/app.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await EasyLocalization.ensureInitialized();
  await configureDependencies();
  // The iOS ACK action runs with no engine and writes straight to the queue
  // Dart drains. Listen before asking for the backlog, or the one waiting from
  // a cold launch is missed.
  final pushHost = getIt<PushHost>();
  pushHost.queuedAcks.listen((_) => unawaited(getIt<AckQueue>().flush()));

  // A notification tapped while the app was closed opens its own screen. iOS
  // hands that route over on a channel; Android sets the platform route name.
  final tappedRoute = await pushHost.takePendingRoute();
  final initialLocation = await getIt<InitialRouteResolver>()(
    deepLink: tappedRoute,
  );
  // The gate starts with collection off every launch, so the saved choice has
  // to be put back before anything is reported.
  final privacy = await getIt<GetPrivacySettingsUsecase>()(const NoParams());
  final analyticsOn = privacy.getOrNull()?.analyticsEnabled ?? false;
  await getIt<TelemetryGate>().setAnalyticsEnabled(analyticsOn);

  // Anything the native push handler recorded while Dart was asleep. Reported
  // only if the user turned analytics on.
  unawaited(getIt<PushEventDrain>().drain());

  // Acks queued offline go out as soon as the network is back.
  unawaited(getIt<AckQueue>().start());

  if (!buildUsesMockApi) {
    // api.md §4.2: register on launch, and again whenever the push token
    // rotates. Failures are retried on the next launch.
    unawaited(getIt<DeviceTokenRegistry>().start());
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      fallbackLocale: const Locale('en'),
      path: Assets.translations.path,
      child: CritAlarmApp(initialLocation: initialLocation),
    ),
  );
}
