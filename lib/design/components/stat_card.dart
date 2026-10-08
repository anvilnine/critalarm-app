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
    this.isHidden = false,
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

  /// True for a day the plan's history does not reach. It has a letter and no
  /// bar, so it does not read as a quiet day.
  final bool isHidden;
}

/// What a bar is made of.
enum AppStatBarKind {
  /// A day the plan's history does not reach: no bar at all.
  hidden,

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
  if (day.isHidden) return AppStatBarKind.hidden;
  if (day.hasUnanswered) return AppStatBarKind.unanswered;
  if (day.isToday) return AppStatBarKind.today;
  if (day.alarms > 0) return AppStatBarKind.busy;
  return AppStatBarKind.quiet;
}

/// The tallest a bar gets, for three alarms or more.
const double kStatBarMaxHeight = 88;

/// The height of a bar for [alarms] alarms, in points: a stub of 8 for none,
/// then 36, 62 and 88 for one, two and three or more.
double statBarHeight(int alarms) {
  if (alarms <= 0) return 8;
  return math.min(kStatBarMaxHeight, 10 + 26.0 * alarms);
}

/// The colour of a bar of [kind].
Color statBarColor(AppStatBarKind kind, AppColors colors) => switch (kind) {
  AppStatBarKind.hidden => Colors.transparent,
  AppStatBarKind.quiet => colors.onPanel.withValues(alpha: 0.14),
  AppStatBarKind.busy => colors.onPanel.withValues(alpha: 0.5),
  AppStatBarKind.today => colors.yellow,
  AppStatBarKind.unanswered => colors.crit,
};

/// History's dark card: a week of seven bars and two numbers.
///
/// Today's bar is yellow, a day with an unanswered alarm is red, a day with
/// answered alarms is a pale bar and a quiet day is a short stub. A day the
/// plan does not reach has a letter and no bar. The bars are the picture:
/// each one is labelled for a screen reader through the days'
/// [AppStatDay.semanticsLabel]. A week with no alarm is a finished picture
/// too: seven stubs and the numbers the caller passes.
///
/// The numbers sit in a column on the left and the bars fill the right, so
/// the card reads as one block. On a narrow card or at a large text size the
/// bars take the full width on top and the numbers sit side by side under
/// them.
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
  static const double _stackedBarWidth = 26;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 18, 20, 18);

  /// The inner width the side by side layout needs: the chart, a gap and a
  /// column wide enough for a numeral such as `11 s`.
  static const double _sideBySideMinWidth = 290;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.of(context).brightness;
    final surface = statusCardSurface(colors, brightness);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;

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

    Widget stat(String value, String text) => Column(
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
          padding: _padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide =
                  constraints.maxWidth >= _sideBySideMinWidth &&
                  textScale <= kChromeMaxTextScale;
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          stat(firstValue, firstCaption),
                          const SizedBox(height: 16),
                          stat(secondValue, secondCaption),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _Bars(
                      days: days,
                      barWidth: _barWidth,
                      gap: _barGap,
                      colors: colors,
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Bars(
                    days: days,
                    barWidth: _stackedBarWidth,
                    gap: null,
                    colors: colors,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(child: stat(firstValue, firstCaption)),
                      const SizedBox(width: 26),
                      Flexible(child: stat(secondValue, secondCaption)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The seven bars and their letters. A null [gap] spreads them across the
/// width they are given.
class _Bars extends StatelessWidget {
  const _Bars({
    required this.days,
    required this.barWidth,
    required this.gap,
    required this.colors,
  });

  final List<AppStatDay> days;
  final double barWidth;
  final double? gap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(AppDurations.slow);
    // The letters are chart chrome: they stop growing at the chrome limit,
    // or they would be wider than their bar.
    final capped = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: kChromeMaxTextScale);

    Widget bar(AppStatDay day) => Semantics(
      label: day.semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: barWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: duration,
                curve: AppCurves.easeOut,
                height: statBarHeight(day.alarms),
                decoration: BoxDecoration(
                  color: statBarColor(statBarKind(day), colors),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                day.letter,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                textScaler: capped,
                style: TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontFamilyFallback: AppTypography.fontMonoFallbacks,
                  fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10,
                  height: 1.2,
                  color: day.isToday ? colors.onPanel : colors.onPanelMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final spread = gap == null;
    return Row(
      mainAxisSize: spread ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: spread
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (!spread && i > 0) SizedBox(width: gap),
          bar(days[i]),
        ],
      ],
    );
  }
}
