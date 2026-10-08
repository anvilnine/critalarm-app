import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:flutter/material.dart';

/// The smallest contrast "I'm up" and the message may have against what
/// is behind them, in every look and both themes (WCAG AA for text).
const double alarmStyleMinContrast = 4.5;

/// One pair of colours a look puts on screen: [foreground] over
/// [background], and how far apart they are.
@immutable
class AlarmContrastLine {
  const AlarmContrastLine(
    this.what,
    this.foreground,
    this.background, {
    required this.isRequired,
  });

  /// What it is, in a few words, for a test's failure message.
  final String what;
  final Color foreground;

  /// What is behind it, flattened: a see-through fill is laid over the
  /// canvas first.
  final Color background;

  /// Whether [ratio] must reach [alarmStyleMinContrast]. The other lines
  /// are measured and reported, and fail nothing.
  final bool isRequired;

  double get ratio => ColorContrast.contrastRatio(foreground, background);

  bool get passes => !isRequired || ratio >= alarmStyleMinContrast;

  @override
  String toString() => '$what ${ratio.toStringAsFixed(2)}';
}

/// What `alarmStyleContrast` found for one look, stage and theme.
@immutable
class AlarmContrastReport {
  const AlarmContrastReport({
    required this.lines,
    required this.acknowledgeStandsOut,
    required this.quietStandsOut,
  });

  final List<AlarmContrastLine> lines;

  /// How far the fill of "I'm up" is from the canvas. Null on the
  /// acknowledged stage, which has no such button.
  final double? acknowledgeStandsOut;

  /// The same for the fill of the quiet buttons.
  final double? quietStandsOut;

  /// "I'm up" is the most visible button: its fill is further from the
  /// canvas than the quiet buttons' fill is.
  bool get acknowledgeIsMostVisible {
    final acknowledge = acknowledgeStandsOut;
    final quiet = quietStandsOut;
    if (acknowledge == null || quiet == null) return true;
    return acknowledge > quiet;
  }

  /// Every line that has to pass and does not, plus the button rule.
  List<String> get failures => [
    for (final line in lines)
      if (!line.passes)
        '$line is under ${alarmStyleMinContrast.toStringAsFixed(1)}',
    if (!acknowledgeIsMostVisible)
      _notMostVisible(acknowledgeStandsOut!, quietStandsOut!),
  ];

  bool get passes => failures.isEmpty;

  static String _notMostVisible(double acknowledge, double quiet) =>
      '"I\'m up" stands out from the canvas by '
      '${acknowledge.toStringAsFixed(2)}, the quiet buttons by '
      '${quiet.toStringAsFixed(2)}: it is not the most visible button';
}

/// The resting fill and label of an `AppButton` of [variant] under
/// [colors]. It follows the switch in `AppButton.build`, for the variants
/// a look may use. Keep the two in step.
({Color fill, Color label}) alarmButtonColors(
  AppButtonVariant variant,
  AppColors colors,
) => switch (variant) {
  AppButtonVariant.primary => (
    fill: colors.highlight,
    label: colors.onHighlight,
  ),
  AppButtonVariant.ink => (fill: colors.ink, label: colors.canvas),
  AppButtonVariant.ghost => (
    fill: const Color(0x00000000),
    label: colors.onCanvas,
  ),
  AppButtonVariant.tinted => (
    fill: colors.surface.withValues(alpha: 0.22),
    label: colors.onCanvas,
  ),
  AppButtonVariant.paper => (fill: colors.surface, label: colors.ink),
  AppButtonVariant.crit => (fill: colors.panel, label: colors.onPanel),
  AppButtonVariant.cream => (
    fill: const Color(0xFFF3EBDD),
    label: const Color(0xFF1A140F),
  ),
  AppButtonVariant.destructive => (fill: colors.crit, label: colors.inkFixed),
  AppButtonVariant.dangerText => (
    fill: const Color(0x00000000),
    label: colors.crit,
  ),
};

/// Measures what [style] puts on [stage] in the [brightness] theme: the
/// buttons and the text against what is behind them.
///
/// The colours are the ones the screen reads, from the look's own palette
/// and its canvas, so a look cannot pass here and draw something else.
/// [severity] is the incident's. It is pure, so the contrast test runs it
/// over every look in the registry.
AlarmContrastReport alarmStyleContrast(
  AlarmStyle style,
  AlarmStage stage, {
  required Brightness brightness,
  SeverityMode severity = SeverityMode.crit,
}) {
  final base = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final colors = style.colorsFor(
    stage,
    base: base,
    severity: severity,
    brightness: brightness,
  );
  final canvas = style.lookOf(stage).ambient(base).canvas;
  Color over(Color fill) => Color.alphaBlend(fill, canvas);
  final card = over(colors.surface);

  switch (stage) {
    case AlarmStage.ringing:
      final acknowledge = alarmButtonColors(
        style.ringing.acknowledgeButton,
        colors,
      );
      final quiet = alarmButtonColors(style.ringing.quietButton, colors);
      return AlarmContrastReport(
        acknowledgeStandsOut: ColorContrast.contrastRatio(
          over(acknowledge.fill),
          canvas,
        ),
        quietStandsOut: ColorContrast.contrastRatio(over(quiet.fill), canvas),
        lines: [
          AlarmContrastLine(
            '"I\'m up" on its fill',
            acknowledge.label,
            over(acknowledge.fill),
            isRequired: true,
          ),
          AlarmContrastLine(
            'message title on the card',
            colors.ink,
            card,
            isRequired: true,
          ),
          AlarmContrastLine(
            'message body on the card',
            colors.ink2,
            card,
            isRequired: true,
          ),
          AlarmContrastLine(
            'message source line on the card',
            colors.ink3,
            card,
            isRequired: true,
          ),
          AlarmContrastLine(
            'topic and time on the canvas',
            colors.onCanvas,
            canvas,
            isRequired: true,
          ),
          AlarmContrastLine(
            'quiet button label on its fill',
            quiet.label,
            over(quiet.fill),
            isRequired: true,
          ),
        ],
      );
    case AlarmStage.acknowledged:
      final desk = alarmButtonColors(AppButtonVariant.ghost, colors);
      final back = alarmButtonColors(AppButtonVariant.paper, colors);
      final row = Color.alphaBlend(colors.cream, card);
      return AlarmContrastReport(
        acknowledgeStandsOut: null,
        quietStandsOut: null,
        lines: [
          AlarmContrastLine(
            'title and line on the canvas',
            colors.onCanvas,
            canvas,
            isRequired: true,
          ),
          AlarmContrastLine(
            '"At my desk" on the canvas',
            desk.label,
            over(desk.fill),
            isRequired: true,
          ),
          AlarmContrastLine(
            '"Back to topics" on its fill',
            back.label,
            over(back.fill),
            isRequired: true,
          ),
          AlarmContrastLine(
            'detail value on its row',
            colors.ink,
            row,
            isRequired: true,
          ),
          AlarmContrastLine(
            'detail label on its row',
            colors.ink3,
            row,
            isRequired: false,
          ),
        ],
      );
  }
}
