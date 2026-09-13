/// Abstract contract for telemetry, analytics, crash reporting,
/// and remote configuration.
abstract interface class TelemetryGate {
  /// Initializes telemetry with collection disabled by default
  /// and configures remote config defaults.
  Future<void> initialize();

  /// Toggles anonymous usage analytics collection.
  ///
  /// When enabled, enables analytics collection.
  /// When disabled, disables analytics collection and clears
  /// any cached analytics data.
  // Contract requires positional boolean parameter.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setAnalyticsEnabled(bool enabled);

  /// Toggles crash reporting collection.
  // Contract requires positional boolean parameter.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCrashlyticsEnabled(bool enabled);

  /// Records one analytics event. Dropped unless the user opted in.
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]);

  /// Whether the paywall feature is enabled via Remote Config.
  bool get paywallEnabled;

  /// Alias for [paywallEnabled].
  bool get isPaywallEnabled;
}

/// A no-op implementation of [TelemetryGate] used for testing or fallback.
class NoopTelemetryGate implements TelemetryGate {
  const NoopTelemetryGate({this.paywallEnabled = false});

  @override
  final bool paywallEnabled;

  @override
  bool get isPaywallEnabled => paywallEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> setCrashlyticsEnabled(bool enabled) async {}

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async {}
}
