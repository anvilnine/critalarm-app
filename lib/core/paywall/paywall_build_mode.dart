// Set with --dart-define=SKIP_PAYWALL=true to run a release build without
// RevenueCat. The app wires the in-memory subscription repository instead, so
// a test API key cannot pop the "Wrong API Key" dialog that closes the app.
// Defaults to false, so shipping builds always talk to RevenueCat.
const buildSkipsPaywall = bool.fromEnvironment('SKIP_PAYWALL');

// Set with --dart-define=PAYWALL_LAB=true to get the variant picker in
// Settings, so one build can show every paywall layout without waiting on a
// Remote Config fetch. Defaults to false, so a shipping build takes its
// variant from Remote Config and nothing else.
const buildHasPaywallLab = bool.fromEnvironment('PAYWALL_LAB');

/// Whether a build is about to ship with no way to take money.
///
/// A release build with an empty RevenueCat key never configures the SDK, so
/// there is no paywall and nothing to buy, and that looks exactly like a
/// working build nobody has bought from yet. [buildSkipsPaywall] is the one
/// way to mean it: a `--dart-define=SKIP_PAYWALL=true` build wires the
/// in-memory repository on purpose. Kept out of the composition root so a
/// test can check the three inputs without a release build.
bool releaseBuildCannotSell({
  required bool isRelease,
  required bool skipsPaywall,
  required String apiKey,
}) => isRelease && !skipsPaywall && apiKey.isEmpty;
