import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:flutter/material.dart';

/// One line of the slip: what it says, what a screen reader adds, and what
/// a tap on it does.
class ReceiptLine {
  const ReceiptLine({
    required this.text,
    required this.label,
    required this.onTap,
  });

  final String text;
  final String label;
  final VoidCallback onTap;
}

/// The colours of the slip and its slot. Paper is light in both themes:
/// on the dark canvas a dark slip did not read as paper. So in the dark
/// theme the paper takes the canvas's light ink colour and its type the
/// fixed dark ink.
class ReceiptInks {
  const ReceiptInks({
    required this.paper,
    required this.ink,
    required this.quiet,
    required this.faint,
    required this.slot,
    required this.slit,
  });

  factory ReceiptInks.of(BuildContext context) {
    final colors = context.appColors;
    if (Theme.of(context).brightness != Brightness.dark) {
      return ReceiptInks(
        paper: colors.cream,
        ink: colors.ink,
        quiet: colors.ink2,
        faint: colors.ink3,
        slot: colors.onCanvas,
        slit: colors.canvas.withValues(alpha: 0.36),
      );
    }
    return ReceiptInks(
      paper: colors.onCanvas,
      ink: colors.inkFixed,
      quiet: colors.inkFixed.withValues(alpha: 0.82),
      faint: colors.inkFixed.withValues(alpha: 0.55),
      slot: colors.ink3,
      slit: colors.inkFixed.withValues(alpha: 0.5),
    );
  }

  /// The paper, and the type on it from strongest to faintest.
  final Color paper;
  final Color ink;
  final Color quiet;
  final Color faint;

  /// The slot the paper hangs from, and the opening along it.
  final Color slot;
  final Color slit;
}

