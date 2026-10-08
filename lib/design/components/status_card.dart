import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// The colour of a numeral or a foot line on the dark card.
enum AppStatusTone {
  /// Yellow: everything is as it should be.
  yellow,

  /// Quiet. Nothing to report, or nothing known yet.
  muted,

  /// Orange: a check needs a look.
  orange,

  /// The lighter orange, for a warning on the orange canvas.
  orangeSoft,

  /// Red: an alarm may not ring, an alarm was missed, or one is ringing.
  red;

  /// The text colour on the card.
  Color color(AppColors colors) => switch (this) {
    AppStatusTone.yellow => colors.yellow,
    AppStatusTone.muted => colors.onPanelMuted,
    AppStatusTone.orange => colors.high,
    AppStatusTone.orangeSoft => colors.highAlt,
    AppStatusTone.red => colors.critAlt,
  };
}

/// How the card is laid out.
enum AppStatusVariant {
  /// Label, numeral, pips, foot and action stacked. Topics and Topic.
  full,

  /// A small face on the left, the numeral on the right. Settings.
  strip,
}

/// The surface of the card in a theme.
///
/// In the light theme the card is the dark panel. In the dark theme the panel
/// is darker than the canvas by only 1.06 to 1, so the card would vanish.
/// There it takes the elevated surface, one step lighter than the canvas,
/// and a faint outline around the edge.
({Color fill, Color? line}) statusCardSurface(
  AppColors colors,
  Brightness brightness,
) => brightness == Brightness.dark
    ? (fill: colors.surfaceElevated, line: colors.panelLine)
    : (fill: colors.panel, line: null);

/// The dark card that answers one question on a screen.
///
/// A mono label, a big numeral, optional pips, a mono foot and an optional
/// full width action. [AppStatusCard.strip] is the Settings version with a
/// 40 point face. The card takes plain values and owns none of the words:
/// the screen decides which kind of thing it is saying.
///
/// - The numeral is fitted to one line.
/// - When [numeral] changes while the card is on screen it pops once
///   ([AppCurves.easeBack] over [AppDurations.slow]). It never pops when the
///   card first builds. Pass false for [popsOnChange] for a numeral that ticks
///   every second.
/// - A press on the card shrinks it to 0.97 when it has an [onTap].
/// - [trailing] sits at the right of the numeral, for the Topic switch.
///
/// The card is one node for a screen reader: label, numeral, foot. The action
/// and [trailing] stay separate controls. Pass [numeralLabel] when the
/// numeral reads badly aloud (`7/7`, `2:17`). Set [liveRegion] on a card whose
/// kind changes while it is on screen, and keep [numeralLabel] free of the
/// ticking part so only the change of state is announced.
class AppStatusCard extends StatefulWidget {
  /// The full card.
  const AppStatusCard({
    required this.numeral,
    this.label,
    this.numeralTone = AppStatusTone.yellow,
    this.foot,
    this.footTone = AppStatusTone.muted,
    this.pips,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.trailing,
    this.numeralLabel,
    this.popsOnChange = true,
    this.liveRegion = false,
    super.key,
  }) : variant = AppStatusVariant.full,
       face = null,
       title = null,
       assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  /// The Settings strip: [face] on the left, [numeral] on the right, [label]
  /// and [title] and [foot] between them.
  const AppStatusCard.strip({
    required this.face,
    required this.numeral,
    this.label,
    this.title,
    this.numeralTone = AppStatusTone.yellow,
    this.foot,
    this.footTone = AppStatusTone.muted,
    this.pips,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.numeralLabel,
    this.popsOnChange = true,
    this.liveRegion = false,
    super.key,
  }) : variant = AppStatusVariant.strip,
       trailing = null,
       assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  final AppStatusVariant variant;

  /// The mono caps line above the numeral. Null leaves it out.
  final String? label;

  /// The big text: a count, a time, a word. Fitted to one line.
  final String numeral;

  /// The numeral's colour.
  final AppStatusTone numeralTone;

  /// The mono line under the numeral. One line, cut with an ellipsis.
  final String? foot;

