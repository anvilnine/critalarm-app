import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/ambient/ambient_shape.dart';
import 'package:critalarm/design/ambient/hero_disc.dart';
import 'package:critalarm/design/ambient/hero_timeline.dart';
import 'package:critalarm/design/ambient/hero_tone.dart';
import 'package:critalarm/design/components/nav_rail.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/design/ambient/hero_tone.dart' show AppHeroTone;

/// Where the face looks while nothing else is going on.
enum AppHeroGaze {
  /// Straight out.
  none,

  /// At the status card.
  card,

  /// Down at the list under the hero.
  list,
}

/// Which way the card and the face are arranged.
enum AppHeroLayout {
  /// The face on the left and the card on the right, overlapping it.
  sideBySide,

  /// The face on top and the card under it at full width.
  stacked,
}

/// The scene stacks below this width.
const double kHeroSideBySideMinWidth = 340;

/// The largest the face is drawn, side by side.
const double kHeroMaxFaceSize = 170;

/// The face size when the scene is stacked.
const double kHeroStackedFaceSize = 120;

/// How far the card overlaps the face, in points.
const double kHeroCardOverlap = 10;

/// Which arrangement the scene uses.
///
/// Side by side needs [kHeroSideBySideMinWidth] points and a text scale of
/// [kChromeMaxTextScale] or less, and a pane never gets it: the list pane of
/// a two pane display is too narrow for the card beside the face.
AppHeroLayout heroLayoutFor({
  required double width,
  required double textScale,
  bool isPane = false,
}) {
  if (isPane || width < kHeroSideBySideMinWidth) return AppHeroLayout.stacked;
  if (textScale > kChromeMaxTextScale) return AppHeroLayout.stacked;
  return AppHeroLayout.sideBySide;
}

/// The face's width and height in [layout] for a scene [width] points wide.
double heroFaceSizeFor(AppHeroLayout layout, double width) => switch (layout) {
  AppHeroLayout.sideBySide => math.min(kHeroMaxFaceSize, width * 0.44),
  AppHeroLayout.stacked => math.min(kHeroStackedFaceSize, width * 0.44),
};

/// Room above the face for its bob.
const double _kHeroFaceTop = Spacing.s2;

/// The space either side of the scene.
const double _kHeroGutter = Spacing.s3;

/// Where the disc and the ring are centred in a scene [width] points wide, and
/// how wide each is, for a face [face] points across.
({Offset centre, double disc, double ring}) heroDiscGeometry({
  required AppHeroLayout layout,
  required double width,
  required double face,
}) {
  final isSide = layout == AppHeroLayout.sideBySide;
  final faceLeft = isSide ? _kHeroGutter : (width - face) / 2;
  final faceCentre = Offset(faceLeft + face / 2, _kHeroFaceTop + face / 2);
  return (
    centre: isSide
        ? faceCentre + Offset(face * 0.27, face * 0.09)
        : faceCentre + Offset(0, face * 0.1),
    disc: face * 2.76,
    ring: face * 3.47,
  );
}

/// Where the disc and the ring of a scene sit on a [screen], for the ambient
/// canvas to draw behind it.
///
/// - [sceneOrigin]: the scene's top left corner on the screen, with the list
///   not scrolled.
/// - [sceneWidth] and [textScale]: what the scene lays itself out from.
HeroDiscSpot heroDiscSpot({
  required Size screen,
  required Offset sceneOrigin,
  required double sceneWidth,
  required double textScale,
  bool isPane = false,
}) {
  final layout = heroLayoutFor(
    width: sceneWidth,
    textScale: textScale,
    isPane: isPane,
  );
  final geometry = heroDiscGeometry(
    layout: layout,
    width: sceneWidth,
    face: heroFaceSizeFor(layout, sceneWidth),
  );
  final centre = sceneOrigin + geometry.centre;
  final short = screen.shortestSide;
  return HeroDiscSpot(
    anchor: Alignment(
      centre.dx / screen.width * 2 - 1,
      centre.dy / screen.height * 2 - 1,
    ),
    discScale: math.min(geometry.disc / short, AmbientShape.maxScale),
    ringScale: math.min(geometry.ring / short, AmbientShape.maxScale),
  );
}

