import 'package:critalarm/gen/locale_keys.g.dart';

/// The long-press actions on the app icon (idea 17).
enum QuickActionType {
  ringMeNow('ring_me_now', '/ring', LocaleKeys.reminders_quick_ring),
  openIncidents(
    'open_incidents',
    '/history',
    LocaleKeys.reminders_quick_incidents,
  ),
  newTopic('new_topic', '/topics/new', LocaleKeys.reminders_quick_new_topic);

  const QuickActionType(this.wire, this.path, this.titleKey);

  final String wire;

  /// "Ring me now" opens the confirm screen, never a ring.
  final String path;
  final String titleKey;

  static QuickActionType? fromWire(String type) {
    for (final action in values) {
      if (action.wire == type) return action;
    }
    return null;
  }
}

abstract final class QuickActionItems {
  static List<QuickActionType> visible({required bool hasCriticalTopic}) => [
    if (hasCriticalTopic) QuickActionType.ringMeNow,
    QuickActionType.openIncidents,
    QuickActionType.newTopic,
  ];
}
