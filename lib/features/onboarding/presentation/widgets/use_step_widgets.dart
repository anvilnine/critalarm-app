import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// The white sheet the five answers of the use step sit on: the inbox
/// sheet's corner and shadow, with no hairlines, because each row is a button
/// of its own.
class UseOptionSheet extends StatelessWidget {
  const UseOptionSheet({required this.children, super.key});

  /// Normally [UseOptionRow]s.
  final List<Widget> children;

  /// The gap between two rows.
  static const double rowGap = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppInboxSheet.radius),
        boxShadow: isDark ? const [] : AppShadows.lightMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: rowGap),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One answer: a glyph tile and two lines, all one button.
///
/// The glyph is drawing, so a screen reader skips it and reads the title and
/// then the hint. A picked row wears the cobalt tile and a pale cobalt row.
/// It grows with the text and keeps at least a full tap height.
class UseOptionRow extends StatefulWidget {
  const UseOptionRow({
    required this.glyph,
    required this.title,
    required this.hint,
    required this.isPicked,
    required this.onTap,
    super.key,
  });

  /// The two or three characters drawn on the tile.
  final String glyph;
  final String title;
  final String hint;
  final bool isPicked;

  /// Null while the step is already moving on.
  final VoidCallback? onTap;

  /// The row's height on the board, at the default text size.
  static const double minHeight = 70;

  @override
  State<UseOptionRow> createState() => _UseOptionRowState();
}

class _UseOptionRowState extends State<UseOptionRow> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value && mounted) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPicked = widget.isPicked;
    final fill = isPicked
        ? colors.cobaltTint
        : _isPressed
        ? colors.cream
        : colors.surface;
    final glyphStyle = AppTypography.monoBold(
      isPicked ? colors.onHighlight : colors.yellow,
      fontSize: 15,
    ).copyWith(height: 1);
    return Semantics(
      button: true,
      selected: isPicked,
      enabled: widget.onTap != null,
      label: '${widget.title}. ${widget.hint}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        // The pick shows at once. The step fades out right after it, so a
        // colour that tweens in would never be seen.
        child: Container(
          constraints: const BoxConstraints(minHeight: UseOptionRow.minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s3,
            vertical: Spacing.s2,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPicked ? colors.highlight : colors.inkFixed,
                  borderRadius: BorderRadius.circular(14),
                ),
                // Drawing only. The title and the hint say what it means.
                child: ExcludeSemantics(
                  // The tile keeps its size when the text grows.
                  child: MediaQuery.withNoTextScaling(
                    child: Text(widget.glyph, style: glyphStyle),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.body(colors.onSurface, fontSize: 17)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.hint,
                      style: AppTypography.mono(
                        colors.onSurfaceMuted,
                        fontSize: 12,
                      ).copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The word `skip` at the far end of the top bar. A small mono word that
/// keeps a full tap area around it.
class UseSkipButton extends StatelessWidget {
  const UseSkipButton({required this.label, required this.onTap, super.key});

  /// The spoken word. It is drawn in capitals.
  final String label;

  /// Null while the step is already moving on.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AppTapTarget(
        onTap: onTap,
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          style: AppTypography.monoBold(
            colors.onCanvasMuted,
            fontSize: 11,
          ).copyWith(letterSpacing: 0.88, height: 1.2),
        ),
      ),
    );
  }
}
