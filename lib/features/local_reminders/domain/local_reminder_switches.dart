import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:flutter/foundation.dart';

/// The two switches on Settings > Reminders.
@immutable
final class LocalReminderSwitches {
  const LocalReminderSwitches({required this.reminders, required this.offers});

  /// From install: Reminders on, Offers off. Offers needs an explicit yes
  /// (App Store 4.5.4).
  static const LocalReminderSwitches defaults = LocalReminderSwitches(
    reminders: true,
    offers: false,
  );

  static const LocalReminderSwitches allOff = LocalReminderSwitches(
    reminders: false,
    offers: false,
  );

  /// Ideas 1, 2, 7, 8, 21 and 22.
  final bool reminders;

  /// Idea 10 and the Pro remind-later notice.
  final bool offers;

  bool allows(LocalReminderKind kind) => kind.isOffer ? offers : reminders;

  LocalReminderSwitches copyWith({bool? reminders, bool? offers}) =>
      LocalReminderSwitches(
        reminders: reminders ?? this.reminders,
        offers: offers ?? this.offers,
      );

  @override
  bool operator ==(Object other) =>
      other is LocalReminderSwitches &&
      other.reminders == reminders &&
      other.offers == offers;

  @override
  int get hashCode => Object.hash(reminders, offers);
}
