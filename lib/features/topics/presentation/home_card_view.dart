import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/readiness_pips.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// What the dark card and its hero draw for a [HomeCardModel], as plain
/// values. Pure: the screen hands them to `AppStatusCard` and `AppHeroScene`.
@immutable
class HomeCardView {
  const HomeCardView({
    required this.numeral,
    required this.numeralTone,
    required this.footTone,
    required this.heroTone,
    required this.gaze,
    this.label,
    this.foot,
    this.pips,
    this.actionLabel,
    this.isLive = false,
    this.ticks = false,
  });

  final String? label;
  final String numeral;
  final AppStatusTone numeralTone;
  final String? foot;
  final AppStatusTone footTone;
  final List<AppPipTone>? pips;
  final String? actionLabel;
  final AppHeroTone heroTone;
  final AppHeroGaze gaze;

  /// An alarm is sounding: the face shakes.
  final bool isLive;

  /// The numeral is a clock the screen has to redraw each second.
  final bool ticks;
}

/// The view of [model] at [now].
HomeCardView homeCardViewFor(
  HomeCardModel model, {
  required DateTime now,
}) {
  final numeral = model.numeral;
  final action = model.action;
  return HomeCardView(
    label: _label(model.label),
    numeral: homeCardNumeralText(numeral, now: now),
    numeralTone: _numeralTone(model.numeralTone),
    foot: _foot(model.foot, now: now),
    footTone: _footTone(model.kind),
    pips: model.pips.isEmpty ? null : [for (final pip in model.pips) _pip(pip)],
    actionLabel: action == null ? null : _actionLabel(action),
    heroTone: _heroTone(model.discTone),
    gaze: model.kind == HomeCardKind.idle ? AppHeroGaze.card : AppHeroGaze.none,
    isLive: model.kind == HomeCardKind.ringing,
    ticks: numeral is Elapsed || numeral is Remaining,
  );
}

/// The backdrop the Topics tab asks the ambient canvas for while the card
/// shows [model]: the card's canvas (the yellow ground, or the warning,
/// ringing and acknowledged one) with the disc tinted for its state.
///
/// [colors] are the app's own, not the ones inside the screen's severity
/// scope. Handing the canvas a different profile when the card changes is
/// what makes the backdrop morph from one state to the next.
AmbientProfile homeAmbientProfile(
  HomeCardModel model,
  AppColors colors, {
  HeroDiscSpot spot = HeroDiscSpot.phone,
}) => AmbientAppProfiles.topicsHero(
  colors,
  severity: model.severity,
  tone: _heroTone(model.discTone),
  spot: spot,
);

/// The big figure as text.
String homeCardNumeralText(HomeCardNumeral numeral, {required DateTime now}) =>
    switch (numeral) {
      Dots() => '···',
      No() => LocaleKeys.home_card_numeral_no.tr(),
      Unknown() => '?',
      NotYet() => LocaleKeys.home_card_numeral_not_yet.tr(),
      Count(:final done, :final of) => '$done/$of',
      Number(:final n) => '$n',
      Seconds(:final n) => LocaleKeys.home_card_numeral_seconds.tr(
        namedArgs: {'n': '$n'},
      ),
      Days(:final n) => LocaleKeys.home_card_numeral_days.tr(
        namedArgs: {'n': '$n'},
      ),
      Elapsed(:final since) => _clock(now.difference(since)),
      Remaining(:final until) => _remaining(until.difference(now)),
      At(:final time) => DateFormat.Hm().format(time.toLocal()),
    };

/// `m:ss`, never negative.
String _clock(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '${total ~/ 60}:$seconds';
}

/// Whole minutes while there is a minute or more left, then `m:ss`.
String _remaining(Duration left) {
  if (left.inSeconds < 60) return _clock(left);
  return LocaleKeys.home_card_numeral_minutes.tr(
    namedArgs: {'n': '${(left.inSeconds / 60).ceil()}'},
  );
}

