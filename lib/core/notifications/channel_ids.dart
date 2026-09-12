abstract final class ChannelIds {
  static String alarm({int version = 1}) => 'critical_alarm_v$version';
  static String status({int version = 1}) => 'incident_status_v$version';
}
