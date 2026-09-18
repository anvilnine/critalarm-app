/// Remembers whether this device has been through the "How to use the app"
/// tour, so it plays once on its own and after that only when asked.
abstract interface class TourRepository {
  bool hasSeenTour();
  Future<void> markTourSeen();
}
