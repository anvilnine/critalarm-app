/// Every local reminder the app can plan. The numbers in the comments are
/// the idea numbers from the spec.
enum LocalReminderKind {
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

  const LocalReminderKind(this.wireName);

  /// The name the native side and the notification payload use.
  final String wireName;

  static LocalReminderKind? fromWire(String? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }

  /// Offers follow the Offers switch. Everything else follows Reminders.
  bool get isOffer =>
      this == LocalReminderKind.morningAfter ||
      this == LocalReminderKind.proLater;

  /// Shares the one-per-week slot. Plan heads-up is about money and the Pro
  /// notice has its own 30 day wait, so neither does.
  bool get usesBudget =>
      this != LocalReminderKind.planHeadsUp &&
      this != LocalReminderKind.proLater;

  /// Lower wins the weekly slot: 1 > 10 > 2 > 7 > 21 > 22.
  int get priority => switch (this) {
    LocalReminderKind.fireDrill => 0,
    LocalReminderKind.morningAfter => 1,
    LocalReminderKind.silentTopic => 2,
    LocalReminderKind.backup => 3,
    LocalReminderKind.reviewAsk => 4,
    LocalReminderKind.feedbackAsk => 5,
    LocalReminderKind.planHeadsUp => 6,
    LocalReminderKind.proLater => 7,
  };

  /// Crit's face on the notification (idea 15). Never an alarmed face: a
  /// reminder must not look like an alarm.
  LocalReminderFace get face => switch (this) {
    LocalReminderKind.fireDrill => LocalReminderFace.curious,
    LocalReminderKind.silentTopic => LocalReminderFace.concerned,
    LocalReminderKind.backup => LocalReminderFace.thinking,
    LocalReminderKind.planHeadsUp => LocalReminderFace.calm,
    LocalReminderKind.morningAfter => LocalReminderFace.laughing,
    LocalReminderKind.proLater => LocalReminderFace.laughing,
    LocalReminderKind.reviewAsk => LocalReminderFace.happy,
    LocalReminderKind.feedbackAsk => LocalReminderFace.watching,
  };

  /// The iOS notification category. Every one starts with `reminder_`, which
  /// is how `AppDelegate.swift` tells a reminder from an incident.
  String get categoryId => 'reminder_$wireName';
}

/// The face images under `assets/reminder_faces/`. Each name matches a
/// `FaceState` so the image can be drawn from the same painter.
enum LocalReminderFace {
  curious,
  concerned,
  thinking,
  calm,
  laughing,
  happy,
  watching;

  String get assetPath => 'assets/reminder_faces/$name.png';
}
