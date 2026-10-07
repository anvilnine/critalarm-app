/// How one reliability check stands.
enum ReliabilityState {
  /// Nothing to do.
  fine,

  /// Might not ring. Worth a look, nothing is known to be broken.
  needsLook,

  /// Known not to work, or known to have stopped working.
  broken,

  /// The check has no meaning on this phone (an Android-only setting on an
  /// iPhone, a push check with no server). It is left out of the list and out
  /// of the overall state.
  notOnThisPhone;

  /// False only for [notOnThisPhone].
  bool get isOnThisPhone => this != notOnThisPhone;
}
