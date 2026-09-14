// Set with --dart-define=SKIP_PAYWALL=true to run a release build without
// RevenueCat. The app wires the in-memory subscription repository instead, so
// a test API key cannot pop the "Wrong API Key" dialog that closes the app.
// Defaults to false, so shipping builds always talk to RevenueCat.
const buildSkipsPaywall = bool.fromEnvironment('SKIP_PAYWALL');