String? _label(HomeCardLabel label) {
  final key = switch (label) {
    HomeCardLabel.none => null,
    HomeCardLabel.willItWakeMe => LocaleKeys.home_card_label_will_it_wake_me,
    HomeCardLabel.ringing => LocaleKeys.home_card_label_ringing,
    HomeCardLabel.ringsAgainIn => LocaleKeys.home_card_label_rings_again_in,
    HomeCardLabel.answeredIn => LocaleKeys.home_card_label_answered_in,
    HomeCardLabel.closed => LocaleKeys.home_card_label_closed,
    HomeCardLabel.missed => LocaleKeys.home_card_label_missed,
    HomeCardLabel.serverLastSeen => LocaleKeys.home_card_label_server_last_seen,
    HomeCardLabel.server => LocaleKeys.home_card_label_server,
    HomeCardLabel.topics => LocaleKeys.home_card_label_topics,
    HomeCardLabel.needsALook => LocaleKeys.home_card_label_needs_a_look,
    HomeCardLabel.setup => LocaleKeys.home_card_label_setup,
    HomeCardLabel.firstMessage => LocaleKeys.home_card_label_first_message,
    HomeCardLabel.quietFor => LocaleKeys.home_card_label_quiet_for,
  };
  return key?.tr().toUpperCase();
}

String _time(DateTime at, DateTime now) {
  final local = at.toLocal();
  final today = now.toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return sameDay
      ? DateFormat.Hm().format(local)
      : DateFormat('d MMM').format(local);
}

String _span(Duration d) => d.inSeconds < 60
    ? LocaleKeys.home_card_numeral_seconds.tr(
        namedArgs: {'n': '${d.inSeconds}'},
      )
    : LocaleKeys.home_card_numeral_minutes.tr(
        namedArgs: {'n': '${(d.inSeconds / 60).round()}'},
      );

String _foot(HomeCardFoot foot, {required DateTime now}) {
  final time = foot.time;
  return switch (foot.slot) {
    HomeCardFootSlot.askingServer =>
      LocaleKeys.home_card_foot_asking_server.tr(),
    HomeCardFootSlot.topic => foot.topic ?? '',
    HomeCardFootSlot.topicUnlessClosed =>
      LocaleKeys.home_card_foot_topic_unless_closed.tr(
        namedArgs: {'topic': foot.topic ?? ''},
      ),
    HomeCardFootSlot.topicClosedAt =>
      LocaleKeys.home_card_foot_topic_closed_at.tr(
        namedArgs: {
          'topic': foot.topic ?? '',
          'time': time == null ? '' : _time(time, now),
        },
      ),
    HomeCardFootSlot.missedRang => LocaleKeys.home_card_foot_missed_rang.tr(
      namedArgs: {
        'duration': _span(foot.duration ?? Duration.zero),
        'time': time == null ? '' : _time(time, now),
      },
    ),
    HomeCardFootSlot.missedAt => LocaleKeys.home_card_foot_missed_at.tr(
      namedArgs: {'time': time == null ? '' : _time(time, now)},
    ),
    HomeCardFootSlot.noServer => LocaleKeys.home_card_foot_no_server.tr(),
    HomeCardFootSlot.notAnswering =>
      LocaleKeys.home_card_foot_not_answering.tr(),
    HomeCardFootSlot.couldNotLoad =>
      LocaleKeys.home_card_foot_could_not_load.tr(),
    HomeCardFootSlot.nothingReachesYou =>
      LocaleKeys.home_card_foot_nothing_reaches_you.tr(),
    HomeCardFootSlot.worstCheck => homeCardCheckFoot(foot.checkId),
    HomeCardFootSlot.checkCouldNotRun =>
      LocaleKeys.home_card_foot_check_could_not_run.tr(),
    HomeCardFootSlot.warningTopics =>
      LocaleKeys.home_card_foot_warning_topics.tr(),
    HomeCardFootSlot.setupNext =>
      foot.setupRow == null
          ? LocaleKeys.home_card_foot_setup_done.tr()
          : LocaleKeys.home_card_foot_setup_next.tr(
              namedArgs: {'row': _setupRow(foot.setupRow!)},
            ),
    HomeCardFootSlot.sendTheLine =>
      LocaleKeys.home_card_foot_send_the_line.tr(),
    HomeCardFootSlot.lastAlarm => LocaleKeys.home_card_foot_last_alarm.tr(
      namedArgs: {'time': time == null ? '' : _time(time, now)},
    ),
    HomeCardFootSlot.noAlarmYet => LocaleKeys.home_card_foot_no_alarm_yet.tr(),
    HomeCardFootSlot.noTopicRings =>
      LocaleKeys.home_card_foot_no_topic_rings.tr(),
  };
}

