import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:flutter/material.dart';

/// The door starts to swing open: one tick and one light tap, once.
void doorsOpenCue() {
  AppHaptics.selection();
  getIt<PaywallCues>().tick();
}

/// The hand puts another benefit in the doorway and the door opens wider
/// for it: one tick and one light tap. The loop doing it is silent.
void doorsWidenCue() {
  AppHaptics.selection();
  getIt<PaywallCues>().tick();
}

/// The corner of the doorway and of the door, and the weight of their
/// outline, in points.
const double _doorRadius = 10;
const double _doorStroke = 3;

/// The colours of the doorway and the door on the app's canvas, in the
/// current theme.
@immutable
class DoorsColors {
  const DoorsColors({
    required this.light,
    required this.glow,
    required this.rays,
    required this.frame,
    required this.door,
    required this.panel,
  });

  factory DoorsColors.of(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DoorsColors(
      // Light in the doorway: the canvas, brighter. The dark canvas gets a
      // glow of the yellow, so the doorway is the brightest thing on it.
      light: isDark
          ? Color.alphaBlend(c.yellow.withValues(alpha: 0.26), c.canvas)
          : c.canvasAlt,
      glow: isDark
          ? Color.alphaBlend(c.yellow.withValues(alpha: 0.4), c.canvas)
          : Color.alphaBlend(c.surface.withValues(alpha: 0.5), c.canvasAlt),
      rays: isDark ? c.yellow.withValues(alpha: 0.2) : c.canvasGhostStrong,
      // The mascot's own outline, so the door is drawn by the same hand.
      frame: c.faceStroke,
      door: isDark
          ? Color.alphaBlend(c.onCanvas.withValues(alpha: 0.12), c.canvas)
          : c.cream,
      panel: c.faceStroke.withValues(alpha: isDark ? 0.4 : 0.22),
    );
  }

  /// What fills the doorway, the disc of light behind the preview, and
  /// the rays around it.
  final Color light;
  final Color glow;
  final Color rays;

  /// The outline of the doorway and of the door, and the door's knob.
  final Color frame;

  /// The face of the door, and the lines of its two panels.
  final Color door;
  final Color panel;
}

/// The stage of the doors layout: one doorway on the app's canvas with
/// light and turning rays in it, the door swung open beside it, the
/// benefit's preview standing in the doorway and the mascot in front,
/// holding the door.
///
/// The door starts shut, gives a little, and swings open. It then rests a
/// step wider for each benefit and swings back when the loop comes round.
/// It is drawn from the front: a door at rest is a plain upright shape,
/// and its free edge tapers only while it swings.
///
/// It answers the hand as the kit's stage does: a swipe goes to the next
/// benefit or the one before, a tap plays the current one again.
class DoorsStage extends StatefulWidget {
  const DoorsStage({
    required this.player,
    required this.size,
    required this.geometry,
    required this.count,
    required this.label,
    this.lead = 0,
    super.key,
  });

  final HeroPlayer player;
  final Size size;
  final DoorsGeometry geometry;

  /// How many benefits take turns in the doorway.
  final int count;

  /// What a screen reader says the stage shows at a frame.
  final String? Function(HeroFrame frame) label;

  /// The head start of the entrance after an intro. See `doorsLeadFor`.
  final double lead;

  @override
  State<DoorsStage> createState() => _DoorsStageState();
}

class _DoorsStageState extends State<DoorsStage> {
  late double _before = _player.clock.value;
  late final bool _isMuted = PaywallMuted.of(context);

  HeroPlayer get _player => widget.player;

  // The opening's cue, on the frame the door starts to swing. After an
  // intro the door is already moving and the hand over has its own cue.
  void _onTick() {
    final clock = _player.clock;
    final now = clock.value;
    final opens = doorsReached(
      _before,
      now,
      DoorsTimeline.prelude - widget.lead,
    );
    _before = now;
    final isOwn = widget.lead == 0;
    if (opens && isOwn && !clock.isStill && !_isMuted) doorsOpenCue();
  }

  @override
  void initState() {
    super.initState();
    _player.clock.addListener(_onTick);
  }

  @override
  void didUpdateWidget(DoorsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.player.clock;
    if (identical(was, _player.clock)) return;
    was.removeListener(_onTick);
    _player.clock.addListener(_onTick);
    _before = _player.clock.value;
  }

