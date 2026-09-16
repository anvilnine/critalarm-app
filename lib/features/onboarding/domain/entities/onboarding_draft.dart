import 'package:flutter/foundation.dart';

/// Which onboarding screen the user had reached.
enum OnboardingStep {
  /// Notification permission, and on iOS 26 the alarm permission after it.
  permissions,

  /// Pick Crit Alarm Cloud or your own server.
  connect,

  /// Connected, ready to run the test alarm.
  test;

  static OnboardingStep fromName(String? name) =>
      OnboardingStep.values.firstWhere(
        (step) => step.name == name,
        orElse: () => OnboardingStep.permissions,
      );

  String get route => switch (this) {
    OnboardingStep.permissions => '/onboarding',
    OnboardingStep.connect || OnboardingStep.test => '/onboarding/connect',
  };
}

/// What onboarding remembers between launches, so quitting halfway costs the
/// user nothing but the tap that got them there.
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.step = OnboardingStep.permissions,
    this.serverUrl = '',
    this.adminToken = '',
    this.isSelfHosting = false,
    this.countdownEndsAt,
  });

  final OnboardingStep step;

  /// The half-typed self-hosted form. Kept so a user who quits to read their
  /// server logs does not come back to an empty box.
  final String serverUrl;
  final String adminToken;
  final bool isSelfHosting;

  /// When the test alarm is due to ring. The alarm itself is held by the OS,
  /// so this is only what the countdown reads to know how long is left.
  final DateTime? countdownEndsAt;

  /// Seconds still to run, or null when no test is pending. Zero once the
  /// alarm is due, which is how a relaunch mid-countdown catches up.
  int? get secondsLeft {
    final endsAt = countdownEndsAt;
    if (endsAt == null) return null;
    final left = endsAt.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  OnboardingDraft copyWith({
    OnboardingStep? step,
    String? serverUrl,
    String? adminToken,
    bool? isSelfHosting,
    DateTime? countdownEndsAt,
    bool clearCountdown = false,
  }) {
    return OnboardingDraft(
      step: step ?? this.step,
      serverUrl: serverUrl ?? this.serverUrl,
      adminToken: adminToken ?? this.adminToken,
      isSelfHosting: isSelfHosting ?? this.isSelfHosting,
      countdownEndsAt: clearCountdown
          ? null
          : (countdownEndsAt ?? this.countdownEndsAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingDraft &&
          step == other.step &&
          serverUrl == other.serverUrl &&
          adminToken == other.adminToken &&
          isSelfHosting == other.isSelfHosting &&
          countdownEndsAt == other.countdownEndsAt;

  @override
  int get hashCode => Object.hash(
    step,
    serverUrl,
    adminToken,
    isSelfHosting,
    countdownEndsAt,
  );
}
