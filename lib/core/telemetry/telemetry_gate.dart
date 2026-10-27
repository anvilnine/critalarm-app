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

  /// Reports one error to crash reporting. Dropped unless the user switched
  /// crash reporting on. What is sent is the error's type and its stack
  /// trace, never its message: a message can quote a server answer or an
  /// address, and those can hold the user's own words.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  /// Records one analytics event. Dropped unless the user opted in.
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]);

  /// The setup flow Remote Config holds under `onboarding_flow`, as the raw
  /// JSON text. Empty when none has been set or fetched yet. Answers at once
  /// with what is already activated and never waits for the network.
  String get onboardingFlowJson;

  /// The switches of the setup offer step Remote Config holds under
  /// `onboarding_offer`, as the raw JSON text. Empty when none has been set
  /// or fetched yet. Answers at once and never waits for the network.
  String get onboardingOfferJson;
}

/// A no-op implementation of [TelemetryGate] used for testing or fallback.
class NoopTelemetryGate implements TelemetryGate {
  const NoopTelemetryGate({
    this.onboardingFlowJson = '',
    this.onboardingOfferJson = '',
  });

  @override
  final String onboardingOfferJson;

  @override
  final String onboardingFlowJson;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> setCrashlyticsEnabled(bool enabled) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {}

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async {}
}