/// The printed slip: a header, one ticked line per benefit in the mono
/// face, a dashed rule, the product's name and the price as the total, and
/// a stamp.
///
/// It draws the moment it is given and holds no time. [out] is how much of
/// the paper has left the slot, in points. [inks] is how far each part is
/// printed: the header, each line, then the total. [active] is the line
/// the stage is playing, marked as with a highlighter: [marker] is how
/// solid that mark is.
class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({
    required this.plan,
    required this.title,
    required this.lines,
    required this.name,
    required this.price,
    required this.stampText,
    required this.active,
    this.out,
    this.inks,
    this.marker = 1,
    this.stamp = const ReceiptStamp(
      opacity: 1,
      scale: 1,
      angle: ReceiptTimeline.stampAngle,
    ),
    super.key,
  });

  final ReceiptPlan plan;
  final String title;
  final List<ReceiptLine> lines;
  final String name;

  /// The price of the plan picked. Null while the store has none.
  final String? price;
  final String stampText;
  final int active;

  /// Null is the whole paper.
  final double? out;

  /// Null is everything printed.
  final List<double>? inks;
  final double marker;
  final ReceiptStamp stamp;

  /// The slip's type grows this much with the text size and no further.
  static const double maxTextScale = 1.3;

  double _ink(int part) => inks == null ? 1 : inks![part];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final inks = ReceiptInks.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = plan.paper.size;
    final shown = math.min(out ?? size.height, size.height);
    const pad = ReceiptPlan.pad;
    // Every line is one size: the one the longest line fits at. The lines
    // have no room to grow into, so the text size is taken back out of
    // them. The header and the total still grow with it.
    final grown = math.min(
      MediaQuery.textScalerOf(context).scale(10) / 10,
      maxTextScale,
    );
    final longest = lines.fold<int>(
      0,
      (most, line) => math.max(most, line.text.length),
    );
    final fontSize = plan.lineFont(longest) / math.max(1, grown);
    final strong = AppTypography.monoBold(
      inks.ink,
      fontSize: fontSize,
    ).copyWith(height: 1.2);
    final quiet = AppTypography.mono(
      inks.quiet,
      fontSize: fontSize,
    ).copyWith(height: 1.2);
    final totalStyle = AppTypography.monoBold(
      inks.ink,
      fontSize: 14.5,
    ).copyWith(height: 1.2);

    // The slip is a picture of a slip: its type grows a little with the
    // text size and no further, and every line says itself to a reader.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _PaperPainter(
                    out: shown,
                    color: inks.paper,
                    shadows: AppShadows.shadowLg(isDark: isDark),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRect(
                clipper: _TopClipper(shown - ReceiptPlan.tear),
                child: Stack(
                  children: [
                    // The highlighter over the line being played.
                    AnimatedPositioned(
                      duration: context.motion(AppDurations.base),
                      curve: AppCurves.easeOut,
                      left: pad - 7,
                      right: pad - 7,
                      top: plan.rowsTop + plan.row * active + 3,
                      height: plan.row - 6,
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: marker,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.yellow.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(Radii.xs),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: pad,
                      right: pad,
                      top: ReceiptPlan.lead,
                      height: ReceiptPlan.header,
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: _ink(0),
                          child: Center(
                            child: Text(
                              title.toUpperCase(),
                              maxLines: 1,
                              style: AppTypography.monoBold(
                                inks.quiet,
                                fontSize: 10.5,
                              ).copyWith(letterSpacing: 2.4, height: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _rule(plan.rowsTop - ReceiptPlan.rule, inks.faint, 0),
                    for (final (i, line) in lines.indexed)
                      Positioned(
                        left: pad,
                        right: pad,
                        top: plan.rowsTop + plan.row * i,
                        height: plan.row,
                        child: Opacity(
                          opacity: _ink(i + 1),
                          child: Semantics(
                            label: '${line.text}. ${line.label}',
                            button: true,
                            selected: i == active,
                            onTap: line.onTap,
                            excludeSemantics: true,
                            child: Row(
                              children: [
                                AppGlyph(
                                  GlyphType.check,
                                  size: ReceiptPlan.tick,
                                  color: inks.ink,
                                  strokeWidth: 2.4,
                                ),
                                const SizedBox(width: ReceiptPlan.tickGap),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: AnimatedDefaultTextStyle(
                                      duration: context.motion(
                                        AppDurations.base,
                                      ),
                                      style: i == active ? strong : quiet,
                                      child: Text(line.text, maxLines: 1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    _rule(
                      plan.totalTop - ReceiptPlan.rule,
                      inks.faint,
                      lines.length + 1,
                    ),
                    Positioned(
                      left: pad,
                      right: pad,
                      top: plan.totalTop,
                      height: ReceiptPlan.total,
                      child: Opacity(
                        opacity: _ink(lines.length + 1),
                        child: Semantics(
                          label: price == null ? name : '$name, $price',
                          excludeSemantics: true,
                          child: Row(
                            children: [
                              Text(name, maxLines: 1, style: totalStyle),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    price ?? '',
                                    maxLines: 1,
                                    style: totalStyle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (stamp.opacity > 0)
              Positioned(
                left: pad,
                right: pad,
                top: plan.stampTop,
                height: ReceiptPlan.stampRoom - 4,
                child: ExcludeSemantics(
                  child: Align(
                    alignment: const Alignment(0.72, 0),
                    child: Opacity(
                      opacity: stamp.opacity,
                      child: Transform.rotate(
                        angle: stamp.angle,
                        child: Transform.scale(
                          scale: stamp.scale,
                          child: _StampMark(
                            text: stampText,
                            color: colors.crit,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rule(double top, Color color, int part) => Positioned(
    left: ReceiptPlan.pad,
    right: ReceiptPlan.pad,
    top: top,
    height: ReceiptPlan.rule,
    child: ExcludeSemantics(
      child: Opacity(
        opacity: _ink(part),
        child: CustomPaint(painter: _DashPainter(color)),
      ),
    ),
  );
}

/// The rubber stamp: the product's name in a double frame.
class _StampMark extends StatelessWidget {
  const _StampMark({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2.2),
        borderRadius: BorderRadius.circular(Radii.xs + 2),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          style: AppTypography.monoBold(
            color,
            fontSize: 15,
          ).copyWith(letterSpacing: 2.6, height: 1.2),
        ),
      ),
    );
  }
}

/// Keeps what is above [height] points down the box.
class _TopClipper extends CustomClipper<Rect> {
  const _TopClipper(this.height);

  final double height;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, math.max(0, height));

  @override
  bool shouldReclip(_TopClipper old) => height != old.height;
}

/// The paper down to [out] points, with a torn edge along its foot, on its
/// shadow.
class _PaperPainter extends CustomPainter {
  const _PaperPainter({
    required this.out,
    required this.color,
    required this.shadows,
  });

  final double out;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (out <= 0) return;
    const tooth = 5.0;
    final teeth = (size.width / 9).round();
    final step = size.width / teeth;
    final foot = math.max(tooth, out);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, foot - tooth);
    for (var i = teeth - 1; i >= 0; i--) {
      path
        ..lineTo(step * (i + 0.5), foot)
        ..lineTo(step * i, foot - tooth);
    }
    path.close();
    for (final shadow in shadows) {
      canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      out != old.out || color != old.color || shadows != old.shadows;
}

/// A dashed rule across the middle of the box.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => color != old.color;
}