  @override
  void dispose() {
    _player.clock.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final geometry = widget.geometry;
    final doorway = geometry.doorway;
    final mascot = geometry.arrangement.mascot;
    final card = geometry.arrangement.card;
    final colors = DoorsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.count;

    return HeroTouchArea(
      player: _player,
      child: RepaintBoundary(
        child: PaywallClockBuilder(
          clock: _player.clock,
          builder: (context, t, _) {
            final frame = _player.frameAt(t);
            final isStill = _player.isStill;
            final e = frame.entrance;
            final index = math.min(frame.activeIndex, math.max(0, count - 1));
            final before = frame.previous?.index;
            final previous = before != null && before < count ? before : null;
            final open = isStill ? 1.0 : DoorsTimeline.open(t + widget.lead);

            final shape = doorsLeafShapeFor(
              angle: doorsAngleAt(
                open: open,
                index: index,
                count: count,
                previous: previous,
                enter: frame.cardEnter,
                maxReach: geometry.maxReach,
              ),
              width: doorway.width,
              height: doorway.height,
              swing: isStill
                  ? 1
                  : doorsSwingAt(
                      open: open,
                      index: index,
                      previous: previous,
                      enter: frame.cardEnter,
                    ),
            );

            // The preview follows the mascot in, as on the approved stage.
            final cardArrive = AppCurves.easeBack.transform(
              phase(e, 0.42, 0.92),
            );
            final footDrop = size.height - mascot.top;
            final pose = heroEntrancePose(
              doorsMotion.entrance,
              e,
              size: mascot.width,
              footDrop: footDrop,
            );

            return Semantics(
              container: true,
              image: true,
              label: widget.label(frame),
              child: ExcludeSemantics(
                child: SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fromRect(
                        rect: doorway,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(_doorRadius),
                          ),
                          child: ColoredBox(
                            color: colors.light,
                            child: CustomPaint(
                              painter: HeroAtmospherePainter(
                                focus: card.center - doorway.topLeft,
                                radius: card.width * 0.6,
                                seconds: _player.stageSeconds(t),
                                entrance: e,
                                showsShapes: true,
                                disc: colors.glow,
                                soft: colors.rays,
                                strong: colors.rays,
                                light: colors.rays,
                                style: doorsMotion.atmosphere,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DoorPainter(
                            doorway: doorway,
                            shape: shape,
                            frame: colors.frame,
                            door: colors.door,
                            panel: colors.panel,
                          ),
                        ),
                      ),
                      if (frame.scene != null)
                        Positioned.fromRect(
                          rect: card,
                          child: Opacity(
                            opacity: phase(e, 0.42, 0.6),
                            child: Transform.translate(
                              offset: Offset(
                                28 * (1 - cardArrive) + _player.pullAt(t),
                                0,
                              ),
                              child: Transform.scale(
                                scale: 0.82 + 0.18 * cardArrive,
                                child: _DoorsCard(
                                  size: card.size,
                                  frame: frame,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fromRect(
                        rect: mascot,
                        child: ClipRect(
                          // A look over the foot of the stage shows
                          // nothing below it, where the words are.
                          clipper: _AboveFoot(
                            pose.clipsAtFoot ? footDrop : null,
                          ),
                          child: HeroMascot.frame(
                            frame,
                            size: mascot.width,
                            motion: doorsMotion,
                            footDrop: footDrop,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hides what is below [foot] points down its child. With no foot it
/// hides nothing.
class _AboveFoot extends CustomClipper<Rect> {
  const _AboveFoot(this.foot);

  final double? foot;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-4000, -4000, 4000, foot ?? 4000);

  @override
  bool shouldReclip(_AboveFoot old) => foot != old.foot;
}

/// The preview of the turn in the doorway, lifted off it. A new one
/// arrives as the motion says: it turns over like a door.
class _DoorsCard extends StatelessWidget {
  const _DoorsCard({
    required this.size,
    required this.frame,
    required this.isDark,
  });

  final Size size;
  final HeroFrame frame;
  final bool isDark;

  Widget _face(HeroCardPose pose, HeroScene scene, double? playFrom) {
    final preview = scene.preview;
    final Widget picture = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          extrasPreviewRadius(size.shortestSide),
        ),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: preview == null
          ? SizedBox.fromSize(size: size)
          : PaywallPreview(
              preview,
              sizeClass: PaywallPreviewClass.large,
              size: size,
              playFrom: playFrom,
            ),
    );
    return Transform.translate(
      offset: Offset(pose.dx, 0),
      child: Opacity(
        opacity: pose.opacity,
        child: Transform.scale(
          scale: pose.scale,
          // A card that is flat is left alone.
          child: pose.turn == 0
              ? picture
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(pose.turn),
                  child: picture,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = frame.previous;
    final enter = frame.cardEnter;
    final pose = heroCardArrivalPose(
      doorsMotion.arrival,
      enter,
      width: size.width,
      direction: frame.direction,
      pull: frame.pull,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (previous != null && enter < 1)
          KeyedSubtree(
            key: ValueKey(frame.previousTurn),
            child: _face(pose.outgoing, previous, frame.previousPlayFrom),
          ),
        KeyedSubtree(
          key: ValueKey(frame.turn),
          child: _face(pose.incoming, frame.scene!, frame.playFrom),
        ),
      ],
    );
  }
}

/// The doorway's frame and the door on its hinge, which is the doorway's
/// left edge. Shut, the door covers the doorway. Open, it lies out over
/// the wall on the other side of the hinge.
class _DoorPainter extends CustomPainter {
  const _DoorPainter({
    required this.doorway,
    required this.shape,
    required this.frame,
    required this.door,
    required this.panel,
  });

  final Rect doorway;
  final DoorsLeafShape shape;
  final Color frame;
  final Color door;
  final Color panel;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(_doorRadius);
    final outline = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = _doorStroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndCorners(doorway, topLeft: radius, topRight: radius),
      outline,
    );

    // The leaf, from its hinge to its free edge. Edge on it keeps the
    // thickness of a door.
    final hinge = doorway.left;
    final free = hinge + shape.extent;
    final left = math.min(hinge, free) - doorsLeafEdge / 2;
    final right = math.max(hinge, free) + doorsLeafEdge / 2;
    final isOverWall = shape.extent < 0;
    final taper = shape.taper;
    final top = doorway.top;
    final bottom = doorway.bottom;

    final Path leaf;
    if (taper == 0) {
      leaf = Path()
        ..addRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(left, top, right, bottom),
            topLeft: radius,
            // Open, its hinge side is square against the frame.
            topRight: isOverWall ? Radius.zero : radius,
          ),
        );
    } else {
      // Swinging: the free edge is drawn in a little at the top and the
      // bottom. It is square again when the door stops.
      final freeX = isOverWall ? left : right;
      final hingeX = isOverWall ? right : left;
      leaf = Path()
        ..moveTo(hingeX, top)
        ..lineTo(hingeX, bottom)
        ..lineTo(freeX, bottom - taper)
        ..lineTo(freeX, top + taper)
        ..close();
    }
    canvas
      ..drawPath(leaf, Paint()..color = door)
      ..drawPath(leaf, outline);

    // Two panels and a knob, once the face is wide enough to carry them.
    final width = right - left;
    if (width < 36) return;
    final inset = math.min<double>(12, width * 0.2);
    final panelPaint = Paint()
      ..color = panel
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final inner = Rect.fromLTRB(
      left + inset,
      top + inset + taper,
      right - inset,
      bottom - inset - taper,
    );
    final split = inner.top + inner.height * 0.42;
    const panelRadius = Radius.circular(4);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(inner.left, inner.top, inner.right, split - 5),
          panelRadius,
        ),
        panelPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(inner.left, split + 5, inner.right, inner.bottom),
          panelRadius,
        ),
        panelPaint,
      );
    // The knob is on the free edge, low enough to show under the mascot.
    final knobX = isOverWall ? left + inset * 0.5 + 3 : right - inset * 0.5 - 3;
    canvas.drawCircle(
      Offset(knobX, top + (bottom - top) * 0.7),
      4.5,
      Paint()..color = frame,
    );
  }

  @override
  bool shouldRepaint(_DoorPainter old) =>
      doorway != old.doorway ||
      shape.extent != old.shape.extent ||
      shape.taper != old.shape.taper ||
      frame != old.frame ||
      door != old.door ||
      panel != old.panel;
}
