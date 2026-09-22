import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:flutter/foundation.dart';

@immutable
class ReminderLabState {
  const ReminderLabState({
    this.switches = ReminderSwitches.defaults,
    this.notificationsAllowed = true,
    this.isSelfHosted = false,
    this.timeZone = '',
    this.budgetSpentAt,
    this.proAskedAt,
    this.proDismissCount = 0,
    this.reviewAskedAt,
    this.reviewAskCount = 0,
    this.feedbackAskedAt,
    this.pending = const [],
    this.skipRules = false,
  });

  final ReminderSwitches switches;
  final bool notificationsAllowed;
  final bool isSelfHosted;
  final String timeZone;
  final DateTime? budgetSpentAt;
  final DateTime? proAskedAt;
  final int proDismissCount;
  final DateTime? reviewAskedAt;
  final int reviewAskCount;
  final DateTime? feedbackAskedAt;

  /// What the native scheduler holds right now: `pending()`.
  final List<PendingReminder> pending;
  final bool skipRules;
}
