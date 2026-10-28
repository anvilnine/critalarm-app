// Off unless asked for. The Makefile passes --dart-define=NO_TELEMETRY=true
// to the release builds it makes for a desk (run-store, build-store-apk,
// build-store-appbundle), which are built like a store build but never go to
// a store. The release scripts never pass it.
const buildBlocksTelemetry = bool.fromEnvironment('NO_TELEMETRY');

/// Whether this run may send analytics and crash reports at all.
///
/// A yes still waits for the user's own switch in Settings > Privacy. A no
/// means the user's switch can never turn them on in this run. The answer is
/// no for:
///
/// - a debug or profile build ([isRelease] false);
/// - a release build made for a desk: an in-memory server ([usesMockApi]),
///   no RevenueCat ([skipsPaywall]), the paywall pickers ([hasPaywallLab]),
///   a quiet ring ([usesQuietAlarm]) or `NO_TELEMETRY` ([blocksTelemetry]);
/// - a web page served from anywhere but the production host
///   ([isProductionWebPage]). [webPage] is the page's address on web and
///   null on a phone.
///
/// The store builds that `scripts/release-ios.sh` and
/// `scripts/release-android.sh` make pass none of those flags, so they answer
/// yes.
bool telemetryAllowedFor({
  required bool isRelease,
  required bool usesMockApi,
  required bool skipsPaywall,
  required bool hasPaywallLab,
  required bool usesQuietAlarm,
  required bool blocksTelemetry,
  required Uri? webPage,
}) {
  if (!isRelease) return false;
  if (usesMockApi || skipsPaywall || hasPaywallLab || usesQuietAlarm) {
    return false;
  }
  if (blocksTelemetry) return false;
  if (webPage != null && !isProductionWebPage(webPage)) return false;
  return true;
}

/// Whether a web page is the production app: https on `critalarm.app` or
/// one of its subdomains, where the dashboard will live. A page on
/// localhost, a LAN address or a preview host is not.
bool isProductionWebPage(Uri page) {
  if (page.scheme != 'https') return false;
  final host = page.host.toLowerCase();
  // Any subdomain counts only because the dashboard host is not chosen yet.
  // Once it is, this must become an allowlist of the exact hosts.
  return host == 'critalarm.app' || host.endsWith('.critalarm.app');
}
