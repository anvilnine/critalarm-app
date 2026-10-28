/// Pages of this app inside the store app.
// ignore: one_member_abstracts
abstract interface class StoreLinks {
  /// Opens this app's listing, where a person can rate it or update it.
  Future<void> listing();
}
