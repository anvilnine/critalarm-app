import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

part 'onboarding_intro_steps.dart';
part 'onboarding_welcome_stories.dart';
part 'onboarding_welcome_variants.dart';

/// The welcome animations. The first five are only faces, the next seven
/// show how Crit Alarm works, and the last three are faces again.
enum WelcomeVariant {
  /// One big face asleep, wakes up, smiles.
  wakeUp,

  /// A row of coloured faces slides in and does a wave.
  parade,

  /// Small faces circle a big one.
  orbit,

  /// A grid of every face in every colour, flipping over in waves.
  ripple,

  /// A face peeks over a ledge, looks around, then pops up.
  peekaboo,

  /// A curl in a terminal makes a phone ring.
  curl,

  /// An iPhone: notification, Live Activity, the system alarm, the app.
  iphone,

  /// An Android phone: heads-up notice, then the full screen alarm.
  android,

  /// Three messages at three priorities, and what each one does.
  ladder,

  /// Server to Crit Alarm to phone, and the acknowledgement back.
  pipeline,

  /// The home screen widgets: a count, a ringing card, the topic list.
  widgets,

  /// A curl in a terminal makes an Android phone ring.
  androidCurl,

  /// A face with what Crit Alarm does going round it.
  featureOrbit,

  /// The parade, but furious: they drop in, stomp and fume.
  angryParade,

  /// Ringing faces circling a big ringing face.
  ringingOrbit;

  /// `?v=1` to `?v=15`. Anything else is the first one.
  static WelcomeVariant fromQuery(String? value) {
    final index = (int.tryParse(value ?? '') ?? 1) - 1;
    return index >= 0 && index < values.length ? values[index] : wakeUp;
  }
}

/// Onboarding welcome screen (/onboarding/welcome), the first thing a new
/// user sees. With no [variant] it opens on one of two faces at random, then
/// keeps playing more animations for as long as the user stays. Developer
/// options opens it with a [variant] and [isPreview] to try each one.
class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({
    this.variant,
    this.isPreview = false,
    super.key,
  });

  final WelcomeVariant? variant;

  /// Opened from Developer options: shows a switch for every animation, and
  /// Get started goes back instead of starting onboarding.
  final bool isPreview;

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  late WelcomeVariant _variant =
      widget.variant ??
      (math.Random().nextBool()
          ? WelcomeVariant.wakeUp
          : WelcomeVariant.peekaboo);

  /// Bumped on every tap of the preview switch, so picking the one already
  /// showing plays it again from the start.
  int _replays = 0;

  bool get _isPlaylist => widget.variant == null && !widget.isPreview;

  @override
  Widget build(BuildContext context) {
    return _IntroLayout(
      top: widget.isPreview ? _previewSwitch() : null,
      // On first launch the opening face hands over to more animations for
      // as long as the user stays.
      hero: _isPlaylist
          ? OnboardingAnimationLoop(
              first: _variant,
              loop: const [
                WelcomeVariant.ladder,
                WelcomeVariant.parade,
                WelcomeVariant.orbit,
              ],
            )
          : KeyedSubtree(
              key: ValueKey((_variant, _replays)),
              child: _heroFor(_variant),
            ),
      title: LocaleKeys.onboarding_welcome_title.tr(),
      subtitle: LocaleKeys.onboarding_welcome_subtitle.tr(),
      button: LocaleKeys.onboarding_welcome_button.tr(),
      onPressed: widget.isPreview
          ? () => context.pop()
          : () => unawaited(
              finishOnboardingStep(context, OnboardingStepId.welcome),
            ),
    );
  }

  /// Every animation by number, in two rows so fifteen still fit a phone.
  Widget _previewSwitch() {
    const perRow = 8;
    const all = WelcomeVariant.values;
    Widget row(List<WelcomeVariant> items) =>
        AppSegmentedControl<WelcomeVariant>(
          items: items,
          selectedItem: _variant,
          labelBuilder: (v) => '${v.index + 1}',
          onChanged: (v) => setState(() {
            _variant = v;
            _replays++;
          }),
        );
    return Column(
      children: [
        row(all.sublist(0, perRow)),
        const SizedBox(height: Spacing.s2),
        row(all.sublist(perRow)),
      ],
    );
  }
}

