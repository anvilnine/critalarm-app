part of 'onboarding_welcome_screen.dart';

// A first welcome page: the day ends, the sun sets, the face sleeps in the
// dark, and at 03:12 the alarm rings. A red burst grows from the middle and
// the face wakes shouting. The clock lives in
// welcome_night_falls_timeline.dart. This file only paints a frame of it.

/// The face that shouts once the alarm rings.
const FaceState _nightShoutFace = FaceState.shocked;

/// The face that smiles in the day, and the one that sleeps at night.
const FaceState _nightDayFace = FaceState.content;
const FaceState _nightSleepFace = FaceState.sleepy;

/// The first welcome page, "night falls, it still rings".
class _NightFallsHero extends StatefulWidget {
  const _NightFallsHero({required this.onDone, this.drawn, this.slide});

  /// Called once, when the first pass is over.
  final VoidCallback onDone;

  /// Told while this story is on screen, so the small shared title hides.
  final _HeroDrawn? drawn;

  /// How far this page has moved off the screen, from 0 to 1, while the
  /// pager moves. Null for a page that does not move.
  final ValueListenable<double>? slide;

  @override
  State<_NightFallsHero> createState() => _NightFallsHeroState();
}

class _NightFallsHeroState extends _ClockState<_NightFallsHero> {
  @override
  double get restAt => 0;

  @override
  double? get loopTakes => welcomeNightFallsLoopSeconds;

  /// One beat when the burst lands. A page that is not in front, or a phone
  /// that asks for reduced motion, plays nothing (see [canPlayHaptics]).
  @override
  List<TimedCue> buildCues() => const [
    (at: welcomeNightFallsBurstLandsAt, cue: HeroCue.ringPulse),
  ];

  bool _hasSaidDone = false;

  @override
  void initState() {
    super.initState();
    widget.drawn?.add();
  }

  @override
  void dispose() {
    widget.drawn?.remove();
    super.dispose();
  }

  @override
  void onClock(double seconds) {
    if (_hasSaidDone || seconds < welcomeNightFallsLoopSeconds) return;
    _hasSaidDone = true;
    widget.onDone();
  }

  String _clockText(WelcomeNightClock clock) => switch (clock) {
    WelcomeNightClock.day =>
      LocaleKeys.welcome_first_pages_night_clock_day.tr(),
    WelcomeNightClock.evening =>
      LocaleKeys.welcome_first_pages_night_clock_evening.tr(),
    WelcomeNightClock.silent =>
      LocaleKeys.welcome_first_pages_night_clock_silent.tr(),
    WelcomeNightClock.ringing =>
      LocaleKeys.welcome_first_pages_night_clock_ringing.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final night = _NightColors(colors);
    final frame = welcomeNightFallsFrameAt(t, reducedMotion: _isStill);
    final textDirection = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = box.maxHeight;
        final pageWidth = width + 2 * _IntroLayout.sidePadding;

        // The sky is a panel the size of the picture. The text sits inside
        // it with a margin.
        const margin = 18.0;
        final textWidth = width - 2 * margin;
        final fontSize = welcomeNightFallsTitleSize(textWidth);
        final ink = Color.lerp(colors.inkFixed, colors.onPanel, frame.ink)!;
        final titleStyle = AppTypography.display(
          ink,
          fontSize: fontSize,
        ).copyWith(height: 1, letterSpacing: -0.03 * fontSize);

        // The small clock, then the title under it. The title may take two
        // or three lines, so it is measured.
        const clockHeight = 18.0;
        const titleTop = margin + clockHeight + 6;
        final title = LocaleKeys.onboarding_welcome_title.tr();
        final titleHeight = (TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: textDirection,
        )..layout(maxWidth: textWidth)).height;

        // The face takes the room under the title.
        final roomTop = titleTop + titleHeight + 8;
        final room = math.max<double>(0, height - margin - roomTop);
        final faceSize = math.max<double>(
          56,
          math.min(200, math.min(width * 0.58, room * 0.82)),
        );
        final centre = Offset(width / 2, roomTop + room / 2);
        final sunSize = faceSize * 1.6;

        // The burst grows to cover the whole panel.
        final farthest = [
          Offset.zero,
          Offset(width, 0),
          Offset(0, height),
          Offset(width, height),
        ].map((corner) => (corner - centre).distance).reduce(math.max);
        final burstRadius = frame.burstReach * farthest * 1.1;
        final ringSize = faceSize * 1.1;

