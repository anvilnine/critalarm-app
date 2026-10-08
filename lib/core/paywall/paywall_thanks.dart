/// What can play after a purchase is confirmed on a paywall layout. It is
/// the third step of a paywall, beside the intro and the layout: any one
/// goes with any layout, for either product.
///
/// The keys go in the route (`?thanks=<key>`), in remote values and in
/// analytics, so a shipped key never changes.
enum PaywallThanksId {
  /// Nothing of its own: the purchase ends as it did before there was a
  /// third step.
  none('none'),

  /// The button bursts, confetti falls and settles, and the mascot jumps
  /// with a crown on.
  confetti('confetti'),

  /// A padlock on every line opens, one after another, and the mascot is
  /// glad of each.
  unlock('unlock'),

  /// A slip prints from the button, a rubber stamp with the product's
  /// name lands on it, and the mascot holds it up.
  stamp('stamp'),

  /// The free plan's limits stand at their caps, each one is lifted, and
  /// the mascot grows a size.
  limits('limits');

  const PaywallThanksId(this.key);

  final String key;

  /// The one [key] names, or null for a missing or unknown key.
  static PaywallThanksId? fromKey(String? key) {
    for (final thanks in values) {
      if (thanks.key == key) return thanks;
    }
    return null;
  }

  /// Reads a remote value or a route's `thanks`. Empty means [none], and so
  /// does a value this build does not know.
  static PaywallThanksId parse(String? value) => fromKey(value?.trim()) ?? none;
}
