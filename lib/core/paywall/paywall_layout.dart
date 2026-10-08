/// The paywall layouts the app can draw. Each one sells either product.
///
/// The keys go in the route (`/plans/<key>`) and, later, in remote values
/// and analytics, so a shipped key never changes.
enum PaywallLayoutId {
  /// The mascot on a stage with one benefit playing beside it. It is also
  /// what an id with no layout registered falls back to, and it is listed
  /// first on the developer page.
  hero('hero'),
  sheet('sheet'),
  proof('proof'),
  bento('bento'),
  reel('reel'),
  stage('stage'),
  sentence('sentence'),
  wipe('wipe'),
  doors('doors'),
  receipt('receipt');

  const PaywallLayoutId(this.key);

  final String key;

  /// The layout [key] names, or null for a missing or unknown one. The
  /// caller decides what an unknown key shows.
  static PaywallLayoutId? fromKey(String? key) {
    for (final layout in values) {
      if (layout.key == key) return layout;
    }
    return null;
  }
}

/// The route every layout opens at. `:layout` is a [PaywallLayoutId.key].
const String paywallLayoutPath = '/plans/:layout';

/// The path that opens the layout [layoutKey] names.
String paywallLayoutPathFor(String layoutKey) => '/plans/$layoutKey';
