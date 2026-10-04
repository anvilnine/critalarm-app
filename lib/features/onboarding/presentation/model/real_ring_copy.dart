import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// The words of the real ring step that differ by phone: the three
/// instruction lines and the list of things to check when no ring came.
///
/// Each phone has its own keys. A line that reads the same on two phones
/// today is still two keys, so one can change without the other.
@immutable
class RealRingCopy {
  const RealRingCopy({required this.steps, required this.checks});

  /// Silence the phone, tap, lock the screen. In order.
  final List<String> steps;

  /// What to look at when the server sent the alarm and the phone stayed
  /// quiet. Text only: none of these opens a sheet or asks for anything.
  final List<String> checks;
}

RealRingCopy realRingCopyFor(RealRingPlatform platform) => switch (platform) {
  RealRingPlatform.iosAlarm => _iosAlarm(),
  RealRingPlatform.iosTimeSensitive => _iosTimeSensitive(),
  RealRingPlatform.android => _android(),
};

/// iOS 26 or later. The push becomes an AlarmKit alarm.
RealRingCopy _iosAlarm() => RealRingCopy(
  steps: [
    LocaleKeys.onboarding_real_ring_ios_step_silence.tr(),
    LocaleKeys.onboarding_real_ring_ios_step_tap.tr(),
    LocaleKeys.onboarding_real_ring_ios_step_lock.tr(),
  ],
  checks: [
    LocaleKeys.onboarding_real_ring_ios_check_notifications.tr(),
    LocaleKeys.onboarding_real_ring_ios_check_alarms.tr(),
    LocaleKeys.onboarding_real_ring_ios_check_online.tr(),
  ],
);

/// iOS 16 to 25. A Time-Sensitive notification with sound, which the silent
/// switch mutes. No line here promises a ring through silent mode.
RealRingCopy _iosTimeSensitive() => RealRingCopy(
  steps: [
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_step_ringer.tr(),
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_step_tap.tr(),
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_step_lock.tr(),
  ],
  checks: [
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_check_notifications.tr(),
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_check_time_sensitive
        .tr(),
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_check_focus.tr(),
    LocaleKeys.onboarding_real_ring_ios_time_sensitive_check_online.tr(),
  ],
);

/// Android. The push arrives over FCM and opens the full-screen alarm.
RealRingCopy _android() => RealRingCopy(
  steps: [
    LocaleKeys.onboarding_real_ring_android_step_silence.tr(),
    LocaleKeys.onboarding_real_ring_android_step_tap.tr(),
    LocaleKeys.onboarding_real_ring_android_step_lock.tr(),
  ],
  checks: [
    LocaleKeys.onboarding_real_ring_android_check_notifications.tr(),
    LocaleKeys.onboarding_real_ring_android_check_full_screen.tr(),
    LocaleKeys.onboarding_real_ring_android_check_battery.tr(),
    LocaleKeys.onboarding_real_ring_android_check_online.tr(),
  ],
);

/// The line under the title. The words about silent mode come from [claim].
String realRingSubtitle(RingClaim claim) => switch (claim) {
  RingClaim.alarm => LocaleKeys.onboarding_real_ring_subtitle.tr(),
  RingClaim.timeSensitive =>
    LocaleKeys.onboarding_real_ring_subtitle_time_sensitive.tr(),
};

/// A problem said in a short title and, where the title is not enough, one
/// plain line under it.
typedef RealRingReason = ({String title, String? line});

/// No server is connected.
RealRingReason realRingNoServerReason() => (
  title: LocaleKeys.onboarding_real_ring_no_server.tr(),
  line: LocaleKeys.onboarding_real_ring_no_server_line.tr(),
);

/// The server has no topic to ring.
RealRingReason realRingNoTopicReason() => (
  title: LocaleKeys.onboarding_real_ring_no_topic.tr(),
  line: LocaleKeys.onboarding_real_ring_no_topic_line.tr(),
);

/// Why the server did not take the test.
RealRingReason realRingFailureLine(RealRingFailure failure) =>
    switch (failure) {
      RealRingFailure.offline => (
        title: LocaleKeys.onboarding_real_ring_failed_offline.tr(),
        line: null,
      ),
      RealRingFailure.slow => (
        title: LocaleKeys.onboarding_real_ring_failed_slow.tr(),
        line: null,
      ),
      RealRingFailure.signedOut => (
        title: LocaleKeys.onboarding_real_ring_failed_signed_out.tr(),
        line: LocaleKeys.onboarding_real_ring_failed_signed_out_line.tr(),
      ),
      RealRingFailure.topicGone => (
        title: LocaleKeys.onboarding_real_ring_failed_topic_gone.tr(),
        line: null,
      ),
      RealRingFailure.rateLimited => (
        title: LocaleKeys.onboarding_real_ring_failed_rate_limited.tr(),
        line: LocaleKeys.onboarding_real_ring_failed_rate_limited_line.tr(),
      ),
      RealRingFailure.serverDown => (
        title: LocaleKeys.onboarding_real_ring_failed_server_down.tr(),
        line: null,
      ),
      RealRingFailure.unknown => (
        title: LocaleKeys.onboarding_real_ring_failed_unknown.tr(),
        line: null,
      ),
    };
