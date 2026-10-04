import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:flutter/foundation.dart';

/// How long the phone gets to ring after the server took the test, before
/// the screen says what to check.
const Duration realRingPushWait = Duration(seconds: 20);

/// What stands between the user and a test alarm sent by the server.
enum RealRingGate {
  /// No server is connected, so nothing can ring this phone from outside.
  noServer,

  /// A server is connected and it holds no topic to ring.
  noTopic,

  /// The topic has Critical delivery off. The server would refuse the test,
  /// so it is never asked.
  criticalOff,

  /// The server can be asked.
  ready,
}

/// Decides what the real ring step shows before any call is made.
///
/// Checked when the step opens and again on every tap. Nothing here talks to
/// the server.
RealRingGate realRingGateFor({
  required bool hasConnection,
  required BackgroundConnectState connect,
  required Topic? topic,
}) {
  if (!hasConnection || connect.isPending || connect.isFailed) {
    return RealRingGate.noServer;
  }
  if (topic == null) return RealRingGate.noTopic;
  if (!topic.critical) return RealRingGate.criticalOff;
  return RealRingGate.ready;
}

/// The topic the setup test rings.
///
/// [heldName] is the topic setup just made, [savedName] the same name read
/// back after the app was killed. With neither, or with a name the list no
/// longer has, it is the first topic on the server.
Topic? setupTestTopic({
  required String? heldName,
  required String? savedName,
  required List<Topic> topics,
}) {
  for (final name in [heldName, savedName]) {
    if (name == null) continue;
    for (final topic in topics) {
      if (topic.name == name) return topic;
    }
  }
  return topics.isEmpty ? null : topics.first;
}

/// Whether the server refused the test because the topic is not critical.
/// The screen checks first and never asks, so this only happens when the
/// switch was turned off somewhere else in between.
bool isCriticalOffAnswer(Failure failure) =>
    failure is ConflictFailure ||
    (failure is ApiFailure && failure.statusCode == 409);

/// Why the server did not take the test. Each one has its own line.
enum RealRingFailure {
  /// The phone has no route to the server.
  offline,

  /// The server did not answer in time.
  slow,

  /// The server no longer accepts this phone's credential.
  signedOut,

  /// The topic is not on the server any more.
  topicGone,

  /// Too many requests in a short time.
  rateLimited,

  /// The server answered an error of its own.
  serverDown,

  /// Anything else.
  unknown,
}

/// Maps the failure of the test call to a reason the screen has words for.
/// No server text and no exception text ever reaches the screen.
RealRingFailure realRingFailureFor(Failure failure) {
  if (failure is UnauthorizedFailure) return RealRingFailure.signedOut;
  if (failure is NotFoundFailure) return RealRingFailure.topicGone;
  if (failure is ApiFailure) {
    return switch (failure.statusCode) {
      401 || 403 => RealRingFailure.signedOut,
      404 => RealRingFailure.topicGone,
      429 => RealRingFailure.rateLimited,
      >= 500 => RealRingFailure.serverDown,
      _ => RealRingFailure.unknown,
    };
  }
  final text = failure.message ?? '';
  if (text.contains('TimeoutException')) return RealRingFailure.slow;
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection closed') ||
      text.contains('Network is unreachable') ||
      text.contains('Network is down') ||
      text.contains('No route to host')) {
    return RealRingFailure.offline;
  }
  if (text.contains('No API session')) return RealRingFailure.signedOut;
  return RealRingFailure.unknown;
}

/// Which phone the step is on. Each one has its own instruction lines and
/// its own list of things to check, with no shared wording between them.
enum RealRingPlatform {
  /// iOS 26 or later: the push becomes an AlarmKit alarm.
  iosAlarm,

  /// iOS 16 to 25: the push is a Time-Sensitive notification with sound.
  /// Nothing on this phone is promised through silent mode.
  iosTimeSensitive,

  /// Android: the push opens the full-screen alarm.
  android,
}

/// Picks the platform from values, so no screen asks the platform itself.
/// [claim] is what `RingClaim.forPhone` answered for this phone.
RealRingPlatform realRingPlatformFor({
  required TargetPlatform platform,
  required bool isWeb,
  required RingClaim claim,
}) {
  if (!isWeb && platform == TargetPlatform.iOS) {
    return claim == RingClaim.timeSensitive
        ? RealRingPlatform.iosTimeSensitive
        : RealRingPlatform.iosAlarm;
  }
  return RealRingPlatform.android;
}
