/// The two things a paywall layout can sell.
///
/// Hosted is the subscription that raises limits. Pro is the pack that adds
/// features. Every layout draws both.
enum PaywallProduct {
  hosted('hosted'),
  pro('pro');

  const PaywallProduct(this.key);

  /// The stable name used in the route (`?product=`) and in file names.
  final String key;

  /// The product [key] names. A missing or unknown key reads as [hosted].
  static PaywallProduct parse(String? key) {
    for (final product in values) {
      if (product.key == key) return product;
    }
    return hosted;
  }
}
