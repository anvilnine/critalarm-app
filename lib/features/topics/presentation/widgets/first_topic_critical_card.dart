import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The tone of the first-topic card for a switch that is [isCritical].
///
/// The one place that decides it. The card settles while the switch is off
/// and takes the critical canvas once the user turns it on, so red appears
/// only after the choice is made and the flip is the one thing that moves.
AppHighlightTone firstTopicCardTone({required bool isCritical}) =>
    isCritical ? AppHighlightTone.crit : AppHighlightTone.calm;

/// The locale keys the first-topic card shows, picked from what is true now.
///
/// Off, the card asks the user to turn it on and says what leaving it off
/// costs. On, it states what the topic does. A subtitle that would only repeat
/// the title is left out, so every line adds something.
class FirstTopicCardCopy {
  const FirstTopicCardCopy({
    required this.titleKey,
    required this.subtitleKey,
    required this.offLineKey,
    required this.planLineKey,
  });

  final String titleKey;

  /// Null when the title already says it.
  final String? subtitleKey;

  /// Only while the switch is off.
  final String? offLineKey;

  /// Null off the free plan. Takes `used` and `limit`.
  final String? planLineKey;
}

/// The words for the card, by [claim], the switch and whether the free plan
/// line applies. The one place that chooses them.
FirstTopicCardCopy firstTopicCardCopy({
  required RingClaim claim,
  required bool isCritical,
  required bool hasPlanLine,
}) {
  final planKey = !hasPlanLine
      ? null
      : isCritical
      ? LocaleKeys.create_topic_first_topic_critical_free_plan_line_on
      : LocaleKeys.create_topic_first_topic_critical_free_plan_line_off;
  return switch ((claim, isCritical)) {
    (RingClaim.alarm, false) => FirstTopicCardCopy(
      titleKey: LocaleKeys.create_topic_first_topic_critical_title,
      subtitleKey: LocaleKeys.create_topic_critical_toggle_subtitle,
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
      subtitleKey:
          LocaleKeys.create_topic_critical_toggle_subtitle_time_sensitive,
      offLineKey: LocaleKeys.create_topic_first_topic_critical_off_line,
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
/// It says what the switch does and what happens if it stays off. The switch
/// is off until the user flips it: this widget only reports a tap through
/// [onChanged] and never changes the value itself.
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
    final subtitle = copy.subtitleKey?.tr();
    final offLine = copy.offLineKey?.tr();
    final planLine = switch ((copy.planLineKey, plan)) {
      (final key?, final plan?) => key.tr(
        namedArgs: {'used': '${plan.used}', 'limit': '${plan.limit}'},
      ),
      _ => null,
    };

    final ink = colors.onCanvas;
    return AppHighlightCard(
      tone: firstTopicCardTone(isCritical: isCritical),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.small(
                            ink,
                            fontSize: 12,
                          ).copyWith(height: 1.4),
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
                semanticHint: [?subtitle, ?offLine, ?planLine].join(' '),
              ),
            ],
          ),
          // Drawn while the switch is off, so the cost of leaving it off is
          // in front of the user. It retracts with the tone change.
          AnimatedSize(
            duration: context.motion(AppDurations.base),
            curve: AppCurves.easeOut,
            alignment: Alignment.topLeft,
            child: offLine == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ExcludeSemantics(
                      child: Text(
                        offLine,
                        style: AppTypography.small(
                          ink,
                          fontSize: 13,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ),
          ),
          if (planLine != null) ...[
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                planLine,
                style: AppTypography.small(ink, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