/// [heroDiscSpot] for the Topics screen on this display: the scene sits under
/// the status bar, the top bar and one gap, with the list at rest.
///
/// It follows the scaffold's own column rules (a capped, centred column on a
/// medium display, a list pane beside the detail on an expanded one), so the
/// disc stays behind the face. Both the shell and the screen call it with the
/// same context, so they agree on the answer.
HeroDiscSpot heroDiscSpotOf(BuildContext context) {
  // Only the parts that matter, so a keyboard sliding up does not rebuild the
  // shell that calls this.
  final screen = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
  final size = AppSize.of(context);
  final isPane = size.isExpanded;
  final railOnRight = size.navPlacement == AppNavPlacement.right;
  final railGap = size.hasRail
      ? AppNavRail.contentGap + (railOnRight ? padding.right : padding.left)
      : 0.0;
  final available = screen.width - railGap;
  final paneWidth = isPane
      ? AppScreenScaffold.listPaneWidth(available)
      : screen.width;
  final gutter = isPane
      ? 0.0
      : math.max(railGap, (paneWidth - AppSize.contentMaxWidth) / 2);
  return heroDiscSpot(
    screen: screen,
    sceneOrigin: Offset(
      gutter + (isPane && !railOnRight ? railGap : 0),
      padding.top + AppScreenScaffold.topBarHeight + Spacing.s3,
    ),
    sceneWidth: paneWidth - 2 * gutter,
    textScale: textScale,
    isPane: isPane,
  );
}

/// Where the pupils sit for [gaze], in the face's 200 unit box.
Offset heroGazeOffset(AppHeroGaze gaze, AppHeroLayout layout) => switch (gaze) {
  AppHeroGaze.none => Offset.zero,
  AppHeroGaze.card =>
    layout == AppHeroLayout.sideBySide
        ? const Offset(7, 3)
        : const Offset(0, 7),
  AppHeroGaze.list => _listGaze,
};

const Offset _listGaze = Offset(1, 8);

/// Faces whose eyes are shut or squeezed already, or that move on their own.
/// They keep their own pose: no blink, no bob.
const Set<FaceState> _facesThatStayPut = {
  FaceState.acked,
  FaceState.happy,
  FaceState.content,
  FaceState.dozing,
  FaceState.sleepy,
  FaceState.yawn,
  FaceState.working,
  FaceState.success,
  FaceState.laughing,
  FaceState.shakeHead,
  FaceState.breatheIn,
  FaceState.breatheOut,
  FaceState.blink,
  FaceState.alarmed,
  FaceState.shocked,
  FaceState.dizzy,
  FaceState.confused,
  FaceState.cheeky,
};

EyeShape _attentiveEye(Offset at) => EyeShape(
  centre: at,
  ballRadius: 20,
  pupilRadius: 9.5,
  lidPoints: restingLid(at),
);

/// The calm face with wide white eyes. A plain calm face has dot eyes, so
/// moving its pupils shows nothing; these eyes let the face be seen looking
/// at the card or down at the list. The head, the mouth and the colours are
/// calm's own, and the state stays calm: all is well, and it is keeping an
/// eye on things. The paywall's mascot looks at its prop with the same eyes.
final FaceShape heroAttentiveCalmFace = FaceShape(
  leftEye: _attentiveEye(const Offset(74, 92)),
  rightEye: _attentiveEye(const Offset(126, 92)),
  mouth: calmFace.mouth,
);

/// The pose the hero draws for [state] when the caller gives none. Calm is
/// the attentive calm face, so a look is readable. Every other state is the
/// face rig's own pose.
FaceShape heroBaseShape(FaceState state) =>
    state == FaceState.calm ? heroAttentiveCalmFace : faceFor(state);

/// True when [state] blinks and looks around in the hero scene.
bool heroFaceBlinks(FaceState state) => !_facesThatStayPut.contains(state);

/// [shape] with both pupils moved by [by], in the 200 unit box.
FaceShape heroLookedShape(FaceShape shape, Offset by) {
  EyeShape look(EyeShape e) => EyeShape(
    centre: e.centre,
    ballRadius: e.ballRadius,
    ballSquash: e.ballSquash,
    ballWidth: e.ballWidth,
    ballIsHead: e.ballIsHead,
    pupilRadius: e.pupilRadius,
    pupilOffset: e.pupilOffset + by,
    shineRadius: e.shineRadius,
    shineOffset: e.shineOffset,
    spiral: e.spiral,
    lid: e.lid,
    lidPoints: e.lidPoints,
    lidWidth: e.lidWidth,
  );
  return FaceShape(
    leftEye: look(shape.leftEye),
    rightEye: look(shape.rightEye),
    mouth: shape.mouth,
    leftBrow: shape.leftBrow,
    rightBrow: shape.rightBrow,
    head: shape.head,
    props: shape.props,
    tilt: shape.tilt,
    nudge: shape.nudge,
  );
}