String _setupRow(SetupChecklistRow row) => switch (row) {
  SetupChecklistRow.server => LocaleKeys.home_card_setup_row_server.tr(),
  SetupChecklistRow.criticalTopic =>
    LocaleKeys.home_card_setup_row_critical.tr(),
  SetupChecklistRow.firstMessage =>
    LocaleKeys.home_card_setup_row_first_message.tr(),
};

/// The short line for a failing check.
String homeCardCheckFoot(ReliabilityCheckId? id) {
  final key = switch (id?.value) {
    'notifications' => LocaleKeys.home_card_check_notifications,
    'full_screen_alarm' => LocaleKeys.home_card_check_full_screen_alarm,
    'battery_optimization' => LocaleKeys.home_card_check_battery_optimization,
    'alarms' => LocaleKeys.home_card_check_alarms,
    'time_sensitive' => LocaleKeys.home_card_check_time_sensitive,
    'push_token_confirmed' => LocaleKeys.home_card_check_push_token_confirmed,
    'last_push_received' => LocaleKeys.home_card_check_last_push_received,
    'system_update' => LocaleKeys.home_card_check_system_update,
    'phone_maker' => LocaleKeys.home_card_check_phone_maker,
    'missed_alarm' => LocaleKeys.home_card_check_missed_alarm,
    _ => LocaleKeys.home_card_check_other,
  };
  return key.tr();
}

String _actionLabel(HomeCardAction action) => switch (action) {
  OpenAlarm() => LocaleKeys.home_card_action_open_alarm.tr(),
  OpenIncident() => LocaleKeys.home_card_action_open_it.tr(),
  SeeMissed() => LocaleKeys.home_card_action_see_why.tr(),
  ConnectServer() => LocaleKeys.home_card_action_connect_server.tr(),
  RetryLoad() => LocaleKeys.home_card_action_try_again.tr(),
  Fix() => LocaleKeys.home_card_action_fix.tr(),
  ContinueSetup() => LocaleKeys.home_card_action_continue.tr(),
  GetFirstLine() => LocaleKeys.home_card_action_get_line.tr(),
  SendTest() => LocaleKeys.home_card_action_send_test.tr(),
};

AppStatusTone _numeralTone(HomeCardNumeralTone tone) => switch (tone) {
  HomeCardNumeralTone.yellow => AppStatusTone.yellow,
  HomeCardNumeralTone.muted => AppStatusTone.muted,
  HomeCardNumeralTone.orange => AppStatusTone.orange,
  HomeCardNumeralTone.orangeAlt => AppStatusTone.orangeSoft,
  HomeCardNumeralTone.red || HomeCardNumeralTone.redAlt => AppStatusTone.red,
};

AppStatusTone _footTone(HomeCardKind kind) => switch (kind) {
  HomeCardKind.issueLook => AppStatusTone.orangeSoft,
  HomeCardKind.issueBroken || HomeCardKind.noServer => AppStatusTone.red,
  _ => AppStatusTone.muted,
};

AppHeroTone _heroTone(HomeCardDiscTone tone) => switch (tone) {
  HomeCardDiscTone.ink => AppHeroTone.quiet,
  HomeCardDiscTone.orangeSoft => AppHeroTone.look,
  HomeCardDiscTone.redSoft => AppHeroTone.danger,
  HomeCardDiscTone.paleYellow ||
  HomeCardDiscTone.orange ||
  HomeCardDiscTone.red ||
  HomeCardDiscTone.cobalt => AppHeroTone.calm,
};

AppPipTone _pip(PipTone tone) => switch (tone) {
  PipTone.fine => AppPipTone.fine,
  PipTone.look => AppPipTone.look,
  PipTone.broken => AppPipTone.broken,
  PipTone.open => AppPipTone.open,
};
