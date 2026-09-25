/// Remembers which "How to use the app" guides this device has been through,
/// so each plays once on its own and after that only when asked.
///
/// Guides are named by string, so the domain does not depend on the
/// presentation's `TourGuide` enum. The cubit passes `TourGuide.name`.
abstract interface class TourRepository {
  bool hasSeenGuide(String guide);
  Future<void> markGuidesSeen(Iterable<String> guides);
}
