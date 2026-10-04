/// How setup hears that an alarm reached this phone.
///
/// The same sources the app opens the alarm screen from: a push the phone
/// received, an alarm the phone set for one, a tapped alarm notification.
/// Nothing here asks the server, because the server knowing about an
/// incident says nothing about whether this phone rang.
abstract interface class AlarmArrivals {
  /// The incident id of every alarm that reaches this phone, as it happens.
  Stream<String> get incidentIds;

  /// Whether an alarm for [incidentId] is up on this phone right now. A
  /// local read, for the moment the app comes back to the front or starts
  /// from cold and may have missed the event.
  Future<bool> isUp(String incidentId);
}