/// The top of a status screen: a large face, the dark card beside or under
/// it, and a pale disc and ring breathing behind both.
///
/// The face is the one living thing. It bobs a few points, blinks every few
/// seconds and can look at the card or down at the list. Nothing plays when
/// the scene first appears: the first frame is a finished picture. The disc
/// and ring breathe, two dots float, and all of it comes from one clock that
/// stops while the route is covered or the app is not in front. With reduce
/// motion, or [hasMotion] false, every part sits at rest: no bob, no blink.
///
/// The face is drawn the way a stage face is, so pull to refresh still takes
/// it over when the screen has a [RefreshFaceScope].
///
/// The scene paints past its own box: the disc is larger than the scene. Let
/// it, and put the list sheet after it so the sheet covers the disc.
class AppHeroScene extends StatelessWidget {
  const AppHeroScene({
    required this.face,
    required this.card,
    this.faceShape,
    this.tone = AppHeroTone.calm,
    this.gaze = AppHeroGaze.none,
    this.isLive = false,
    this.hasMotion = true,
    this.isPane = false,
    this.glance = 0,
    super.key,
  });

  /// The face's state. Pass the face from `face_meaning.dart`.
  final FaceState face;

  /// Draws this pose in place of [face]'s own. The head colours still follow
  /// [face]. A pose the face package lacks is built as a [FaceShape] by the
  /// caller.
  final FaceShape? faceShape;

  /// The disc tint.
  final AppHeroTone tone;

  /// Where the face looks while nothing else is going on.
  final AppHeroGaze gaze;

  /// True lets a live face (the alarmed shake) move. Such a face does not
  /// bob or blink.
  final bool isLive;

  /// False holds every part at rest, as reduce motion does.
  final bool hasMotion;

  /// True when the scene sits in the list pane of a two pane display. It
  /// stacks whatever its width.
  final bool isPane;

  /// Change this number to make the face glance down at the list for a
  /// moment: a message landed. A number that is already there when the scene
  /// first builds does nothing.
  final int glance;

  /// The card. Normally the status card.
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = heroLayoutFor(
          width: width,
          textScale: scale,
          isPane: isPane,
        );
        final body = _HeroBody(
          scene: this,
          layout: layout,
          width: width,
          faceSize: heroFaceSizeFor(layout, width),
        );
        return hasMotion ? body : PaywallStill(child: body);
      },
    );
  }
}

class _HeroBody extends StatefulWidget {
  const _HeroBody({
    required this.scene,
    required this.layout,
    required this.width,
    required this.faceSize,
  });

  final AppHeroScene scene;
  final AppHeroLayout layout;
  final double width;
  final double faceSize;

  @override
  State<_HeroBody> createState() => _HeroBodyState();
}

class _HeroBodyState extends PaywallClockState<_HeroBody> {
  /// Seconds on the clock, for the disc, the ring and the dots.
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  /// The face's blink and glance, rounded to steps so the face is rebuilt
  /// only when it would look different.
  final ValueNotifier<({double blink, double glance})> _faceTick =
      ValueNotifier((blink: 0, glance: 0));

  /// The clock second the current glance began at, or null.
  double? _glanceStart;

