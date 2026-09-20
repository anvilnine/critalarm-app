import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Firebase implementation of [TelemetryGate].
///
/// Handles analytics, crashlytics, and remote configuration
/// using official Firebase plugins.
/// Collection is strictly disabled at startup and enabled only
/// via explicit user opt-in.
class FirebaseTelemetryGate implements TelemetryGate {
  FirebaseTelemetryGate({
    this.app,
    this.options,
    this.analytics,
    this.crashlytics,
    this.remoteConfig,
  });

  final FirebaseApp? app;
  final FirebaseOptions? options;
  FirebaseAnalytics? analytics;
  FirebaseCrashlytics? crashlytics;
  FirebaseRemoteConfig? remoteConfig;

  static const Duration defaultFetchTimeout = Duration(seconds: 10);
  static const Duration minimumFetchInterval = Duration(hours: 1);
  static const String paywallEnabledKey = 'paywall_enabled';
  static const String paywallVariantKeyName = 'paywall_variant';

  static const Map<String, dynamic> remoteConfigDefaults = {
    paywallEnabledKey: false,
    paywallVariantKeyName: 'straight',
  };

  bool _isInitialized = false;
  bool _analyticsEnabled = false;
  bool _crashlyticsEnabled = false;

  bool get isInitialized => _isInitialized;
  bool get isAnalyticsEnabled => _analyticsEnabled;
  bool get isCrashlyticsEnabled => _crashlyticsEnabled;

  @override
  Future<void> initialize() async {
    try {
      if (app == null && Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(options: options);
        } on Object catch (_) {
          // Safe initialization: missing config or test environment
        }
      }

      final hasApp = app != null || Firebase.apps.isNotEmpty;
      if (analytics == null && hasApp) {
        try {
          analytics = app != null
              ? FirebaseAnalytics.instanceFor(app: app!)
              : FirebaseAnalytics.instance;
        } on Object catch (_) {}
      }

      if (crashlytics == null && hasApp) {
        try {
          crashlytics = FirebaseCrashlytics.instance;
        } on Object catch (_) {}
      }

      if (remoteConfig == null && hasApp) {
        try {
          remoteConfig = app != null
              ? FirebaseRemoteConfig.instanceFor(app: app!)
              : FirebaseRemoteConfig.instance;
        } on Object catch (_) {}
      }

      // By default, collection is DISABLED at startup
      await analytics?.setAnalyticsCollectionEnabled(false);
      await crashlytics?.setCrashlyticsCollectionEnabled(false);
      _analyticsEnabled = false;
      _crashlyticsEnabled = false;

      // Sets Remote Config settings (1 hour minimum fetch interval)
      await remoteConfig?.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: defaultFetchTimeout,
          minimumFetchInterval: minimumFetchInterval,
        ),
      );

      // Sets Remote Config defaults ({'paywall_enabled': false})
      await remoteConfig?.setDefaults(remoteConfigDefaults);

      // Attempt to fetch and activate remote config values
      try {
        await remoteConfig?.fetchAndActivate();
      } on Object catch (_) {
        // Fall back to defaults on fetch failure or offline
      }

      _isInitialized = true;
    } on Object catch (_) {
      // Safe initialization: handle gracefully without crashing
    }
  }

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {
    _analyticsEnabled = enabled;
    try {
      if (enabled) {
        await analytics?.setAnalyticsCollectionEnabled(true);
      } else {
        await analytics?.setAnalyticsCollectionEnabled(false);
        await analytics?.resetAnalyticsData();
      }
    } on Object catch (_) {
      // Gracefully handle missing or failed platform channel
    }
  }

  @override
  Future<void> setCrashlyticsEnabled(bool enabled) async {
    _crashlyticsEnabled = enabled;
    try {
      if (enabled) {
        await crashlytics?.setCrashlyticsCollectionEnabled(true);
      } else {
        await crashlytics?.setCrashlyticsCollectionEnabled(false);
      }
    } on Object catch (_) {
      // Gracefully handle missing or failed platform channel
    }
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    if (!_analyticsEnabled) return;
    try {
      await analytics?.logEvent(
        name: name,
        parameters: parameters == null
            ? null
            : {
                for (final entry in parameters.entries)
                  if (entry.value != null) entry.key: entry.value!,
              },
      );
    } on Object catch (_) {
      // Analytics is best-effort; a failed send never breaks the alarm path.
    }
  }

  @override
  bool get paywallEnabled {
    try {
      return remoteConfig?.getBool(paywallEnabledKey) ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  bool get isPaywallEnabled => paywallEnabled;

  @override
  String get paywallVariantKey {
    try {
      return remoteConfig?.getString(paywallVariantKeyName) ?? '';
    } on Object catch (_) {
      return '';
    }
  }
}
