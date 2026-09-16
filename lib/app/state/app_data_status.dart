/// Whether an app-level cubit has a list worth drawing.
///
/// Fetching is not part of this. A refresh keeps whatever was already loaded
/// and says so through `isRefreshing`, so a screen never has to blank a list
/// it is already showing.
enum AppDataStatus {
  /// Nothing has been fetched yet.
  initial,

  /// The list came back from the server at least once.
  ready,

  /// The last fetch failed. Anything loaded before it is still in the state.
  failure,
}
