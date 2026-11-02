/// The store's own "rate this app" popup.
abstract interface class StoreReview {
  /// Whether the store can show its popup on this device now. A yes does
  /// not mean it will: the store decides that and never says.
  Future<bool> isAvailable();

  /// Asks the store to show its popup.
  Future<void> request();
}
