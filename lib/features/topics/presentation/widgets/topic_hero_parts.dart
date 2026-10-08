import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/topics/domain/topic_hero_card.dart';
import 'package:critalarm/features/topics/domain/topic_summary.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The name's size and line height.
const double _kNameSize = 25;
const double _kNameLine = 1.25;

/// The summary's size and line height.
const double _kSummarySize = 14.5;
const double _kSummaryLine = 1.35;

/// The gap between the name and the summary.
const double _kHeaderGap = 2;

/// How many lines the summary may take: one, or two once the text is large.
int _summaryLines(TextScaler scaler) =>
    scaler.scale(16) / 16 > kChromeMaxTextScale ? 2 : 1;

/// How tall [TopicHeader] is for the text size of [context].
///
/// Fixed, because the canvas draws the hero's disc and has to know where the
/// scene starts: the header never grows past this, whatever the name or the
/// summary says.
double topicHeaderHeight(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  return scaler.scale(_kNameSize) * _kNameLine +
      _kHeaderGap +
      _summaryLines(scaler) * scaler.scale(_kSummarySize) * _kSummaryLine;
}

/// The topic's name in mono and the one line under it.
///
/// Each takes one line and ends in an ellipsis when it is too long (the
/// summary two lines at large text). A screen reader gets both in full.
class TopicHeader extends StatelessWidget {
  const TopicHeader({
    required this.name,
    required this.summary,
    required this.height,
    super.key,
  });

  final String name;
  final String summary;

  /// From [topicHeaderHeight].
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      header: true,
      label: '$name. $summary',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: scaler.scale(_kNameSize) * _kNameLine,
                  child: Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.monoBold(
                      colors.onCanvas,
                      fontSize: _kNameSize,
                    ).copyWith(height: _kNameLine, letterSpacing: -0.25),
                  ),
                ),
                const SizedBox(height: _kHeaderGap),
                SizedBox(
                  height:
                      _summaryLines(scaler) *
                      scaler.scale(_kSummarySize) *
                      _kSummaryLine,
                  child: Text(
                    summary,
                    maxLines: _summaryLines(scaler),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small(
                      colors.onCanvasMuted,
                      fontSize: _kSummarySize,
                    ).copyWith(height: _kSummaryLine),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under the name, for [summary].
String topicSummaryText(TopicSummary summary) {
  if (summary.isEmpty) return LocaleKeys.topic_hero_summary_nothing.tr();
  final count = summary.today == 0
      ? LocaleKeys.topic_hero_summary_none_today.tr()
      : LocaleKeys.topic_hero_summary_today.plural(summary.today);
  final at = summary.lastAlarmAt;
  if (at == null) return count;
  final local = at.toLocal();
  final time = summary.lastAlarmIsToday
      ? DateFormat.Hm().format(local)
      : DateFormat('d MMM').format(local);
  final last = LocaleKeys.topic_hero_summary_last_alarm.tr(
    namedArgs: {'time': time},
  );
  return '$count $last';
}

/// The foot of the card for [foot].
String topicFootText(TopicHeroFoot foot) => switch (foot) {
  TopicHeroFoot.ringsThroughSilent =>
    LocaleKeys.topic_hero_foot_rings_through_silent.tr(),
  TopicHeroFoot.timeSensitive => LocaleKeys.topic_hero_foot_time_sensitive.tr(),
  TopicHeroFoot.normalPush => LocaleKeys.topic_hero_foot_normal_push.tr(),
  TopicHeroFoot.needsAlarm => LocaleKeys.topic_hero_foot_needs_alarm.tr(),
};

/// The dark card with the Critical delivery switch.
///
/// The numeral is On in yellow or Off muted. The switch is in the card's
/// trailing slot, in the panel variant so its off track shows on the dark
/// card. A tap on the card body opens the info dialog.
class TopicCriticalCard extends StatefulWidget {
  const TopicCriticalCard({
    required this.card,
    required this.onChanged,
    required this.onInfo,
    super.key,
  });

  final TopicHeroCard card;

  /// Null leaves the switch still.
  final ValueChanged<bool>? onChanged;

  /// Opens the explanation of Critical delivery.
  final VoidCallback onInfo;

  @override
  State<TopicCriticalCard> createState() => _TopicCriticalCardState();
}

class _TopicCriticalCardState extends State<TopicCriticalCard> {
  /// The numeral that was on the card before this build was dots. The step
  /// from dots to the real answer is the screen finishing loading, not news,
  /// so it does not pop.
  bool _cameFromLoading = false;

  @override
  void didUpdateWidget(covariant TopicCriticalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cameFromLoading = oldWidget.card.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final foot = card.foot;
    final numeral = card.isLoading
        ? '···'
        : card.isOn
        ? LocaleKeys.topic_hero_numeral_on.tr()
        : LocaleKeys.topic_hero_numeral_off.tr();
    return AppStatusCard(
      label: LocaleKeys.topic_hero_card_label.tr().toUpperCase(),
      numeral: numeral,
      numeralTone: card.isOn ? AppStatusTone.yellow : AppStatusTone.muted,
      foot: foot == null ? null : topicFootText(foot),
      popsOnChange: !_cameFromLoading,
      onTap: card.isLoading ? null : widget.onInfo,
      trailing: AppSwitch(
        value: card.isOn,
        variant: AppSwitchVariant.panel,
        onChanged: widget.onChanged,
        semanticLabel: LocaleKeys.topic_detail_critical_toggle_title.tr(),
        semanticHint: foot == null ? null : topicFootText(foot),
      ),
    );
  }
}