        Widget circle({
          required Offset at,
          required double size,
          required Color color,
          double opacity = 1,
        }) => Positioned(
          left: at.dx - size / 2,
          top: at.dy - size / 2,
          width: size,
          height: size,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        );

        final sky = ClipRRect(
          borderRadius: Radii.xlAll,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // A yellow canvas is the day itself, so the shapes behind the
              // panel stay whole. On any other canvas the day is its own
              // yellow sky.
              if (colors.canvas != colors.yellow)
                Positioned.fill(child: ColoredBox(color: colors.yellow)),
              if (frame.nightOpacity > 0.002)
                Positioned.fill(
                  child: Opacity(
                    opacity: frame.nightOpacity.clamp(0.0, 1.0),
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: night.sky)),
                        for (var i = 0; i < frame.starOpacities.length; i++)
                          Positioned(
                            left: welcomeNightFallsStarPlaces[i].$1 * width - 3,
                            top: welcomeNightFallsStarPlaces[i].$2 * height - 3,
                            width: 6,
                            height: 6,
                            child: Opacity(
                              opacity: frame.starOpacities[i].clamp(0.0, 1.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: night.star,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (frame.sunOpacity > 0.002)
                circle(
                  at:
                      centre +
                      Offset(
                        0,
                        frame.sunFall * welcomeNightFallsSunFall * sunSize,
                      ),
                  size: sunSize,
                  color: Color.lerp(colors.yellow, colors.onPanel, 0.42)!,
                  opacity: frame.sunOpacity,
                ),
              if (burstRadius > 1 && frame.burstOpacity > 0.002)
                circle(
                  at: centre,
                  size: burstRadius * 2,
                  color: colors.crit,
                  opacity: frame.burstOpacity,
                ),
              for (final ring in frame.rings)
                if (ring.opacity > 0.002)
                  Positioned(
                    left: centre.dx - ringSize / 2,
                    top: centre.dy - ringSize / 2,
                    width: ringSize,
                    height: ringSize,
                    child: Opacity(
                      opacity: ring.opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: ring.scale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.inkFixed,
                              width: math.max(2, faceSize * 0.02),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );

        Widget face(
          FaceState state,
          double opacity,
          Color fill,
          Color lines, {
          Color? tongue,
        }) => opacity <= 0.002
            ? const SizedBox.shrink()
            : Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: FaceWidget(
                  state: FaceState.calm,
                  shape: _shape(state),
                  size: faceSize,
                  overrideFillColor: fill,
                  overrideStrokeColor: lines,
                  overrideInkColor: lines,
                  overrideTongueColor: tongue,
                ),
              );

        Widget parting(
          ({double opacity, double shift}) Function(double) partingAt,
          Widget child,
        ) => Positioned.fill(
          child: _PartingLayer(
            slide: widget.slide,
            pageWidth: pageWidth,
            partingAt: partingAt,
            child: child,
          ),
        );

        return SizedBox(
          width: width,
          height: height,
          // Nothing here is cut by the page: while the pager moves the sky,
          // the title and the face fade out and travel clear.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              parting(_backdropParting, sky),
              parting(
                _titleParting,
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: margin,
                      top: margin,
                      height: clockHeight,
                      child: Text(
                        _clockText(frame.clock),
                        style: AppTypography.monoBold(ink, fontSize: 13),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    Positioned(
                      left: margin,
                      top: titleTop,
                      width: textWidth,
                      child: Text(title, style: titleStyle),
                    ),
                  ],
                ),
              ),
              parting(
                _faceParting,
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: centre.dx - faceSize / 2,
                      top: centre.dy - faceSize / 2,
                      width: faceSize,
                      height: faceSize,
                      child: Transform.rotate(
                        angle: frame.faceTurn,
                        child: Transform.scale(
                          scale: frame.faceScale,
                          child: Stack(
                            children: [
                              face(
                                _nightDayFace,
                                frame.dayFaceOpacity,
                                colors.yellow,
                                colors.inkFixed,
                              ),
                              face(
                                _nightSleepFace,
                                frame.sleepFaceOpacity,
                                night.dimFill,
                                night.dimInk,
                                tongue: night.dimInk,
                              ),
                              face(
                                _nightShoutFace,
                                frame.shoutFaceOpacity,
                                colors.yellow,
                                colors.inkFixed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
