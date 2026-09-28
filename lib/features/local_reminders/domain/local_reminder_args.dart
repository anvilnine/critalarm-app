/// Keys in a reminder's args and payload. The copy reads them to fill in its
/// words; a tap reads them to know where to go.
abstract final class LocalReminderArgs {
  static const String kind = 'kind';
  static const String id = 'id';
  static const String topic = 'topic';
  static const String days = 'days';
  static const String count = 'count';
  static const String date = 'date';
  static const String price = 'price';
  static const String weekday = 'weekday';
  static const String time = 'time';
  static const String seconds = 'seconds';
  static const String incidentId = 'incident_id';
  static const String headsUp = 'notice';
  static const String url = 'url';
  static const String pool = 'pool';
}
