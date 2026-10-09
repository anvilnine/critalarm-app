part of 'onboarding_welcome_screen.dart';

// Story 1 of the welcome pages: the word that rings. "Welcome to Crit Alarm"
// drops in, a red block grows behind "Alarm", its letters shake, and the face
// leans in from the right edge and shouts. The clock lives in
// welcome_word_timeline.dart. This file only paints a frame of it.

/// Tells the welcome screen whether a word story is on screen. The story is
/// not built when the room is too small (see [introHeroFits]), so the screen
/// learns from the story itself whether it may hide the small shared title.
///
/// A story that is replaced by a new one in the same frame must not leave
/// this at false, so the value follows a count and is set after the frame,
/// when both the old and the new story have said their part.
class _HeroDrawn extends ValueNotifier<bool> {
  _HeroDrawn() : super(false);

  int _stories = 0;
  bool _isDisposed = false;

  void add() {
    _stories++;
    _settle();
  }

  void remove() {
    _stories--;
    _settle();
  }

  void _settle() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_isDisposed) value = _stories > 0;
  });

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

/// The face that shouts once the block is up. The calm face melts into it.
const FaceState _wordShoutFace = FaceState.shocked;

/// Where the clock of a held still hero rests: inside the part of the story
/// where the block is up.
const double _wordRestAt = 4.5;

/// The first welcome page.
class _WordStoryHero extends StatefulWidget {
  const _WordStoryHero({required this.onDone, this.drawn});

  /// Called once, when the first pass is over.
  final VoidCallback onDone;

  /// Told while this story is on screen.
  final _HeroDrawn? drawn;

  @override
  State<_WordStoryHero> createState() => _WordStoryHeroState();
}

class _WordStoryHeroState extends _ClockState<_WordStoryHero> {
  @override
  double get restAt => _wordRestAt;

  @override
  double? get loopTakes => welcomeWordLoopSeconds;

  /// One beat when the block lands. A page that is not in front, or a phone
  /// that asks for reduced motion, plays nothing (see [canPlayHaptics]).
  @override
  List<TimedCue> buildCues() => const [
    (at: welcomeWordBlockLandsAt, cue: HeroCue.ringPulse),
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
    if (_hasSaidDone || seconds < welcomeWordLoopSeconds) return;
    _hasSaidDone = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final frame = welcomeWordFrameAt(t, reducedMotion: _isStill);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = box.maxHeight;

        // The drawing is made for 84 point type. A short room shrinks the
        // type so the three lines always fit.
        const lineHeight = 0.94;
        final fontSize = math.max<double>(
          24,
          math.min(
            welcomeWordFontSize(width),
            (height - 8) / (welcomeWordLineCount * lineHeight),
          ),
        );
        final unit = fontSize / welcomeWordMaxFontSize;
        final titleHeight = welcomeWordLineCount * lineHeight * fontSize;

        // The face is 210 points at full size and takes what the title
        // leaves, but never less than a small face.
        const faceFull = 210.0;
        final gap = 12 * unit;
        final room = height - titleHeight - gap;
        final faceSize = math.max<double>(
          72,
          math.min(math.min(faceFull, width * 0.6), room),
        );
        final faceUnit = faceSize / faceFull;
        final groupHeight = titleHeight + gap + faceSize;
        final titleTop = math.max<double>(0, (height - groupHeight) * 0.4);
        final faceTop = math.min(
          titleTop + titleHeight + gap,
          height - faceSize,
        );

        // The right edge of the face is the right edge of the page, which is
        // wider than this picture by the side padding.
        final pageRight = width + _IntroLayout.sidePadding;
        final faceRight = pageRight + (30 + frame.face.shift) * faceUnit;
        final ringsCentre = Offset(
          pageRight - faceSize / 2,
          faceTop + faceSize / 2,
        );
        final ringSize = faceSize * 200 / faceFull;

        final style = AppTypography.display(
          colors.onCanvas,
          fontSize: fontSize,
        ).copyWith(height: lineHeight, letterSpacing: -0.045 * fontSize);

        Widget dropped(int index, Widget child) {
          final line = frame.lines[index];
          return Opacity(
            opacity: line.opacity,
            child: Transform.translate(
              offset: Offset(0, line.offset * unit),
              child: child,
            ),
          );
        }

        final word = LocaleKeys.onboarding_welcome_title_word
            .tr()
            .characters
            .toList();
        final lastLine = Stack(
          clipBehavior: Clip.none,
          children: [
            if (frame.blockScale > 0.03)
              Positioned(
                left: -10 * unit,
                right: -14 * unit,
                top: 4 * unit,
                bottom: -2 * unit,
                child: Transform.scale(
                  scaleX: frame.blockScale,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.crit,
                      borderRadius: BorderRadius.circular(26 * unit),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < word.length; i++)
                  Transform(
                    alignment: Alignment.center,
                    transform:
                        Matrix4.translationValues(
                          0,
                          frame
                                  .letters[math.min(
                                    i,
                                    frame.letters.length - 1,
                                  )]
                                  .offset *
                              unit,
                          0,
                        )..rotateZ(
                          frame
                              .letters[math.min(i, frame.letters.length - 1)]
                              .turn,
                        ),
                    child: Text(word[i], style: style, softWrap: false),
                  ),
              ],
            ),
          ],
        );

        final shoutAmount = frame.face.shout;
        final faceShape = _withBlink(
          _blend(FaceState.calm, _wordShoutFace, shoutAmount),
          t,
        );

        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            clipper: const _PageClip(_IntroLayout.sidePadding),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final ring in frame.rings)
                  if (ring.opacity > 0.002)
                    Positioned(
                      left: ringsCentre.dx - ringSize / 2,
                      top: ringsCentre.dy - ringSize / 2,
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
                                color: colors.onCanvas,
                                width: math.max(2, 4 * faceUnit),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                Positioned(
                  left: 0,
                  top: titleTop,
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      dropped(
                        0,
                        Text(
                          LocaleKeys.onboarding_welcome_title_line_1.tr(),
                          style: style,
                          softWrap: false,
                        ),
                      ),
                      dropped(
                        1,
                        Text(
                          LocaleKeys.onboarding_welcome_title_line_2.tr(),
                          style: style,
                          softWrap: false,
                        ),
                      ),
                      dropped(2, lastLine),
                    ],
                  ),
                ),
                Positioned(
                  left: faceRight - faceSize,
                  top: faceTop,
                  width: faceSize,
                  height: faceSize,
                  child: Transform.rotate(
                    angle: frame.face.turn,
                    child: _face(faceShape, faceSize, fill: colors.yellow),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Clips sideways to the picture's box widened by the side padding, which is
/// the page the picture sits on. The face leans in from the page's edge and
/// the rings stop at it, instead of at the narrower box. Up and down nothing
/// is cut: the rings pass behind the words around them.
class _PageClip extends CustomClipper<Rect> {
  const _PageClip(this.side);

  final double side;

  static const double _far = 2000;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-side, -_far, size.width + side, size.height + _far);

  @override
  bool shouldReclip(_PageClip oldClipper) => oldClipper.side != side;
}
