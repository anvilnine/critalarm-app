import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

part 'onboarding_welcome_stories.dart';

/// The welcome animations on trial. The first five are only faces, the rest
/// show how Crit Alarm works.
enum WelcomeVariant {
  /// One big face asleep, wakes up, smiles.
  wakeUp,

  /// A row of coloured faces slides in and does a wave.
  parade,

  /// Small faces circle a big one.
  orbit,

  /// A grid of faces lights up in a diagonal wave.
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
  widgets;

  /// `?v=1` to `?v=11`. Anything else is the first one.
  static WelcomeVariant fromQuery(String? value) {
    final index = (int.tryParse(value ?? '') ?? 1) - 1;
    return index >= 0 && index < values.length ? values[index] : wakeUp;
  }
}

/// Onboarding welcome screen (/onboarding/welcome). Says hello before the
/// permission screens ask for anything. For now it only opens from
/// Developer options, while one of the five animations is picked.
class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({
    this.variant = WelcomeVariant.wakeUp,
    this.isPreview = false,
    super.key,
  });

  final WelcomeVariant variant;

  /// Opened from Developer options: shows a switch for the five animations,
  /// and Get started goes back instead of starting onboarding.
  final bool isPreview;

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  late WelcomeVariant _variant = widget.variant;

  /// Bumped on every tap of the switch, so tapping the one already showing
  /// plays it again from the start.
  int _replays = 0;

  /// When the words come in, so they land after the face has done its bit.
  Duration get _textDelay => switch (_variant) {
    WelcomeVariant.wakeUp => const Duration(milliseconds: 2300),
    WelcomeVariant.parade => const Duration(milliseconds: 1300),
    WelcomeVariant.orbit => const Duration(milliseconds: 1100),
    WelcomeVariant.ripple => const Duration(milliseconds: 1400),
    WelcomeVariant.peekaboo => const Duration(milliseconds: 2700),
    WelcomeVariant.curl ||
    WelcomeVariant.iphone ||
    WelcomeVariant.android ||
    WelcomeVariant.ladder ||
    WelcomeVariant.pipeline ||
    WelcomeVariant.widgets => const Duration(milliseconds: 900),
  };

  Widget get _hero => switch (_variant) {
    WelcomeVariant.wakeUp => const _WakeUpHero(),
    WelcomeVariant.parade => const _ParadeHero(),
    WelcomeVariant.orbit => const _OrbitHero(),
    WelcomeVariant.ripple => const _RippleHero(),
    WelcomeVariant.peekaboo => const _PeekabooHero(),
    WelcomeVariant.curl => const _CurlHero(),
    WelcomeVariant.iphone => const _IphoneHero(),
    WelcomeVariant.android => const _AndroidHero(),
    WelcomeVariant.ladder => const _LadderHero(),
    WelcomeVariant.pipeline => const _PipelineHero(),
    WelcomeVariant.widgets => const _WidgetsHero(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s5,
            Spacing.s4,
            Spacing.s5,
            Spacing.s5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isPreview) ...[
                AppSegmentedControl<WelcomeVariant>(
                  items: WelcomeVariant.values,
                  selectedItem: _variant,
                  labelBuilder: (v) => '${v.index + 1}',
                  onChanged: (v) => setState(() {
                    _variant = v;
                    _replays++;
                  }),
                ),
                const SizedBox(height: Spacing.s4),
              ],
              Expanded(
                // A new key restarts every animation on the screen.
                child: KeyedSubtree(
                  key: ValueKey((_variant, _replays)),
                  child: _body(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final colors = context.appColors;
    final delay = _textDelay;
    const step = Duration(milliseconds: 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _hero),
        const SizedBox(height: Spacing.s5),
        _Reveal(
          delay: delay,
          child: Text(
            LocaleKeys.onboarding_welcome_title.tr(),
            style: AppTypography.display(colors.onCanvas, fontSize: 36),
          ),
        ),
        const SizedBox(height: Spacing.s2),
        _Reveal(
          delay: delay + step,
          child: Text(
            LocaleKeys.onboarding_welcome_subtitle.tr(),
            style: AppTypography.lead(
              colors.onCanvasMuted,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: Spacing.s6),
        _Reveal(
          delay: delay + step * 2,
          child: AppButton(
            label: LocaleKeys.onboarding_welcome_button.tr(),
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: widget.isPreview
                ? () => context.pop()
                : () => context.go('/onboarding'),
          ),
        ),
      ],
    );
  }
}

/// Fades and lifts [child] in after [delay].
class _Reveal extends StatefulWidget {
  const _Reveal({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
      _start ??= Timer(widget.delay, () => unawaited(_controller.forward()));
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_controller.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      );
    },
  );
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

const Color _darkInk = Color(0xFF1A140F);

/// Bright heads for the crowd variants. Dark ink on all of them, so they
/// read the same in light and dark mode.
const List<Color> _crowdFills = [
  Color(0xFFFFC93C),
  Color(0xFF4EAAD8),
  Color(0xFFE2673D),
  Color(0xFF3FA652),
  Color(0xFFF2A7C3),
];

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

// ---------------------------------------------------------------------------
// 4. Ripple.

class _RippleHero extends StatefulWidget {
  const _RippleHero();

  @override
  State<_RippleHero> createState() => _RippleHeroState();
}

class _RippleHeroState extends _ClockState<_RippleHero> {
  @override
  double get restAt => 1.2;

  static const List<FaceState> _reactions = [
    FaceState.happy,
    FaceState.love,
    FaceState.cheeky,
    FaceState.laughing,
    FaceState.proud,
    FaceState.surprised,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    return LayoutBuilder(
      builder: (context, box) {
        const cols = 4;
        const gap = 12.0;
        final size = math.min(
          (box.maxWidth - gap * (cols - 1)) / cols,
          (box.maxHeight - gap * 4) / 5,
        );
        final rows = ((box.maxHeight + gap) / (size + gap)).floor().clamp(1, 5);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        if (c > 0) const SizedBox(width: gap),
                        _cell(r, c, cols, size, t),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(int r, int c, int cols, double size, double t) {
    final d = r + c;
    final pop = Curves.easeOutBack.transform(_window(t, d * 0.07, 0.5));

    // A diagonal wave: each face lights up with its own reaction, holds it,
    // then settles back to calm.
    final reaction = _reactions[(r * cols + c) % _reactions.length];
    final local = (t - 1.2 - d * 0.16) % 4.2;
    final FaceShape face;
    var bump = 0.0;
    if (t < 1.2 || local > 1.6) {
      face = _withBlink(_shape(FaceState.calm), t, offset: d * 0.37);
    } else if (local < 0.3) {
      face = _blend(FaceState.calm, reaction, local / 0.3);
      bump = math.sin(local / 0.3 * math.pi) * 0.14;
    } else if (local < 1.2) {
      face = _shape(reaction);
    } else {
      face = _blend(reaction, FaceState.calm, (local - 1.2) / 0.4);
    }

    return Transform.scale(
      scale: pop + bump,
      child: _face(face, size),
    );
  }
}

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
