/// Every local reminder the app can plan. The numbers in the comments are
/// the idea numbers from the spec.
enum ReminderKind {
  /// 1 (with 20 folded in).
  fireDrill('fire_drill'),

  /// 2.
  silentTopic('silent_topic'),

  /// 7.
  backup('backup'),

  /// 8.
  planHeadsUp('plan_heads_up'),

  /// 10.
  morningAfter('morning_after'),

  /// The Pro sheet's "Remind me later", coming back as a notification.
  proLater('pro_later'),

  /// 21.
  reviewAsk('review_ask'),

  /// 22.
  feedbackAsk('feedback_ask');

  const ReminderKind(this.wireName);

  /// The name the native side and the notification payload use.
  final String wireName;

  static ReminderKind? fromWire(String? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }

  /// Offers follow the Offers switch. Everything else follows Reminders.
  bool get isOffer =>
      this == ReminderKind.morningAfter || this == ReminderKind.proLater;

  /// Shares the one-per-week slot. Plan heads-up is about money and the Pro
  /// notice has its own 30 day wait, so neither does.
  bool get usesBudget =>
      this != ReminderKind.planHeadsUp && this != ReminderKind.proLater;

  /// Lower wins the weekly slot: 1 > 10 > 2 > 7 > 21 > 22.
  int get priority => switch (this) {
    ReminderKind.fireDrill => 0,
    ReminderKind.morningAfter => 1,
    ReminderKind.silentTopic => 2,
    ReminderKind.backup => 3,
    ReminderKind.reviewAsk => 4,
    ReminderKind.feedbackAsk => 5,
    ReminderKind.planHeadsUp => 6,
    ReminderKind.proLater => 7,
  };

  /// Crit's face on the notification (idea 15). Never an alarmed face: a
  /// reminder must not look like an alarm.
  ReminderFace get face => switch (this) {
    ReminderKind.fireDrill => ReminderFace.curious,
    ReminderKind.silentTopic => ReminderFace.concerned,
    ReminderKind.backup => ReminderFace.thinking,
    ReminderKind.planHeadsUp => ReminderFace.calm,
    ReminderKind.morningAfter => ReminderFace.laughing,
    ReminderKind.proLater => ReminderFace.laughing,
    ReminderKind.reviewAsk => ReminderFace.happy,
    ReminderKind.feedbackAsk => ReminderFace.watching,
  };

  /// The iOS notification category. Every one starts with `reminder_`, which
  /// is how `AppDelegate.swift` tells a reminder from an incident.
  String get categoryId => 'reminder_$wireName';
}

/// The face images under `assets/reminder_faces/`. Each name matches a
/// `FaceState` so the image can be drawn from the same painter.
enum ReminderFace {
  curious,
  concerned,
  thinking,
  calm,
  laughing,
  happy,
  watching;

  String get assetPath => 'assets/reminder_faces/$name.png';
}
