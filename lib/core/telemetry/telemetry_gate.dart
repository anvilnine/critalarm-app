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

  /// Which paywall layout Remote Config picked for this device, as the raw
  /// string under `paywall_variant`. `PaywallVariant.fromKey` turns an
  /// unknown value into the default, so this getter never has to validate.
  String get paywallVariantKey;

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
    this.paywallEnabled = false,
    this.paywallVariantKey = '',
    this.onboardingFlowJson = '',
    this.onboardingOfferJson = '',
  });

  @override
  final String onboardingOfferJson;

  @override
  final bool paywallEnabled;

  @override
  final String paywallVariantKey;

  @override
  final String onboardingFlowJson;

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