Widget _heroFor(WelcomeVariant variant) => switch (variant) {
  WelcomeVariant.wakeUp => const _WakeUpHero(),
  WelcomeVariant.parade => const _ParadeHero(),
  WelcomeVariant.orbit => const _OrbitHero(),
  WelcomeVariant.ripple => const FaceRipple(),
  WelcomeVariant.peekaboo => const _PeekabooHero(),
  WelcomeVariant.curl => const _CurlHero(),
  WelcomeVariant.iphone => const _IphoneHero(),
  WelcomeVariant.android => const _AndroidHero(),
  WelcomeVariant.ladder => const _LadderHero(),
  WelcomeVariant.pipeline => const _PipelineHero(),
  WelcomeVariant.widgets => const _WidgetsHero(),
  WelcomeVariant.androidCurl => const _AndroidCurlHero(),
  WelcomeVariant.featureOrbit => const _FeatureOrbitHero(),
  WelcomeVariant.angryParade => const _AngryParadeHero(),
  WelcomeVariant.ringingOrbit => const _RingingOrbitHero(),
};

/// Plays [first], then each of [loop] round and round, fading between them.
/// With animations switched off it stays on [first], sitting still.
class OnboardingAnimationLoop extends StatefulWidget {
  const OnboardingAnimationLoop({required this.loop, this.first, super.key});

  final WelcomeVariant? first;
  final List<WelcomeVariant> loop;

  @override
  State<OnboardingAnimationLoop> createState() =>
      _OnboardingAnimationLoopState();
}

class _OnboardingAnimationLoopState extends State<OnboardingAnimationLoop> {
  late WelcomeVariant _variant = widget.first ?? widget.loop.first;
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  /// How long each animation plays: one full story for the phone ones, a
  /// few seconds for the faces.
  Duration get _playFor => switch (_variant) {
    WelcomeVariant.ladder ||
    WelcomeVariant.pipeline => const Duration(milliseconds: 9800),
    _ => const Duration(seconds: 7),
  };

  void _scheduleNext() {
    _next = Timer(_playFor, () {
      if (!mounted) return;
      // With animations off each face sits still, so there is nothing to
      // move on from.
      if (MediaQuery.of(context).disableAnimations) return;
      final at = widget.loop.indexOf(_variant);
      setState(() => _variant = widget.loop[(at + 1) % widget.loop.length]);
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) => _NoIntrinsicSize(
    // The heroes are mock-ups of the app. Their fake topic names and times
    // mean nothing read aloud; the title and text below say what they show.
    child: ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: context.motion(const Duration(milliseconds: 450)),
        child: KeyedSubtree(key: ValueKey(_variant), child: _heroFor(_variant)),
      ),
    ),
  );
}

/// The shape every intro step shares: an animation filling the top, then a
/// title, a line of text and one button. The words and the button are on the
/// page from the first frame and stay put while the animation above them
/// plays and changes.
class _IntroLayout extends StatelessWidget {
  const _IntroLayout({
    required this.hero,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onPressed,
    this.top,
    this.badge,
  });

  final Widget hero;
  final String title;
  final String subtitle;
  final String button;
  final VoidCallback onPressed;

  /// Above the animation, such as the preview switch.
  final Widget? top;

  /// Between the title and the text, such as the Hosted badge.
  final Widget? badge;

  /// The least room the animation keeps when large text crowds the page.
  static const double _minHeroHeight = 380;

