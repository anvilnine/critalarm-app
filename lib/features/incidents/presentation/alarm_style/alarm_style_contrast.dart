import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:flutter/material.dart';

/// The smallest contrast text may have against what is behind it, in every
/// look and both themes (WCAG AA for text): "I'm up", the other buttons'
/// labels and the message.
const double alarmStyleMinContrast = 4.5;

/// The smallest contrast a drawn thing that is not text may have: the
/// spinner in "I'm up" while the acknowledge is on its way (WCAG AA for
/// graphics).
const double alarmStyleMinGraphicContrast = 3;

/// One pair of colours a look puts on screen: [foreground] over
/// [background], and how far apart they are.
@immutable
class AlarmContrastLine {
  const AlarmContrastLine(
    this.what,
    this.foreground,
    this.background, {
    this.min = alarmStyleMinContrast,
    this.isRequired = true,
  });

  /// What it is, in a few words. Stable: a test names a line by it.
  final String what;
  final Color foreground;

  /// What is behind it, flattened: a see-through fill is laid over what it
  /// sits on first.
  final Color background;

  /// The contrast [ratio] has to reach.
  final double min;

  /// False for a line that is measured and reported and fails nothing: a
  /// pair the screen does not draw today.
  final bool isRequired;

  double get ratio => ColorContrast.contrastRatio(foreground, background);

  bool get passes => !isRequired || ratio >= min;

  @override
  String toString() => '$what ${ratio.toStringAsFixed(2)}';
}

/// "This shape must stand out from what is behind it more than that one
/// does": the order of weight of the pinned buttons.
@immutable
class AlarmWeightLine {
  const AlarmWeightLine(this.what, {required this.heavy, required this.light});

  /// What it is, in a few words. Stable: a test names a line by it.
  final String what;

  /// How far the fill that must be the heavier one is from its background.
  final double heavy;

  /// The same for the fill it must outweigh.
  final double light;

  bool get passes => heavy > light;

  @override
  String toString() =>
      '$what ${heavy.toStringAsFixed(2)} over ${light.toStringAsFixed(2)}';
}

/// What `alarmStyleContrast` found for one look, stage, theme and
/// severity.
@immutable
class AlarmContrastReport {
  const AlarmContrastReport({required this.lines, required this.weights});

  final List<AlarmContrastLine> lines;
  final List<AlarmWeightLine> weights;

  /// The name of every line that has to pass and does not.
  List<String> get failed => [
    for (final line in lines)
      if (!line.passes) line.what,
    for (final weight in weights)
      if (!weight.passes) weight.what,
  ];

  /// The same, with the numbers, for a failure message.
  List<String> get failures => [
    for (final line in lines)
      if (!line.passes) '$line is under ${line.min.toStringAsFixed(1)}',
    for (final weight in weights)
      if (!weight.passes) '$weight: it does not stand out more',
  ];

  bool get passes => failed.isEmpty;

  AlarmContrastLine? line(String what) {
    for (final line in lines) {
      if (line.what == what) return line;
    }
    return null;
  }

  AlarmWeightLine? weight(String what) {
    for (final weight in weights) {
      if (weight.what == what) return weight;
    }
    return null;
  }
}

/// The fill and label of an `AppButton` of [variant] under [colors], at
/// rest. It follows the switch in `AppButton.build`, for the variants a
/// look may use. Keep the two in step.
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

/// The fill and the spinner (or label) of an `AppButton` of [variant]
/// while it is off: loading, or with nothing to press. "I'm up" is drawn
/// like this for as long as an acknowledge is on its way. It follows the
/// second switch in `AppButton.build`. Keep the two in step.
({Color fill, Color label}) alarmButtonOffColors(
  AppButtonVariant variant,
  AppColors colors,
) => switch (variant) {
  AppButtonVariant.primary ||
  AppButtonVariant.ink ||
  AppButtonVariant.paper ||
  AppButtonVariant.crit ||
  AppButtonVariant.cream ||
  AppButtonVariant.destructive => (fill: colors.ash, label: colors.ink2),
  AppButtonVariant.ghost || AppButtonVariant.dangerText => (
    fill: const Color(0x00000000),
    label: colors.ink3,
  ),
  AppButtonVariant.tinted => (
    fill: colors.surface.withValues(alpha: 0.22),
    label: colors.ink3,
  ),
};