  @override
  double get restAt => 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isStill) {
      // Reduce motion arrived while the scene was playing: go to the rest
      // frame rather than hold whatever second it was on.
      _glanceStart = null;
      _seconds.value = restAt;
      _faceTick.value = (blink: 0, glance: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _HeroBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scene.glance != oldWidget.scene.glance && !isStill) {
      _glanceStart = t;
    }
  }

  @override
  void onTick() {
    final now = t;
    _seconds.value = now;
    final start = _glanceStart;
    var glance = 0.0;
    if (start != null) {
      final since = now - start;
      if (since >= heroGlanceSeconds) {
        _glanceStart = null;
      } else {
        glance = heroGlance(since);
      }
    }
    _faceTick.value = (
      blink: _step(heroBlink(now), 20),
      glance: _step(glance, 50),
    );
  }

  /// [value] rounded to the nearest 1/[steps].
  static double _step(double value, int steps) =>
      (value * steps).round() / steps;

  @override
  void dispose() {
    _seconds.dispose();
    _faceTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final colors = context.appColors;
    final layout = widget.layout;
    final width = widget.width;
    final face = widget.faceSize;
    final isSide = layout == AppHeroLayout.sideBySide;

    const gutter = _kHeroGutter;
    const faceTop = _kHeroFaceTop;

    final faceLeft = isSide ? gutter : (width - face) / 2;
    final disc = heroDiscGeometry(layout: layout, width: width, face: face);
    // On the app's ambient canvas the canvas draws the disc and the ring, so
    // they morph with the tab changes and the pushes. Alone, in the gallery
    // or a capture tool, the scene draws its own.
    final paintsDisc = !AmbientScope.isInAmbientScope(context);

    // The card starts a little under the top of the face beside it, or just
    // above the foot of the face when stacked.
    final cardTop = isSide ? faceTop + face * 0.176 : faceTop + face - 10;
    final cardLeft = isSide ? faceLeft + face - kHeroCardOverlap : gutter;

    final dotRingColor = colors.onCanvas.withValues(alpha: 0.1);
    final dotFillColor = colors.surface.withValues(alpha: 0.7);

    final firstDot = Offset(
      isSide ? width * 0.815 : width * 0.86,
      faceTop + (isSide ? -face * 0.06 : face * 0.1),
    );
    final secondDot = Offset(
      isSide ? width * 0.636 : width * 0.74,
      faceTop + (isSide ? face * 0.012 : face * 0.02),
    );

    final target = heroGazeOffset(scene.gaze, layout);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: _seconds,
            builder: (context, secs, _) {
              final frame = heroTimeline(secs);
              return ExcludeSemantics(
                child: IgnorePointer(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (paintsDisc)
                        Positioned.fill(
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(
                              end: scene.tone.discColor(colors),
                            ),
                            duration: context.motion(
                              const Duration(milliseconds: 600),
                            ),
                            curve: AppCurves.easeOut,
                            builder: (context, discColor, _) => HeroDisc(
                              painter: HeroDiscPainter(
                                centre: disc.centre,
                                discDiameter: disc.disc,
                                ringDiameter: disc.ring,
                                discColor: discColor ?? colors.canvasAlt,
                                ringColor: colors.onCanvas.withValues(
                                  alpha: 0.06,
                                ),
                                discScale: frame.discScale,
                                ringScale: frame.ringScale,
                              ),
                            ),
                          ),
                        ),
                      _dot(
                        firstDot - Offset(0, frame.firstDotRise),
                        26,
                        border: dotRingColor,
                      ),
                      _dot(
                        secondDot - Offset(0, frame.secondDotRise),
                        10,
                        fill: dotFillColor,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: faceLeft,
          top: faceTop,
          width: face,
          height: face,
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(end: target),
              duration: context.motion(const Duration(milliseconds: 300)),
              curve: AppCurves.easeOut,
              builder: (context, rest, _) => ValueListenableBuilder<double>(
                valueListenable: _seconds,
                builder: (context, secs, child) {
                  final rise = scene.isLive || !heroFaceBlinks(scene.face)
                      ? 0.0
                      : heroTimeline(secs).faceRise;
                  return Transform.translate(
                    offset: Offset(0, -rise),
                    child: child,
                  );
                },
                child: ValueListenableBuilder<({double blink, double glance})>(
                  valueListenable: _faceTick,
                  builder: (context, tick, _) => _HeroFace(
                    state: scene.face,
                    shape: scene.faceShape,
                    size: face,
                    isLive: scene.isLive,
                    gaze: Offset.lerp(rest, _listGaze, tick.glance)!,
                    blink: tick.blink,
                  ),
                ),
              ),
            ),
          ),
        ),
        // The card sets the scene's height: it is the only child that is not
        // positioned. The face's own height is the least the scene takes.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: faceTop + face),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.fromLTRB(cardLeft, cardTop, gutter, 0),
              child: scene.card,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(Offset at, double size, {Color? border, Color? fill}) =>
      Positioned(
        left: at.dx,
        top: at.dy,
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: border == null ? null : Border.all(color: border, width: 5),
          ),
        ),
      );
}

/// The hero face for one frame: the stage face at rest, a shaped face while
/// it blinks or looks aside, and the refresh face while a pull is on.
class _HeroFace extends StatelessWidget {
  const _HeroFace({
    required this.state,
    required this.shape,
    required this.size,
    required this.isLive,
    required this.gaze,
    required this.blink,
  });

  final FaceState state;
  final FaceShape? shape;
  final double size;
  final bool isLive;
  final Offset gaze;
  final double blink;

  @override
  Widget build(BuildContext context) {
    final controller = RefreshFaceScope.maybeOf(context);
    return ListenableBuilder(
      listenable: controller ?? const _NeverChanges(),
      builder: (context, _) {
        final refreshing =
            controller != null && controller.phase != RefreshFacePhase.idle;
        final moves = heroFaceBlinks(state);
        final looks = moves && gaze != Offset.zero;
        final blinks = moves && blink > 0;
        // A calm hero always wears the attentive eyes, whether or not it is
        // looking at anything this frame.
        final isShaped = shape != null || state == FaceState.calm;

        if (refreshing || !(looks || blinks || isShaped)) {
          return stageFace(context, state: state, size: size, isLive: isLive);
        }

        var pose = shape ?? heroBaseShape(state);
        if (looks) pose = heroLookedShape(pose, gaze);
        if (blinks) pose = FaceShape.lerp(pose, pose.blinking, blink);
        return FaceWidget(state: state, size: size, shape: pose);
      },
    );
  }
}

class _NeverChanges implements Listenable {
  const _NeverChanges();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
