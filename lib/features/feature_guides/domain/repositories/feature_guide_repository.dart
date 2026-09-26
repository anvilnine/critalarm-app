/// Remembers which Feature Guides this device has been through,
/// so each plays once on its own and after that only when asked.
///
/// Guides are named by string, so the domain does not depend on the
/// presentation's `FeatureGuide` enum. The cubit passes `FeatureGuide.name`.
abstract interface class FeatureGuideRepository {
  bool hasSeenGuide(String guide);
  Future<void> markGuidesSeen(Iterable<String> guides);
}