/// Measures what [style] puts on [stage] in the [brightness] theme: the
/// buttons and the text against what is behind them.
///
/// The colours are the ones the screen reads, from the look's own palette
/// and its canvas, so a look cannot pass here and draw something else.
/// [severity] is the incident's. It is pure, so the contrast test runs it
/// over every look in the registry.
///
/// What is behind a pinned button is one of two colours, and both are
/// measured: the look's canvas (its ambient profile) while the screen is
/// at rest, and the bar's backing (`canvas` of the stage's palette), which
/// is drawn under the buttons when the list scrolls beneath them and
/// always on the acknowledged stage. For the standard look the two differ
/// for a severity that is not critical.
///
/// The cards are measured as they are drawn: opaque. A profile also names
/// a `surfaceOpacity`, which no card reads today. The message's faintest
/// line is measured a second time on a card of that opacity and reported,
/// so the number is known before a card ever takes it up.
///
/// [behindTheStage] is for a look whose painter covers the canvas: one
/// flat colour the painter can put behind the stage, measured in place of
/// the look's canvas. Left out, the canvas is the look's own.
AlarmContrastReport alarmStyleContrast(
  AlarmStyle style,
  AlarmStage stage, {
  required Brightness brightness,
  SeverityMode severity = SeverityMode.crit,
  Color? behindTheStage,
}) {
  final base = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final colors = style.colorsFor(
    stage,
    base: base,
    severity: severity,
    brightness: brightness,
  );
  final profile = style.lookOf(stage).ambient(base, brightness);
  final canvas = behindTheStage ?? profile.canvas;
  // The two things a pinned button can have behind it.
  final behind = <(String, Color)>[
    ('the canvas', canvas),
    ('the bar backing', Color.alphaBlend(colors.canvas, canvas)),
  ];
  double off(Color fill, Color background) => ColorContrast.contrastRatio(
    Color.alphaBlend(fill, background),
    background,
  );
  final card = Color.alphaBlend(colors.surface, canvas);
  final thinCard = Color.alphaBlend(
    colors.surface.withValues(alpha: colors.surface.a * profile.surfaceOpacity),
    canvas,
  );

  switch (stage) {
    case AlarmStage.ringing:
      final look = style.ringing;
      final acknowledge = alarmButtonColors(look.acknowledgeButton, colors);
      final busy = alarmButtonOffColors(look.acknowledgeButton, colors);
      final quiet = alarmButtonColors(look.quietButton, colors);
      return AlarmContrastReport(
        lines: [
          for (final (where, background) in behind) ...[
            AlarmContrastLine(
              '"I\'m up" on its fill, over $where',
              acknowledge.label,
              Color.alphaBlend(acknowledge.fill, background),
            ),
            AlarmContrastLine(
              'the spinner in "I\'m up" on its fill, over $where',
              busy.label,
              Color.alphaBlend(busy.fill, background),
              min: alarmStyleMinGraphicContrast,
            ),
            AlarmContrastLine(
              'quiet button label on its fill, over $where',
              quiet.label,
              Color.alphaBlend(quiet.fill, background),
            ),
          ],
          AlarmContrastLine('message title on the card', colors.ink, card),
          AlarmContrastLine('message body on the card', colors.ink2, card),
          AlarmContrastLine(
            'message source line on the card',
            colors.ink3,
            card,
          ),
          AlarmContrastLine(
            'message source line on a card at the profile opacity',
            colors.ink3,
            thinCard,
            isRequired: false,
          ),
          AlarmContrastLine(
            'topic and time on the canvas',
            colors.onCanvas,
            canvas,
          ),
        ],
        weights: [
          for (final (where, background) in behind) ...[
            AlarmWeightLine(
              '"I\'m up" against the quiet buttons, over $where',
              heavy: off(acknowledge.fill, background),
              light: off(quiet.fill, background),
            ),
            AlarmWeightLine(
              '"I\'m up" while it spins against the quiet buttons, '
              'over $where',
              heavy: off(busy.fill, background),
              light: off(quiet.fill, background),
            ),
          ],
        ],
      );
    case AlarmStage.acknowledged:
      final desk = alarmButtonColors(AppButtonVariant.ghost, colors);
      final back = alarmButtonColors(AppButtonVariant.paper, colors);
      final backOff = alarmButtonOffColors(AppButtonVariant.paper, colors);
      final row = Color.alphaBlend(colors.cream, card);
      return AlarmContrastReport(
        lines: [
          AlarmContrastLine(
            'title and line on the canvas',
            colors.onCanvas,
            canvas,
          ),
          for (final (where, background) in behind) ...[
            AlarmContrastLine(
              '"At my desk" and the hint, over $where',
              desk.label,
              Color.alphaBlend(desk.fill, background),
            ),
            AlarmContrastLine(
              '"Back to topics" on its fill, over $where',
              back.label,
              Color.alphaBlend(back.fill, background),
            ),
            // No button of this stage is ever off today. Measured so one
            // that is, later, already has a fill it reads on.
            AlarmContrastLine(
              '"Back to topics" if it were off, on its fill, over $where',
              backOff.label,
              Color.alphaBlend(backOff.fill, background),
              min: alarmStyleMinGraphicContrast,
            ),
          ],
          AlarmContrastLine('detail value on its row', colors.ink, row),
          AlarmContrastLine('detail label on its row', colors.ink3, row),
        ],
        weights: const [],
      );
  }
}
