import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The tone of the first-topic card for a switch that is [isCritical].
///
/// The one place that decides it. Off, the card is a choice nobody has made
/// yet: it stands out, and claims nothing. On, it takes the critical canvas.
/// In the light palette the two share a stroke, so red is the only thing
/// that moves when the user flips the switch.
AppHighlightTone firstTopicCardTone({required bool isCritical}) =>
    isCritical ? AppHighlightTone.crit : AppHighlightTone.choice;

/// The locale keys the first-topic card shows, picked from what is true now.
///
/// One title and one line under it. Off, the title names what the switch
/// does and the line says what leaving it off costs. On, the title states
/// what the topic does and the line adds what the title left out.
class FirstTopicCardCopy {
  const FirstTopicCardCopy({
    required this.titleKey,
    required this.subtitleKey,
    required this.offLineKey,
    required this.planLineKey,
  });

  final String titleKey;

  /// Only while the switch is on. Null when the title already says it.
  final String? subtitleKey;

  /// Only while the switch is off.
  final String? offLineKey;

  /// Null off the free plan. Takes `used` and `limit`.
  final String? planLineKey;

  /// The one line under the title: what off costs, or what on adds.
  String? get lineKey => offLineKey ?? subtitleKey;
}

/// The words for the card, by [claim], the switch and whether the free plan
/// line applies. The one place that chooses them.
FirstTopicCardCopy firstTopicCardCopy({
  required RingClaim claim,
  required bool isCritical,
  required bool hasPlanLine,
}) {
  // The same line either way: it is a count, and the switch does not change
  // what the count would be.
  final planKey = hasPlanLine
      ? LocaleKeys.create_topic_first_topic_critical_plan_line
      : null;
  return switch ((claim, isCritical)) {
    (RingClaim.alarm, false) => FirstTopicCardCopy(
      titleKey: LocaleKeys.create_topic_first_topic_critical_title,
      subtitleKey: null,
      offLineKey: LocaleKeys.create_topic_first_topic_critical_off_line,
      planLineKey: planKey,
    ),
    (RingClaim.alarm, true) => FirstTopicCardCopy(
      titleKey: LocaleKeys.create_topic_first_topic_critical_title_on,
      subtitleKey: LocaleKeys.create_topic_first_topic_critical_subtitle_on,
      offLineKey: null,
      planLineKey: planKey,
    ),
    (RingClaim.timeSensitive, false) => FirstTopicCardCopy(
      titleKey:
          LocaleKeys.create_topic_first_topic_critical_title_time_sensitive,
      subtitleKey: null,
      offLineKey:
          LocaleKeys.create_topic_first_topic_critical_off_line_time_sensitive,
      planLineKey: planKey,
    ),
    (RingClaim.timeSensitive, true) => FirstTopicCardCopy(
      titleKey:
          LocaleKeys.create_topic_first_topic_critical_title_time_sensitive_on,
      subtitleKey: LocaleKeys
          .create_topic_first_topic_critical_subtitle_time_sensitive_on,
      offLineKey: null,
      planLineKey: planKey,
    ),
  };
}

/// The Critical delivery switch as the hero of the user's first topic.
///
/// One title, one line. It says what the switch does and what off costs.
/// The switch is off until the user flips it: this widget only reports a tap
/// through [onChanged] and never changes the value itself.
class FirstTopicCriticalCard extends StatelessWidget {
  const FirstTopicCriticalCard({
    required this.claim,
    required this.isCritical,
    required this.onChanged,
    this.plan,
    super.key,
  });

  /// What this phone can promise. Picks the words, never an inline platform
  /// check.
  final RingClaim claim;

  final bool isCritical;

  /// Null while a create is running, which locks the switch.
  final ValueChanged<bool>? onChanged;

  /// On the free plan: the critical topics this one would use and the cap, both
  /// from the plan. Null off the free plan, which leaves the plan line out.
  final ({int used, int limit})? plan;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final copy = firstTopicCardCopy(
      claim: claim,
      isCritical: isCritical,
      hasPlanLine: plan != null,
    );
    final title = copy.titleKey.tr();
    final line = copy.lineKey?.tr();
    final planLine = switch ((copy.planLineKey, plan)) {
      (final key?, final plan?) => key.tr(
        namedArgs: {'used': '${plan.used}', 'limit': '${plan.limit}'},
      ),
      _ => null,
    };

    final ink = colors.onCanvas;
    return AppHighlightCard(
      tone: firstTopicCardTone(isCritical: isCritical),
      child: Row(
        children: [
          Expanded(
            // The switch carries the words, so a screen reader hears one
            // "Title, switch, off" instead of loose lines.
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.small(
                      ink,
                      fontSize: 15,
                    ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  if (line != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: AppTypography.small(
                        ink,
                        fontSize: 13,
                      ).copyWith(height: 1.35),
                    ),
                  ],
                  if (planLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      planLine,
                      style: AppTypography.small(ink, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(
            value: isCritical,
            onChanged: onChanged,
            semanticLabel: title,
            semanticHint: [?line, ?planLine].join(' '),
          ),
        ],
      ),
    );
  }
}
