import 'package:flutter/foundation.dart';

/// What the user had typed and started during onboarding, kept between
/// launches so quitting halfway costs them nothing. Which step they are on is
/// not here: the flow engine works that out.
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.serverUrl = '',
    this.adminToken = '',
    this.isSelfHosting = false,
    this.countdownEndsAt,
  });

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
    String? serverUrl,
    String? adminToken,
    bool? isSelfHosting,
    DateTime? countdownEndsAt,
    bool clearCountdown = false,
  }) {
    return OnboardingDraft(
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
          serverUrl == other.serverUrl &&
          adminToken == other.adminToken &&
          isSelfHosting == other.isSelfHosting &&
          countdownEndsAt == other.countdownEndsAt;

  @override
  int get hashCode => Object.hash(
    serverUrl,
    adminToken,
    isSelfHosting,
    countdownEndsAt,
  );
}
