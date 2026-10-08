import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:flutter/material.dart';

/// The round mark at the left of a History row: a cobalt tick for an alarm
/// someone answered, a red bang for one nobody answered or that still rings.
///
/// The row speaks the state for a screen reader, so the mark is silent.
class HistoryMarkBadge extends StatelessWidget {
  const HistoryMarkBadge({required this.mark, super.key});

  final HistoryMark mark;

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final answered = mark == HistoryMark.answered;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: answered ? colors.highlight : colors.crit,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: answered
                ? AppGlyph(
                    GlyphType.check,
                    size: 16,
                    strokeWidth: 3.2,
                    color: colors.onHighlight,
                  )
                : CustomPaint(
                    size: const Size.square(16),
                    painter: _BangPainter(colors.inkFixed),
                  ),
          ),
        ),
      ),
    );
  }
}

/// An exclamation mark drawn on a 16 point square.
class _BangPainter extends CustomPainter {
  const _BangPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    canvas
      ..drawLine(
        Offset(x, size.height * 0.1),
        Offset(x, size.height * 0.6),
        paint,
      )
      ..drawLine(
        Offset(x, size.height * 0.9),
        Offset(x, size.height * 0.9),
        paint,
      );
  }

  @override
  bool shouldRepaint(_BangPainter old) => old.color != color;
}

/// One alarm in the History sheet: the mark, the topic, what happened and the
/// time. It sits flat on the white sheet, divided from its neighbours by the
/// sheet's hairlines.
class HistoryRow extends StatefulWidget {
  const HistoryRow({
    required this.name,
    required this.meta,
    required this.time,
    required this.mark,
    required this.markLabel,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  /// The topic, in mono. One line.
  final String name;

  /// What happened: how long it rang and how it ended. Two lines at most.
  final String meta;

  /// The clock time the alarm started.
  final String time;

  final HistoryMark mark;

  /// What a screen reader says for the mark.
  final String markLabel;

  /// True for the row open in the detail pane on a two pane display.
  final bool isSelected;

  final VoidCallback? onTap;

  @override
  State<HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<HistoryRow> {
  bool _isPressed = false;

  static const double _pressScale = 0.985;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final dropsTime = scale > kChromeMaxTextScale;

    final nameStyle = TextStyle(
      fontFamily: AppTypography.fontMono,
      fontFamilyFallback: AppTypography.fontMonoFallbacks,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.3,
      color: colors.ink,
    );
    final timeStyle = TextStyle(
      fontFamily: AppTypography.fontMono,
      fontFamilyFallback: AppTypography.fontMonoFallbacks,
      fontSize: 12,
      height: 1.3,
      color: colors.ink3,
    );
    final metaStyle = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontSize: 13.5,
      height: 1.35,
      color: colors.ink2,
    );

    final name = Text(
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );
    final time = Text(
      widget.time,
      maxLines: 1,
      softWrap: false,
      style: timeStyle,
    );

    final row = AnimatedScale(
      scale: _isPressed ? _pressScale : 1,
      duration: context.motion(AppDurations.tap),
      curve: AppCurves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? colors.cobaltTint.withValues(alpha: 0.6)
              : null,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistoryMarkBadge(mark: widget.mark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dropsTime) ...[name, time] else name,
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        widget.meta,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                  ],
                ),
              ),
              if (!dropsTime) ...[
                const SizedBox(width: 10),
                Padding(padding: const EdgeInsets.only(top: 2), child: time),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label: [
        widget.name,
        widget.markLabel,
        widget.meta,
        widget.time,
      ].join(', '),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null
              ? null
              : (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}
