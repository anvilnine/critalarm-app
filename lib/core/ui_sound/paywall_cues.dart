/// The short sounds a paywall layout asks for. The kit calls them at fixed
/// moments, so every layout sounds the same without playing anything itself.
///
/// None of these is an alarm. The app never makes one: an alarm comes from
/// the server.
abstract interface class PaywallCues {
  /// The paywall came on screen.
  void open();

  /// An entrance that plays a joke before the pitch.
  void gag();

  /// An entrance that prints, such as a till receipt.
  void print();

  /// One small step inside a layout's own motion.
  void tick();

  /// A plan was picked. [yearly] says which, so the two can differ.
  void pickPlan({required bool yearly});

  /// The purchase is confirmed.
  void bought();

  /// The paywall was closed without buying.
  void close();
}

/// Which cue the frame plays when a layout appears.
enum PaywallEntranceCue { open, gag, print, none }

/// Plays nothing. What every build is wired with until a playing one exists.
final class SilentPaywallCues implements PaywallCues {
  const SilentPaywallCues();

  @override
  void open() {}

  @override
  void gag() {}

  @override
  void print() {}

  @override
  void tick() {}

  @override
  void pickPlan({required bool yearly}) {}

  @override
  void bought() {}

  @override
  void close() {}
}
