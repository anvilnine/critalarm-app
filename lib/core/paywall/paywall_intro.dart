/// The short animations that can play before a paywall layout. An intro is
/// not a layout: it plays once, full screen, and hands over to whichever
/// layout was chosen. Any intro goes with any layout.
///
/// The keys go in the route (`?intro=<key>`), in remote values and in
/// analytics, so a shipped key never changes.
enum PaywallIntroId {
  /// No intro: the layout opens with its own entrance.
  none('none'),

  /// The screen looks like an alarm for a second, then admits it is not.
  falseAlarm('false_alarm'),

  /// A finger goes for a Snooze button and the mascot eats the button.
  snooze('snooze'),

  /// The mascot is asleep and a message drops on its head.
  wakeUp('wake_up'),

  /// The mascot peeks out of a curtain, then throws it open.
  curtain('curtain'),

  /// The screen looks like an alarm with a Snooze button, the button dodges
  /// a finger, and the mascot eats it: the ringing stops.
  alarmSnack('alarm_snack');

  const PaywallIntroId(this.key);

  final String key;

  /// The intro [key] names, or null for a missing or unknown one.
  static PaywallIntroId? fromKey(String? key) {
    for (final intro in values) {
      if (intro.key == key) return intro;
    }
    return null;
  }

  /// Reads a remote value or a route's `intro`. Empty means [none], and so
  /// does a value this build does not know. That covers the key of an intro
  /// that was taken out, such as `countdown`: it plays nothing.
  static PaywallIntroId parse(String? value) => fromKey(value?.trim()) ?? none;
}

/// The layout key the false alarm had while it was a layout. A stored or
/// remote layout value that still says it reads as the `hero` layout with
/// the [PaywallIntroId.falseAlarm] intro.
const String paywallFalseAlarmLayoutKey = 'false_alarm';

/// The intro a layout value carries from the time intros were layouts, or
/// null when it carries none.
PaywallIntroId? paywallIntroInLayoutValue(String? layoutValue) =>
    layoutValue?.trim() == paywallFalseAlarmLayoutKey
    ? PaywallIntroId.falseAlarm
    : null;
