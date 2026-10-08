import 'dart:math' as math;

import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// One bar in the week.
@immutable
class AppStatDay {
  const AppStatDay({
    required this.letter,
    required this.alarms,
    required this.semanticsLabel,
    this.isToday = false,
    this.hasUnanswered = false,
  });

  /// The day's letter under its bar.
  final String letter;

  /// How many alarms rang that day.
  final int alarms;

  /// What a screen reader says for the bar, such as "Monday: 1 alarm, not
  /// answered".
  final String semanticsLabel;

  /// True for the last bar.
  final bool isToday;

  /// True when an alarm that day was not answered.
  final bool hasUnanswered;
}

/// What a bar is made of.
enum AppStatBarKind {
  /// A day with no alarm: a short stub.
  quiet,

  /// A day with alarms, all answered.
  busy,

  /// The current day.
  today,

  /// A day with an unanswered alarm.
  unanswered,
}

/// The kind of bar [day] draws. An unanswered alarm outranks being today:
/// red is the thing to see, and the letter still marks today.
AppStatBarKind statBarKind(AppStatDay day) {
  if (day.hasUnanswered) return AppStatBarKind.unanswered;
  if (day.isToday) return AppStatBarKind.today;
  if (day.alarms > 0) return AppStatBarKind.busy;
  return AppStatBarKind.quiet;
}

/// The height of a bar for [alarms] alarms, in points: a stub of 8 for none,
/// then 28, 40 and 52 for one, two and three or more.
double statBarHeight(int alarms) {
  if (alarms <= 0) return 8;
  return math.min(52, 16 + 12.0 * alarms);
}

/// The colour of a bar of [kind].
Color statBarColor(AppStatBarKind kind, AppColors colors) => switch (kind) {
  AppStatBarKind.quiet => colors.onPanel.withValues(alpha: 0.14),
  AppStatBarKind.busy => colors.onPanel.withValues(alpha: 0.5),
  AppStatBarKind.today => colors.yellow,
  AppStatBarKind.unanswered => colors.crit,
};

/// History's dark card: a week of seven bars and two numbers.
///
/// Today's bar is yellow, a day with an unanswered alarm is red, a day with
/// answered alarms is a pale bar and a quiet day is a short stub. The bars are
/// the picture: each one is labelled for a screen reader through the days'
/// [AppStatDay.semanticsLabel]. A week with no alarm is a finished picture
/// too: seven stubs and the numbers the caller passes.
///
/// It takes the same surface as [AppStatusCard], including the lift and the
/// outline in the dark theme.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    required this.days,
    required this.firstValue,
    required this.firstCaption,
    required this.secondValue,
    required this.secondCaption,
    this.semanticsLabel,
    super.key,
  }) : assert(days.length == 7, 'A week has seven days.');

  /// Seven days, oldest first.
  final List<AppStatDay> days;

  /// The first number, such as `3`.
  final String firstValue;

  /// The mono-quiet caption under it, such as "alarms, 7 days".
  final String firstCaption;

  /// The second number, such as `11 s`.
  final String secondValue;

  /// Its caption.
  final String secondCaption;

  /// One sentence for the chart as a whole. Null leaves the bars to speak.
  final String? semanticsLabel;

  static const double _barWidth = 14;
  static const double _barGap = 7;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.of(context).brightness;
    final surface = statusCardSurface(colors, brightness);
    final duration = context.motion(AppDurations.slow);

    TextStyle number() => TextStyle(
      fontFamily: AppTypography.fontDisplay,
      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
      fontWeight: FontWeight.w800,
      fontSize: 44,
      height: 1,
      letterSpacing: -0.03 * 44,
      color: colors.yellow,
    );
    final caption = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontSize: 13,
      height: 1.25,
      color: colors.onPanelMuted,
    );

    Widget stat(String value, String text) => Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: number()),
          ),
          const SizedBox(height: 2),
          Text(text, style: caption),
        ],
      ),
    );

    final bars = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: _barGap),
          Semantics(
            label: days[i].semanticsLabel,
            child: ExcludeSemantics(
              child: SizedBox(
                width: _barWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      curve: AppCurves.easeOut,
                      height: statBarHeight(days[i].alarms),
                      decoration: BoxDecoration(
                        color: statBarColor(statBarKind(days[i]), colors),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      days[i].letter,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontFamilyFallback: AppTypography.fontMonoFallbacks,
                        fontWeight: days[i].isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 10,
                        height: 1.2,
                        color: days[i].isToday
                            ? colors.onPanel
                            : colors.onPanelMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final isDark = brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface.fill,
          borderRadius: Radii.xlAll,
          border: surface.line == null
              ? null
              : Border.all(color: surface.line!),
          boxShadow: isDark ? const [] : AppShadows.lightMd,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(alignment: Alignment.centerRight, child: bars),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  stat(firstValue, firstCaption),
                  const SizedBox(width: 26),
                  stat(secondValue, secondCaption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
