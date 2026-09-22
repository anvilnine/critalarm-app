/// The four Android notification channels, one per delivery class.
///
/// Channel settings freeze the moment a channel is created, so the only way to
/// change one is to create a new channel. Every id carries a version for that.
/// Keep these in step with `NotificationChannels.kt`.
abstract final class ChannelIds {
  /// Priority 1-3 (api.md §1.7). Quiet, no sound.
  static String standard({int version = 1}) => 'message_standard_v$version';

  /// Priority 4, and priority 5 on a topic that is not critical. Heads-up with
  /// a sound, but never the alarm.
  static String high({int version = 1}) => 'message_high_v$version';

  /// Priority 5 on a critical topic. Full-screen intent, alarm sound.
  static String alarm({int version = 1}) => 'critical_alarm_v$version';

  /// The ongoing card that stays up while an incident is open.
  static String card({int version = 1}) => 'incident_status_v$version';

  /// Former name for [card].
  static String status({int version = 1}) => card(version: version);

  /// Local reminders (fire drill, silent topic, backup, plan heads-up,
  /// review and feedback asks). Not in [all]: the alarm health check never
  /// looks at them. Keep in step with `NotificationChannels.kt`.
  static const String reminders = 'reminders_v1';

  /// Local Pro offers (morning after, Pro remind-later). Not in [all].
  static const String offers = 'offers_v1';

  static List<String> all({int version = 1}) => [
    standard(version: version),
    high(version: version),
    alarm(version: version),
    card(version: version),
  ];
}
