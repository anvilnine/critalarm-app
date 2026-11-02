import 'dart:async';
import 'package:critalarm/core/alarm/alarm_build_mode.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/push/last_push_reader.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/connect_link_analytics.dart';
import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/telemetry_build_rule.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The analytics and crash gate, built once.
Future<void> registerTelemetryGate(GetIt getIt) async {
  if (!getIt.isRegistered<TelemetryGate>()) {
    final options = () {
      try {
        return DefaultFirebaseOptions.currentPlatform;
      } on Object catch (_) {
        return null;
      }
    }();
    // Debug, profile and desk builds, and a web page off the production
    // host, send no analytics and no crash reports, whatever the user's
    // switch says. A store build still waits for that switch.
    final collectionAllowed = telemetryAllowedFor(
      isRelease: kReleaseMode,
      usesMockApi: buildUsesMockApi,
      skipsPaywall: buildSkipsPaywall,
      hasPaywallLab: buildHasPaywallLab,
      usesQuietAlarm: buildUsesQuietAlarm,
      blocksTelemetry: buildBlocksTelemetry,
      webPage: kIsWeb ? Uri.base : null,
    );
    final telemetryGate = FirebaseTelemetryGate(
      options: options,
      collectionAllowed: collectionAllowed,
      isWeb: kIsWeb,
    );
    await telemetryGate.initialize();
    getIt.registerSingleton<TelemetryGate>(telemetryGate);
  }
}

/// The analytics senders, the push event drain and the setup funnel.
void registerAnalyticsEvents(GetIt getIt) {
  getIt
    ..registerLazySingleton(() => PushAnalytics(getIt<TelemetryGate>()))
    ..registerLazySingleton(
      () => LocalReminderAnalytics(getIt<TelemetryGate>()),
    )
    ..registerLazySingleton(
      () => ConnectLinkAnalytics(getIt<TelemetryGate>()),
    )
    ..registerLazySingleton(
      () => PushEventDrain(
        getIt<SharedPreferences>(),
        getIt<TelemetryGate>(),
        lastPush: getIt<LastPushStore>(),
      ),
    )
    // Setup step events. They wait on the phone until the user answers the
    // analytics question.
    ..registerLazySingleton(
      () => OnboardingFunnel(
        prefs: getIt<SharedPreferences>(),
        gate: getIt<TelemetryGate>(),
        stepIds: OnboardingStepRegistry.requiresById.keys.toSet(),
      ),
    );
}
