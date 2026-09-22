import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:flutter/foundation.dart';

/// The two switches on Settings > Reminders.
@immutable
final class ReminderSwitches {
  const ReminderSwitches({required this.reminders, required this.offers});

  /// From install: Reminders on, Offers off. Offers needs an explicit yes
  /// (App Store 4.5.4).
  static const ReminderSwitches defaults = ReminderSwitches(
    reminders: true,
    offers: false,
  );

  static const ReminderSwitches allOff = ReminderSwitches(
    reminders: false,
    offers: false,
  );

  /// Ideas 1, 2, 7, 8, 21 and 22.
  final bool reminders;

  /// Idea 10 and the Pro remind-later notice.
  final bool offers;

  bool allows(ReminderKind kind) => kind.isOffer ? offers : reminders;

  ReminderSwitches copyWith({bool? reminders, bool? offers}) =>
      ReminderSwitches(
        reminders: reminders ?? this.reminders,
        offers: offers ?? this.offers,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSwitches &&
      other.reminders == reminders &&
      other.offers == offers;

  @override
  int get hashCode => Object.hash(reminders, offers);
}
