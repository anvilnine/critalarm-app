import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:flutter/foundation.dart';

@immutable
class ReminderSettingsState {
  const ReminderSettingsState({
    this.switches = ReminderSwitches.defaults,
    this.notificationsAllowed = true,
    this.isSelfHosted = false,
    this.isLoaded = false,
  });

  final ReminderSwitches switches;

  /// False when the OS has notifications off for the app. The screen then
  /// says so, so the switches never promise something the phone blocks.
  final bool notificationsAllowed;

  /// Hides the Offers switch: there is no Pro on a self-hosted server.
  final bool isSelfHosted;
  final bool isLoaded;

  ReminderSettingsState copyWith({
    ReminderSwitches? switches,
    bool? notificationsAllowed,
    bool? isSelfHosted,
    bool? isLoaded,
  }) => ReminderSettingsState(
    switches: switches ?? this.switches,
    notificationsAllowed: notificationsAllowed ?? this.notificationsAllowed,
    isSelfHosted: isSelfHosted ?? this.isSelfHosted,
    isLoaded: isLoaded ?? this.isLoaded,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettingsState &&
      other.switches == switches &&
      other.notificationsAllowed == notificationsAllowed &&
      other.isSelfHosted == isSelfHosted &&
      other.isLoaded == isLoaded;

  @override
  int get hashCode =>
      Object.hash(switches, notificationsAllowed, isSelfHosted, isLoaded);
}
