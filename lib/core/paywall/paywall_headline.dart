/// Which words a layout puts on a paywall that is about a plan ending or
/// ended. Most paywalls have none and the layout uses its own.
///
/// The keys go in the route (`?headline=<key>`), so a shipped key never
/// changes.
enum PaywallHeadlineVariant {
  /// The layout's own words.
  none('none'),

  /// The plan is cancelled and still running.
  leaving('leaving'),

  /// The plan has ended.
  ended('ended');

  const PaywallHeadlineVariant(this.key);

  final String key;

  /// The variant [value] names. A missing or unknown value is [none].
  static PaywallHeadlineVariant parse(String? value) {
    for (final variant in values) {
      if (variant.key == value) return variant;
    }
    return none;
  }
}