  /// The foot's colour.
  final AppStatusTone footTone;

  /// One pip per check, drawn under the numeral. Null draws none.
  final List<AppPipTone>? pips;

  /// The action pill's label. Null draws no action.
  final String? actionLabel;

  /// What the action does.
  final VoidCallback? onAction;

  /// Taps on the card body. Null makes the body inert.
  final VoidCallback? onTap;

  /// A control at the right of the numeral (full variant only).
  final Widget? trailing;

  /// The strip's face (strip variant only).
  final FaceState? face;

  /// The strip's headline, between the label and the foot.
  final String? title;

  /// What a screen reader says for the numeral. Defaults to [numeral].
  final String? numeralLabel;

  /// False for a numeral that changes every second.
  final bool popsOnChange;

  /// True announces the card's words when they change.
  final bool liveRegion;

  @override
  State<AppStatusCard> createState() => _AppStatusCardState();
}

class _AppStatusCardState extends State<AppStatusCard>
    with SingleTickerProviderStateMixin {
  /// Runs 0 to 1 when the numeral steps. Rests at 1.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
    value: 1,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.82,
    end: 1,
  ).animate(CurvedAnimation(parent: _pop, curve: AppCurves.easeBack));

  bool _isPressed = false;

  @override
  void didUpdateWidget(covariant AppStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.numeral != oldWidget.numeral &&
        widget.label == oldWidget.label &&
        widget.popsOnChange &&
        !context.reduceMotion) {
      _pop.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  TextStyle _label(Color color) => TextStyle(
    fontFamily: AppTypography.fontMono,
    fontFamilyFallback: AppTypography.fontMonoFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.88,
    color: color,
  );

  TextStyle _foot(Color color) => TextStyle(
    fontFamily: AppTypography.fontMono,
    fontFamilyFallback: AppTypography.fontMonoFallbacks,
    fontSize: 11.5,
    height: 1.3,
    color: color,
  );

  TextStyle _numeral(Color color, double size) => TextStyle(
    fontFamily: AppTypography.fontDisplay,
    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
    fontWeight: FontWeight.w800,
    fontSize: size,
    height: 1.05,
    letterSpacing: -0.03 * size,
    color: color,
  );

  TextStyle _stripTitle(Color color) => TextStyle(
    fontFamily: AppTypography.fontBody,
    fontFamilyFallback: AppTypography.fontBodyFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.25,
    color: color,
  );

  /// Lines the stacked title may take. Far more than any title needs, so it
  /// never loses a word.
  static const int _stripStackedTitleLines = 8;

  /// The widest the strip's numeral gets beside the title.
  static const double _stripNumeralMaxWidth = 110;

  /// Whether the strip's title keeps all its words in two lines with the
  /// numeral at the end of the row. [width] is the strip's inner width.
  ///
  /// It measures the title and the numeral with the text size the strip is
  /// drawn at. When it does not fit, the numeral stacks under the title and
  /// the title has the whole column.
  bool _stripFitsInARow(BuildContext context, double width, AppColors colors) {
    final title = widget.title;
    if (title == null) return true;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final numeral = TextPainter(
      text: TextSpan(
        text: widget.numeral,
        style: _numeral(colors.onPanel, 40),
      ),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final numeralWidth = numeral.width < _stripNumeralMaxWidth
        ? numeral.width
        : _stripNumeralMaxWidth;
    numeral.dispose();
    // Face 40, gap 14 before the column, gap 10 after it.
    final columnWidth = width - 40 - 14 - 10 - numeralWidth;
    if (columnWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: title, style: _stripTitle(colors.onPanel)),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 2,
    )..layout(maxWidth: columnWidth);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  /// Text that is chrome (label, foot) stops growing at the chrome limit.
  Widget _capped(BuildContext context, Widget child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: kChromeMaxTextScale),
    ),
    child: child,
  );

  Widget _cross(Widget child, Object key) => ExcludeSemantics(
    child: AnimatedSwitcher(
      duration: context.motion(AppDurations.base),
      switchInCurve: AppCurves.easeOut,
      switchOutCurve: AppCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.of(context).brightness;
    final surface = statusCardSurface(colors, brightness);
    final isStrip = widget.variant == AppStatusVariant.strip;
    final hasAction = widget.actionLabel != null;

    final labelText = widget.label;
    final numeralColor = widget.numeralTone.color(colors);
    final numeralSize = isStrip ? 40.0 : 50.0;

    final labelWidget = labelText == null
        ? null
        : _capped(
            context,
            _cross(
              Text(
                labelText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _label(colors.onPanelMuted),
              ),
              labelText,
            ),
          );

    Widget numeralAt(Alignment alignment) => ExcludeSemantics(
      child: ScaleTransition(
        scale: _scale,
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            widget.numeral,
            maxLines: 1,
            softWrap: false,
            style: _numeral(numeralColor, numeralSize),
          ),
        ),
      ),
    );
    final numeralWidget = numeralAt(
      isStrip ? Alignment.centerRight : Alignment.centerLeft,
    );

    final footWidget = widget.foot == null
        ? null
        : _capped(
            context,
            _cross(
              Text(
                widget.foot!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _foot(widget.footTone.color(colors)),
              ),
              widget.foot!,
            ),
          );

    final pips = widget.pips;
    final pipsWidget = pips == null || pips.isEmpty
        ? null
        : AppReadinessPips(tones: pips);

    final Widget top;
    if (isStrip) {
      Widget face() => ExcludeSemantics(
        child: FaceWidget(
          state: widget.face!,
          size: 40,
          overrideFillColor: colors.yellow,
          overrideStrokeColor: colors.inkFixed,
          overrideInkColor: colors.inkFixed,
        ),
      );
      Widget title({required int maxLines}) => ExcludeSemantics(
        child: Text(
          widget.title!,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: _stripTitle(colors.onPanel),
        ),
      );
      top = LayoutBuilder(
        builder: (context, box) {
          final inRow = _stripFitsInARow(context, box.maxWidth, colors);
          return Row(
            crossAxisAlignment: inRow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              face(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?labelWidget,
                    if (widget.title != null) ...[
                      const SizedBox(height: 3),
                      // Stacked, the title has the whole column and keeps
                      // every word, however many lines that takes.
                      title(maxLines: inRow ? 2 : _stripStackedTitleLines),
                    ],
                    // Stacked, the numeral sits under the title.
                    if (!inRow) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _stripNumeralMaxWidth,
                          ),
                          child: numeralAt(Alignment.centerLeft),
                        ),
                      ),
                    ],
                    if (footWidget != null) ...[
                      const SizedBox(height: 2),
                      footWidget,
                    ],
                  ],
                ),
              ),
              if (inRow) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _stripNumeralMaxWidth,
                  ),
                  child: numeralWidget,
                ),
              ],
            ],
          );
        },
      );
    } else {
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?labelWidget,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(child: numeralWidget),
                if (widget.trailing != null) ...[
                  const SizedBox(width: Spacing.s3),
                  widget.trailing!,
                ],
              ],
            ),
          ),
          if (pipsWidget != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: pipsWidget,
            ),
          if (footWidget != null)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: footWidget,
            ),
        ],
      );
    }

    final spoken = [
      ?widget.label,
      ?widget.title,
      widget.numeralLabel ?? widget.numeral,
      ?widget.foot,
    ].join(', ');

    final body = Semantics(
      container: true,
      liveRegion: widget.liveRegion,
      button: widget.onTap != null,
      onTap: widget.onTap,
      label: spoken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          top,
          if (isStrip && pipsWidget != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: pipsWidget,
            ),
          if (hasAction)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppButton(
                label: widget.actionLabel!,
                isFullWidth: true,
                onPressed: widget.onAction,
              ),
            ),
        ],
      ),
    );

    final isDark = brightness == Brightness.dark;
    final card = AnimatedScale(
      scale: _isPressed ? 0.97 : 1,
      duration: context.motion(AppDurations.tap),
      curve: AppCurves.easeOut,
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: body,
        ),
      ),
    );

    if (widget.onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: card,
    );
  }
}
