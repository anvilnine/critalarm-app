import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:flutter/foundation.dart';

@immutable
class LocalReminderSettingsState {
  const LocalReminderSettingsState({
    this.switches = LocalReminderSwitches.defaults,
    this.notificationsAllowed = true,
    this.isSelfHosted = false,
    this.isPaid = false,
    this.isLoaded = false,
  });

  final LocalReminderSwitches switches;

  /// False when the OS has notifications off for the app. The screen then
  /// says so, so the switches never promise something the phone blocks.
  final bool notificationsAllowed;

  /// Hides the Offers switch: there is no Pro on a self-hosted server.
  final bool isSelfHosted;

  /// Hides the Offers switch: Pro offers mean nothing to someone with Pro.
  final bool isPaid;
  final bool isLoaded;

  /// Whether the "News about Pro" switch shows at all.
  bool get showsOffers => !isSelfHosted && !isPaid;

  LocalReminderSettingsState copyWith({
    LocalReminderSwitches? switches,
    bool? notificationsAllowed,
    bool? isSelfHosted,
    bool? isPaid,
    bool? isLoaded,
  }) => LocalReminderSettingsState(
    switches: switches ?? this.switches,
    notificationsAllowed: notificationsAllowed ?? this.notificationsAllowed,
    isSelfHosted: isSelfHosted ?? this.isSelfHosted,
    isPaid: isPaid ?? this.isPaid,
    isLoaded: isLoaded ?? this.isLoaded,
  );

  @override
  bool operator ==(Object other) =>
      other is LocalReminderSettingsState &&
      other.switches == switches &&
      other.notificationsAllowed == notificationsAllowed &&
      other.isSelfHosted == isSelfHosted &&
      other.isPaid == isPaid &&
      other.isLoaded == isLoaded;

  @override
  int get hashCode => Object.hash(
    switches,
    notificationsAllowed,
    isSelfHosted,
    isPaid,
    isLoaded,
  );
}
