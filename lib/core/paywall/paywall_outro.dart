/// What can play between a confirmed purchase and the step after it. It is
/// the fourth value of a paywall, beside the layout, the intro and the
/// thanks: any one goes with any layout and any thanks, for either product.
///
/// The keys go in the route (`?outro=<key>`), in remote values and in
/// analytics, so a shipped key never changes.
enum PaywallOutroId {
  /// Nothing of its own: a purchase goes straight to the thanks.
  none('none'),

  /// The paywall breaks, Crit lifts off and rings out in the sky.
  breakLiftRing('break_lift_ring'),

  /// A cloud floats Crit up to the moon.
  cloudClimb('cloud_climb');

  const PaywallOutroId(this.key);

  final String key;

  /// The one [key] names, or null for a missing or unknown key.
  static PaywallOutroId? fromKey(String? key) {
    for (final outro in values) {
      if (outro.key == key) return outro;
    }
    return null;
  }

  /// Reads a remote value or a route's `outro`. Empty means [none], and so
  /// does a value this build does not know.
  static PaywallOutroId parse(String? value) => fromKey(value?.trim()) ?? none;
}
