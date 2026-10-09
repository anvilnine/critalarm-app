import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_summary.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/look_pass_tone.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_widgets_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What the root and the pass pages read about the passes right now: the
/// values, the tones and the plan words. Built by [PassLiveBuilder].
class PassLive {
  const PassLive._({
    required this.summary,
    required this.lookStyle,
    required this.colors,
    required this.brightness,
    required this.isPlanRead,
    required this.decisions,
    required this.challengeKind,
  });

  final PersonalizeSummary summary;

  /// The look that rings now: `AlarmStyleGate.styleFor(null)`.
  final AlarmStyle lookStyle;

  final AppColors colors;
  final Brightness brightness;
  final bool isPlanRead;
  final Map<PassId, FeatureDecision> decisions;

  /// The challenge the card shows: the saved default for new topics, or null
  /// when none is saved or challenges are locked (the card says Off).
  final ChallengeKind? challengeKind;

  /// The pass's label, in normal case. The card upper-cases it.
  String labelOf(PassId pass) => switch (pass) {
    PassId.look => LocaleKeys.alarm_styles_strip_title.tr(),
    PassId.sound => LocaleKeys.personalize_sound_title.tr(),
    PassId.challenge => LocaleKeys.challenges_strip_title.tr(),
    PassId.widgets => LocaleKeys.personalize_widgets_row.tr(),
    PassId.appIcon => LocaleKeys.personalize_app_icon_row.tr(),
  };

  /// The pass's value, translated.
  String valueOf(PassId pass) => switch (summary.of(pass).value) {
    PassValueText(:final text) => text,
    PassValueKey(:final key) => key.tr(),
  };

  /// Whether the setting is a saved choice, which decides the value colour.
  bool isOn(PassId pass) => summary.of(pass).isOn;

  /// The card and page colours of the pass in the theme in use. The Look
  /// pass takes the colour of the look that rings.
  PassTone toneOf(PassId pass) => pass == PassId.look
      ? lookPassToneFor(lookStyle, brightness, colors)
      : passToneFor(pass, colors);

  /// The plan word to draw on the pass, or null. It shows only while the
  /// feature is locked and the plan is read, and only on the passes that
  /// carry one. It never changes what a tap does.
  String? tagOf(PassId pass) {
    final item = summary.of(pass);
    if (!item.showsTag || !isPlanRead) return null;
    final decision = decisions[pass];
    return decision is FeatureLocked ? planWordFor(decision.offer) : null;
  }
}

/// Builds [builder] with a [PassLive] and builds it again whenever something
/// the passes show changes: the look, the challenge, the plan, the plan being
/// read, the photo of the own look.
///
/// The root hands it the sound's name and the icon showing now, which it
/// reads from its own state. The pass pages leave them out, because they read
/// only the passes they draw.
class PassLiveBuilder extends StatefulWidget {
  const PassLiveBuilder({
    required this.builder,
    this.soundName,
    this.appIcon,
    super.key,
  });

  final Widget Function(BuildContext context, PassLive live) builder;
  final String? soundName;
  final AppIcon? appIcon;

  @override
  State<PassLiveBuilder> createState() => _PassLiveBuilderState();
}

class _PassLiveBuilderState extends State<PassLiveBuilder> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _access.changes.listen((_) => _redraw()),
      getIt<AlarmStyleChoices>().changes.listen((_) => _redraw()),
      getIt<ChallengeChoices>().changes.listen((_) => _redraw()),
      getIt<AlarmStyleGate>().checked.listen((_) => _redraw()),
      getIt<OwnAlarmLookKeeper>().changes.listen((_) => _redraw()),
    ]);
    _access.planRead.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _access.planRead.removeListener(_redraw);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = alarmStyleOf(getIt<AlarmStyleGate>().styleFor(null));
    final challengesLocked =
        _access.decide(AppFeature.wakeUpChallenges) is FeatureLocked;
    final savedChallenge = getIt<ChallengeChoices>().defaultForNewTopics;
    final summary = personalizeSummaryFor(
      lookNameKey: style.nameKey,
      lookIsStandard: style.id.isFree,
      soundName: widget.soundName,
      challengeKind: savedChallenge,
      challengesLocked: challengesLocked,
      hasWidgets:
          homeWidgetsStepsFor(getIt<PlatformCapabilities>().platform) != null,
      appIcon: widget.appIcon,
    );
    final live = PassLive._(
      summary: summary,
      lookStyle: style,
      colors: context.appColors,
      brightness: Theme.of(context).brightness,
      isPlanRead: _access.isPlanRead,
      decisions: {
        for (final item in summary.passes)
          item.pass: _access.decide(item.feature),
      },
      challengeKind: challengesLocked ? null : savedChallenge,
    );
    return widget.builder(context, live);
  }
}