  /// The most the system text size may grow the title.
  static const double _titleMaxTextScale = 1.4;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Same frame as the permissions and connect screens, so the button sits
    // in the same place on every onboarding step.
    return AppScreenScaffold(
      backgroundColor: Colors.transparent,
      withGhosts: false,
      withFades: false,
      hasTabBar: false,
      // Still while the words fit. At a large text size they take the room
      // the animation had, and then the page scrolls instead of cutting them
      // off behind the button.
      physics: const ClampingScrollPhysics(),
      bottomBar: AppButton(
        label: button,
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: onPressed,
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s5,
            Spacing.s4,
            Spacing.s5,
            0,
          ),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              // The scaffold leaves room for the button under the list, but
              // SliverFillRemaining measures against the whole viewport, so
              // it carries that room itself: the lg button, the 12 under it
              // and the home indicator, plus a gap above the button.
              padding: EdgeInsets.only(
                bottom:
                    // The button grows with the system text size, so the
                    // room for it does too.
                    MediaQuery.textScalerOf(context).scale(60) +
                    12 +
                    MediaQuery.paddingOf(context).bottom +
                    12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (top != null) ...[
                    top!,
                    const SizedBox(height: Spacing.s4),
                  ],
                  Expanded(
                    child: _NoIntrinsicSize(
                      minHeight: _minHeroHeight,
                      // A mock-up; the words below carry the meaning. It is
                      // a drawing, so it keeps its size when the system text
                      // grows.
                      child: ExcludeSemantics(
                        child: MediaQuery.withNoTextScaling(
                          child: AnimatedSwitcher(
                            duration: context.motion(
                              const Duration(milliseconds: 450),
                            ),
                            child: hero,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.s5),
                  Text(
                    title,
                    // The display size is already large. Capped, it holds
                    // to about three lines at the largest system size, while
                    // the words below keep the full scale.
                    textScaler: MediaQuery.textScalerOf(
                      context,
                    ).clamp(maxScaleFactor: _titleMaxTextScale),
                    style: AppTypography.display(
                      colors.onCanvas,
                      fontSize: 36,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: Spacing.s3),
                    Align(alignment: Alignment.centerLeft, child: badge),
                  ],
                  const SizedBox(height: Spacing.s2),
                  Text(
                    subtitle,
                    style: AppTypography.lead(
                      colors.onCanvasMuted,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A hero that redraws every frame and knows how many seconds it has run.
/// With animations switched off it sits still at [restAt].
abstract class _ClockState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _seconds = 0;

  /// Where a still hero rests: after the intro, on a friendly face.
  double get restAt;

  /// Seconds since the hero appeared.
  double get t => (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
      ? restAt
      : _seconds;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => setState(() => _seconds = elapsed.inMicroseconds / 1e6),
    );
    unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Face helpers.

final Map<FaceState, FaceShape> _shapes = {};

FaceShape _shape(FaceState state) =>
    _shapes.putIfAbsent(state, () => faceFor(state));

/// How far through the window starting at [start] and lasting [length] the
/// clock [t] is, from 0 to 1.
double _window(double t, double start, double length) =>
    ((t - start) / length).clamp(0.0, 1.0);

FaceShape _blend(FaceState a, FaceState b, double p) => FaceShape.lerp(
  _shape(a),
  _shape(b),
  Curves.easeInOutCubic.transform(p),
);

/// Walks [faces] in a loop: holds each one, then melts into the next.
FaceShape _cycle(
  List<FaceState> faces,
  double t, {
  double hold = 1.6,
  double blend = 0.45,
}) {
  final step = hold + blend;
  final local = t % (step * faces.length);
  final i = local ~/ step;
  final into = local - i * step;
  final from = faces[i];
  final to = faces[(i + 1) % faces.length];
  return into < hold ? _shape(from) : _blend(from, to, (into - hold) / blend);
}

/// A quick blink every few seconds, so a face that is holding still still
/// looks alive. [offset] keeps a crowd of faces from blinking together.
FaceShape _withBlink(FaceShape face, double t, {double offset = 0}) {
  final local = (t + offset) % 3.7;
  return local < 0.12 ? face.blinking : face;
}

const Color _darkInk = faceCrowdInk;

/// Bright heads for the crowd variants. Dark ink on all of them, so they
/// read the same in light and dark mode.
const List<Color> _crowdFills = faceCrowdFills;

Widget _face(FaceShape shape, double size, {Color? fill}) => FaceWidget(
  state: FaceState.calm,
  shape: shape,
  size: size,
  overrideFillColor: fill,
  overrideStrokeColor: fill == null ? null : _darkInk,
  overrideInkColor: fill == null ? null : _darkInk,
);

// ---------------------------------------------------------------------------
// 1. Wake up.

class _WakeUpHero extends StatefulWidget {
  const _WakeUpHero();

  @override
  State<_WakeUpHero> createState() => _WakeUpHeroState();
}

class _WakeUpHeroState extends _ClockState<_WakeUpHero> {
  @override
  double get restAt => 3.2;

  static const List<FaceState> _after = [
    FaceState.happy,
    FaceState.curious,
    FaceState.cheeky,
    FaceState.love,
    FaceState.content,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final enter = Curves.easeOutBack.transform(_window(t, 0, 0.9));

    final FaceShape face;
    if (t < 1.6) {
      face = _shape(FaceState.dozing);
    } else if (t < 1.95) {
      face = _blend(FaceState.dozing, FaceState.wakesUp, _window(t, 1.6, 0.35));
    } else if (t < 2.5) {
      face = _shape(FaceState.wakesUp);
    } else if (t < 2.9) {
      face = _blend(FaceState.wakesUp, FaceState.happy, _window(t, 2.5, 0.4));
    } else {
      face = _withBlink(_cycle(_after, t - 2.9, hold: 2), t);
    }

    // A startled hop as it wakes, then a slow breathing bob.
    final hop = math.sin(_window(t, 1.6, 0.45) * math.pi) * -26;
    final bob = t > 2.9 ? math.sin((t - 2.9) * 2.2) * 5 : 0.0;

    return Center(
      child: Opacity(
        opacity: _window(t, 0, 0.4),
        child: Transform.translate(
          offset: Offset(0, hop + bob),
          child: Transform.scale(
            scale: 0.6 + 0.4 * enter,
            child: _face(face, 190),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Parade.

class _ParadeHero extends StatefulWidget {
  const _ParadeHero();

  @override
  State<_ParadeHero> createState() => _ParadeHeroState();
}

class _ParadeHeroState extends _ClockState<_ParadeHero> {
  @override
  double get restAt => 2.2;

  static const List<FaceState> _moods = [
    FaceState.happy,
    FaceState.cheeky,
    FaceState.love,
    FaceState.proud,
    FaceState.laughing,
    FaceState.content,
    FaceState.curious,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    return LayoutBuilder(
      builder: (context, box) {
        const count = 5;
        const gap = 8.0;
        final size = math.min<double>(
          72,
          (box.maxWidth - gap * (count - 1)) / count,
        );
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _member(i, size, t, box.maxWidth),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _member(int i, double size, double t, double width) {
    final enter = Curves.easeOutBack.transform(_window(t, 0.12 * i, 0.8));
    final slide = (1 - enter) * width;

    // After everyone is in, a wave runs left to right, over and over.
    final wave = (t - 1.4 - i * 0.14) % 2.4;
    final hop = t > 1.4 && wave < 0.5
        ? math.sin(wave / 0.5 * math.pi) * -24
        : 0.0;

    final face = _withBlink(
      _cycle(_moods, t + i * 0.7, hold: 1.8),
      t,
      offset: i * 0.9,
    );
    return Transform.translate(
      offset: Offset(slide, hop),
      child: _face(face, size, fill: _crowdFills[i % _crowdFills.length]),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Orbit.

class _OrbitHero extends StatefulWidget {
  const _OrbitHero();

  @override
  State<_OrbitHero> createState() => _OrbitHeroState();
}

class _OrbitHeroState extends _ClockState<_OrbitHero> {
  @override
  double get restAt => 2;

  static const List<FaceState> _centre = [
    FaceState.calm,
    FaceState.happy,
    FaceState.lookLeft,
    FaceState.lookRight,
    FaceState.proud,
  ];

  static const List<FaceState> _moons = [
    FaceState.happy,
    FaceState.love,
    FaceState.cheeky,
    FaceState.surprised,
    FaceState.laughing,
    FaceState.content,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight);
        final big = side * 0.4;
        final small = side * 0.15;
        final radius = side / 2 - small / 2 - 4;
        const count = 6;

        final centreIn = Curves.easeOutBack.transform(_window(t, 0, 0.7));
        final centreFace = _withBlink(_cycle(_centre, t, hold: 1.7), t);

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  _moon(i, count, t, radius, small),
                Transform.scale(
                  scale: centreIn,
                  child: _face(centreFace, big),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _moon(int i, int count, double t, double radius, double size) {
    final out = Curves.easeOutBack.transform(_window(t, 0.3 + i * 0.08, 0.9));
    final angle = i * 2 * math.pi / count + t * 0.45 - math.pi / 2;
    final r = radius * out;
    final face = _withBlink(
      _cycle(_moons, t + i * 0.8, hold: 1.5),
      t,
      offset: i * 0.6,
    );
    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
      child: Opacity(
        opacity: out.clamp(0.0, 1.0),
        child: _face(face, size, fill: _crowdFills[i % _crowdFills.length]),
      ),
    );
  }
}

// 4. Ripple lives in lib/design/faces/face_ripple.dart (FaceRipple), shared
// with the test alarm's acknowledged screen.

// ---------------------------------------------------------------------------
// 5. Peekaboo.

class _PeekabooHero extends StatefulWidget {
  const _PeekabooHero();

  @override
  State<_PeekabooHero> createState() => _PeekabooHeroState();
}

class _PeekabooHeroState extends _ClockState<_PeekabooHero> {
  @override
  double get restAt => 3.4;

  static const List<FaceState> _after = [
    FaceState.love,
    FaceState.happy,
    FaceState.cheeky,
    FaceState.content,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final colors = context.appColors;

    final FaceShape face;
    if (t < 1.3) {
      face = _shape(FaceState.lookLeft);
    } else if (t < 1.6) {
      face = _blend(
        FaceState.lookLeft,
        FaceState.lookRight,
        _window(t, 1.3, 0.3),
      );
    } else if (t < 2.1) {
      face = _shape(FaceState.lookRight);
    } else if (t < 2.3) {
      face = _blend(
        FaceState.lookRight,
        FaceState.realization,
        _window(t, 2.1, 0.2),
      );
    } else if (t < 2.6) {
      face = _shape(FaceState.realization);
    } else if (t < 3) {
      face = _blend(
        FaceState.realization,
        FaceState.love,
        _window(t, 2.6, 0.4),
      );
    } else {
      face = _withBlink(_cycle(_after, t - 3, hold: 2), t);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min<double>(210, box.maxHeight * 0.8);
        // Hidden below the ledge, then the top of the head peeks over it,
        // then the whole face pops up.
        final peek = Curves.easeOutCubic.transform(_window(t, 0.2, 0.7));
        final pop = Curves.easeOutBack.transform(_window(t, 2.5, 0.6));
        final shown = 0.42 * peek + 0.58 * pop;
        final bob = t > 3.1 ? math.sin((t - 3.1) * 2.2) * 4 : 0.0;
        final ledgeY = box.maxHeight * 0.5 + size / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: ledgeY,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: (box.maxWidth - size) / 2,
                      top: ledgeY - size * shown + bob,
                      child: _face(face, size),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: box.maxWidth * 0.12,
              right: box.maxWidth * 0.12,
              top: ledgeY,
              child: Opacity(
                opacity: _window(t, 0, 0.3),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onCanvas,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Answers "how big do you want to be" with [minHeight] (zero by default),
/// so a scroll view that asks (SliverFillRemaining does) never reaches the
/// LayoutBuilder inside the animations, which cannot answer it. The
/// animations fill whatever room they are given anyway. A [minHeight] above
/// zero is the room the page keeps for them when other things on the page
/// grow.
class _NoIntrinsicSize extends SingleChildRenderObjectWidget {
  const _NoIntrinsicSize({required Widget super.child, this.minHeight = 0});

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoIntrinsicSize(minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNoIntrinsicSize renderObject,
  ) {
    renderObject.minHeight = minHeight;
  }
}

class _RenderNoIntrinsicSize extends RenderProxyBox {
  _RenderNoIntrinsicSize(this._minHeight);

  double _minHeight;

  double get minHeight => _minHeight;

  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight;
}
