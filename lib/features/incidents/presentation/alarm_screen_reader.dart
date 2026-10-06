import 'dart:ui' show AppLifecycleState;

import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// What a screen reader says on the ringing alarm screen. Pure functions, so
/// the words can be tested without a screen.

/// Whether the ringing screen is the thing the user is looking at.
///
/// Its route has to be the current one ([isRouteCurrent]: no sheet and no
/// other screen over it) and the app has to be resumed. Control Center, the
/// notification shade, an incoming call and the app switcher all leave the
/// route current and take the app out of `resumed`. A lifecycle nobody has
/// reported yet counts as not resumed.
///
/// The magic tap is armed, and the delayed announcement is spoken, only
/// while this is true.
bool isRingingScreenInFront({
  required bool isRouteCurrent,
  required AppLifecycleState? lifecycle,
}) => isRouteCurrent && lifecycle == AppLifecycleState.resumed;

/// How long the alarm has been ringing, in whole minutes.
///
/// The line on screen counts seconds. Read aloud, that would change under the
/// listener every second, so the spoken form only changes once a minute.
String spokenRingTime(Duration ringing) {
  final minutes = ringing.inMinutes;
  if (minutes < 1) {
    return LocaleKeys.critical_alarm_ring_time_spoken_under_minute.tr();
  }
  return LocaleKeys.critical_alarm_ring_time_spoken.plural(minutes);
}

/// The one announcement made when the ringing screen appears: which topic is
/// ringing and for how long, plus the count when more than one alarm is open.
String ringingAnnouncement({
  required String topic,
  required String ringTime,
  required int openAlarms,
}) {
  if (openAlarms > 1) {
    return LocaleKeys.critical_alarm_announcement_several.tr(
      namedArgs: {
        'topic': topic,
        'ring_time': ringTime,
        'count': '$openAlarms',
      },
    );
  }
  return LocaleKeys.critical_alarm_announcement.tr(
    namedArgs: {'topic': topic, 'ring_time': ringTime},
  );
}

/// The topic name and the severity word under the face, as one stop. The
/// topic comes first because it is what tells two alarms apart.
String spokenTopic({required String topic, required String word}) {
  return LocaleKeys.critical_alarm_topic_semantics.tr(
    namedArgs: {'topic': topic, 'word': word},
  );
}

/// The message card as one stop: title, body, then the time and tags line.
String spokenMessage({
  required String title,
  required String body,
  required String meta,
}) {
  return [title, body, meta].where((part) => part.isNotEmpty).join('\n');
}
