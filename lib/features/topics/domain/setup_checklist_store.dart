/// What the setup checklist and the widgets card on Home remember.
///
/// Each flag is set once and never cleared: neither one comes back after
/// the user has seen it through, whatever they delete later.
abstract interface class SetupChecklistStore {
  /// The first look at this phone's own data has been taken, so an install
  /// from before the checklist is never asked to set up again.
  bool get isSeeded;

  Future<void> markSeeded();

  /// The checklist finished, or was never needed. It does not show again,
  /// and the celebration cannot play again.
  bool get isDone;

  Future<void> markDone();

  /// The user opened the widgets how-to or dismissed the card.
  bool get isWidgetsCardSeen;

  Future<void> markWidgetsCardSeen();
}
