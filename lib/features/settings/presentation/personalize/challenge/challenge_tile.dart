import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/personalize/challenge_shelf_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge/challenge_tile_art.dart';
import 'package:flutter/material.dart';

/// The corner radius of a tile.
const double kChallengeTileRadius = 26;

/// The size of the pick control's touch target.
const double kChallengePickTarget = 44;

/// The ring of the pick control, inside the target.
const double _kPickRing = 28;

/// One tile of the Wake-up challenge shelf.
///
/// It has two taps. The tile (the picture and the name) is [onOpen]: it opens
/// the try, for everyone. The pick control at the right of the name strip is
/// [onPick]: it keeps the challenge for topics made from now on, or, locked,
/// opens the paywall. The control is the only badge a tile carries.
///
/// The tile knows nothing of plans. It draws [pick] and calls back.
class ChallengeTile extends StatefulWidget {
  const ChallengeTile({
    required this.tile,
    required this.pick,
    required this.name,
    required this.descriptor,
    required this.tileLabel,
    required this.tileHint,
    required this.pickLabel,
    required this.onOpen,
    required this.onPick,
    super.key,
  });

  final ShelfTile tile;
  final ShelfPick pick;

  /// What the tile is called, and the one short line under it.
  final String name;
  final String descriptor;

  /// What a screen reader says for the tile and for its control. The hint
  /// says what the tile does when it is tapped.
  final String tileLabel;
  final String tileHint;
  final String pickLabel;

  final VoidCallback onOpen;
  final VoidCallback onPick;

  @override
  State<ChallengeTile> createState() => _ChallengeTileState();
}

class _ChallengeTileState extends State<ChallengeTile> {
  bool _isPressed = false;
  bool _isFocused = false;

  void _open() {
    AppHaptics.selection();
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tile = widget.tile;
    final radius = BorderRadius.circular(kChallengeTileRadius);
    final isChosen = widget.pick == ShelfPick.chosen;

    final visuals = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          child: ChallengeTileArt(kind: tile.kind, isOffChosen: isChosen),
        ),
        Row(
          children: [
            Expanded(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 0, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style:
                              AppTypography.body(
                                colors.onPanel,
                                fontSize: 15,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.descriptor,
                          style: AppTypography.mono(
                            colors.onPanelMuted,
                            fontSize: 11,
                          ).copyWith(height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ChallengePickControl(
              pick: widget.pick,
              label: widget.pickLabel,
              onTap: widget.onPick,
            ),
          ],
        ),
      ],
    );

    final body = Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            container: true,
            button: true,
            label: widget.tileLabel,
            hint: widget.tileHint,
            onTap: _open,
            excludeSemantics: true,
            child: FocusableActionDetector(
              onShowFocusHighlight: (value) =>
                  setState(() => _isFocused = value),
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _open();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) => setState(() => _isPressed = false),
                onTapCancel: () => setState(() => _isPressed = false),
                onTap: _open,
              ),
            ),
          ),
        ),
        visuals,
        if (_isFocused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: colors.onPanel, width: 3),
                ),
              ),
            ),
          ),
      ],
    );

    final shaped = tile.isOff
        ? CustomPaint(
            foregroundPainter: _DashedBorderPainter(
              color: colors.panelLine,
              radius: kChallengeTileRadius,
            ),
            child: ClipRRect(borderRadius: radius, child: body),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: colors.panelHover,
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // A fine edge, so a dark picture does not run into the
                  // page.
                  border: Border.all(
                    color: colors.onPanel.withValues(alpha: 0.14),
                  ),
                ),
                child: body,
              ),
            ),
          );

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1,
      duration: context.motion(AppDurations.tap),
      curve: AppCurves.easeOut,
      child: shaped,
    );
  }
}

/// The control at the right of a tile's name strip: a ring that is filled
/// with a check on the chosen tile and holds a lock glyph while it is locked.
/// A 44 point target.
class ChallengePickControl extends StatefulWidget {
  const ChallengePickControl({
    required this.pick,
    required this.label,
    required this.onTap,
    super.key,
  });

  final ShelfPick pick;

  /// What a screen reader says.
  final String label;

  final VoidCallback onTap;

  @override
  State<ChallengePickControl> createState() => _ChallengePickControlState();
}

class _ChallengePickControlState extends State<ChallengePickControl> {
  bool _isFocused = false;

  void _activate() {
    AppHaptics.selection();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pick = widget.pick;
    final isChosen = pick == ShelfPick.chosen;
    final ringColor = _isFocused ? colors.onPanel : colors.onPanelMuted;
    return Semantics(
      container: true,
      button: true,
      // The tick is spoken, not only drawn.
      selected: isChosen,
      label: widget.label,
      onTap: _activate,
      excludeSemantics: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _isFocused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          child: SizedBox.square(
            dimension: kChallengePickTarget,
            child: Center(
              child: AnimatedContainer(
                duration: context.motion(AppDurations.tap),
                width: _kPickRing,
                height: _kPickRing,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChosen ? colors.yellow : null,
                  border: isChosen
                      ? null
                      : Border.all(
                          color: ringColor,
                          width: _isFocused ? 3 : 2,
                        ),
                ),
                child: Center(
                  child: switch (pick) {
                    ShelfPick.chosen => AppGlyph(
                      GlyphType.check,
                      size: 15,
                      color: colors.inkFixed,
                      strokeWidth: 3,
                    ),
                    ShelfPick.locked => AppGlyph(
                      GlyphType.lock,
                      size: 13,
                      color: colors.onPanelMuted,
                      strokeWidth: 2.4,
                    ),
                    ShelfPick.open || ShelfPick.unread => null,
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded border, for the "No challenge" tile.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _width = 2;
  static const double _dash = 7;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        final end = at + _dash;
        canvas.drawPath(
          metric.extractPath(at, end > metric.length ? metric.length : end),
          paint,
        );
        at += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
